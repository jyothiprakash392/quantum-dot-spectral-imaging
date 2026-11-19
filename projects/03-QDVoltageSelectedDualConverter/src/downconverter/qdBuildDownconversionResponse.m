function response = qdBuildDownconversionResponse(config,selectorVoltage_V)
%QDBUILDDOWNCONVERSIONRESPONSE Build passive film and detector operators.
%   RESPONSE = QDBUILDDOWNCONVERSIONRESPONSE(CONFIG,VSELECT) returns the
%   voltage-selected passive down-conversion operator
%
%       c = H(VSELECT)*u        photons emitted by each film
%       p = P(VSELECT)*c        output photons per wavelength bin
%       e = diag(g)*p           expected detector photoelectrons
%
%   VSELECT is a selector/actuator command. It selects a fixed-emission
%   film; it is not interpreted as a broad continuous Stark shift.

if nargin<1 || isempty(config)
    config = qdDownconversionConfig();
end
if nargin<2 || isempty(selectorVoltage_V)
    selectorVoltage_V = config.selector.defaultVoltage_V;
end
localValidateConfig(config);
if ~isnumeric(selectorVoltage_V) || ~isscalar(selectorVoltage_V) || ...
        ~isreal(selectorVoltage_V) || ~isfinite(selectorVoltage_V) || ...
        selectorVoltage_V<config.selector.minimumVoltage_V || ...
        selectorVoltage_V>config.selector.maximumVoltage_V
    error('QDConverter:SelectorVoltage', ...
        ['Selector voltage must be a finite scalar inside the calibrated ' ...
        'channel-voltage range.']);
end

hc_eVnm = 1239.8419843320026;
inputWavelength_nm = config.inputWavelength_nm(:);
outputWavelength_nm = config.outputWavelength_nm(:);
filmCount = config.filmCount;

[selectorWeights,selectedIndex] = localSelectorWeights( ...
    selectorVoltage_V,config.selector);

absorptionMatrix = zeros(filmCount,numel(inputWavelength_nm));
converterMatrix = zeros(filmCount,numel(inputWavelength_nm));
emissionBasis = zeros(numel(outputWavelength_nm),filmCount);
emissionCenter_nm = config.film.emissionCenter_nm(:);

voltageSpan = config.selector.maximumVoltage_V- ...
    config.selector.minimumVoltage_V;
if voltageSpan>0 && config.film.qcsePeakShift_nm>0
    voltageCoordinate = 2*(selectorVoltage_V- ...
        config.selector.minimumVoltage_V)/voltageSpan-1;
    % This optional small common shift is deliberately bounded. The broad
    % wavelength choice still comes only from the discrete film selector.
    emissionCenter_nm = emissionCenter_nm+ ...
        0.5*config.film.qcsePeakShift_nm*voltageCoordinate;
end

outputEnergy_eV = hc_eVnm./outputWavelength_nm;
for filmIndex = 1:filmCount
    absorptionShape = exp(-4*log(2)*( ...
        (inputWavelength_nm-config.film.absorptionCenter_nm(filmIndex))/ ...
        config.film.absorptionFWHM_nm(filmIndex)).^2);
    absorptance = config.film.peakAbsorptance(filmIndex)*absorptionShape;
    absorptionMatrix(filmIndex,:) = ...
        selectorWeights(filmIndex)*absorptance.';
    converterMatrix(filmIndex,:) = absorptionMatrix(filmIndex,:)* ...
        config.film.photoluminescenceQuantumYield(filmIndex)* ...
        config.film.extractionEfficiency(filmIndex);

    % NIR QD linewidths are represented in photon energy. This avoids
    % imposing unrealistically narrow wavelength-domain lines at 1-1.5 um.
    centerEnergy_eV = hc_eVnm/emissionCenter_nm(filmIndex);
    shape = exp(-4*log(2)*( ...
        (outputEnergy_eV-centerEnergy_eV)/ ...
        config.film.emissionFWHM_eV(filmIndex)).^2);
    if ~any(shape>0)
        error('QDConverter:DownconversionBand', ...
            'The output grid does not sample film %d emission.',filmIndex);
    end
    emissionBasis(:,filmIndex) = shape/sum(shape);
end

outputMatrix = emissionBasis*converterMatrix;
absorptionProbabilityByInput = sum(absorptionMatrix,1).';
outputPhotonYieldByInput = sum(outputMatrix,1).';

% Smooth illustrative detector curves. A dichroic splitter routes shorter
% wavelengths to silicon and longer wavelengths to InGaAs.
lambda = outputWavelength_nm;
siLeft = 1./(1+exp(-(lambda-390)/16));
siRight = 1./(1+exp((lambda-1030)/28));
siQE = config.detector.siliconQuantumEfficiencyPeak*siLeft.*siRight;
ingaasLeft = 1./(1+exp(-(lambda-850)/35));
ingaasRight = 1./(1+exp((lambda-1700)/45));
ingaasQE = config.detector.ingaasQuantumEfficiencyPeak* ...
    ingaasLeft.*ingaasRight;
siRoute = 1./(1+exp((lambda-config.detector.dichroicCrossover_nm)/ ...
    config.detector.dichroicTransitionWidth_nm));
ingaasRoute = 1-siRoute;
throughput = config.detector.opticalTransmission* ...
    config.detector.fillFactor;
siGain = throughput*siRoute.*siQE;
ingaasGain = throughput*ingaasRoute.*ingaasQE;
hybridGain = siGain+ingaasGain;

readNoise = sqrt((siRoute*config.detector.siliconReadNoiseElectronsRMS).^2+ ...
    (ingaasRoute*config.detector.ingaasReadNoiseElectronsRMS).^2);
darkRate = siRoute*config.detector.siliconDarkCurrent_ePerSecond+ ...
    ingaasRoute*config.detector.ingaasDarkCurrent_ePerSecond;
darkElectrons = darkRate*config.detector.exposureTime_s;

detectorMatrix = hybridGain.*outputMatrix;
effectiveDetectorQEByFilm = emissionBasis.'*hybridGain;

% Computational branch: wavelength-selective spatial UV pixels are sampled
% at sequential electro-absorption bias states. Each CCD/InGaAs spatial
% channel retains its identity even though the selected film emits the same
% output color. This is what makes UV spectral reconstruction possible.
pixelCount = config.spectrometer.pixelCount;
biasVoltages_V = config.spectrometer.biasVoltages_V(:);
biasCount = config.spectrometer.biasCount;
measurementCount = config.spectrometer.measurementCount;
inputCount = numel(inputWavelength_nm);
filterCenters0_nm = linspace(inputWavelength_nm(1)+4, ...
    inputWavelength_nm(end)-4,pixelCount).';
if biasVoltages_V(end)==biasVoltages_V(1)
    normalizedFilterBias = zeros(biasCount,1);
else
    normalizedFilterBias = 2*(biasVoltages_V-biasVoltages_V(1))/ ...
        (biasVoltages_V(end)-biasVoltages_V(1))-1;
end
filmPhotonProbabilityByInput = sum(converterMatrix,1);
computationalConverterMatrix = zeros(measurementCount,inputCount);
filterCenter_nm = zeros(measurementCount,1);
filterFWHM_nm = zeros(measurementCount,1);
pixelIndexByMeasurement = zeros(measurementCount,1);
biasIndexByMeasurement = zeros(measurementCount,1);
filterBiasByMeasurement_V = zeros(measurementCount,1);
for biasIndex = 1:biasCount
    biasCoordinate = normalizedFilterBias(biasIndex);
    for pixelIndex = 1:pixelCount
        measurementIndex = (biasIndex-1)*pixelCount+pixelIndex;
        pixelPhase = 2*pi*(pixelIndex-1)/pixelCount;
        center_nm = filterCenters0_nm(pixelIndex)+ ...
            config.spectrometer.filterShiftRange_nm*biasCoordinate;
        width_nm = config.spectrometer.filterResponseFWHM_nm* ...
            (1+0.08*biasCoordinate*cos(pixelPhase));
        spatialUniformity = 0.92+0.08*cos(pixelPhase+0.31);
        filterShape = exp(-4*log(2)*( ...
            (inputWavelength_nm-center_nm)/width_nm).^2);
        computationalConverterMatrix(measurementIndex,:) = ...
            spatialUniformity*filterShape.'.*filmPhotonProbabilityByInput;
        filterCenter_nm(measurementIndex) = center_nm;
        filterFWHM_nm(measurementIndex) = width_nm;
        pixelIndexByMeasurement(measurementIndex) = pixelIndex;
        biasIndexByMeasurement(measurementIndex) = biasIndex;
        filterBiasByMeasurement_V(measurementIndex) = ...
            biasVoltages_V(biasIndex);
    end
end
selectedEmissionBasis = emissionBasis*selectorWeights;
selectedEmissionBasis = selectedEmissionBasis/max(sum(selectedEmissionBasis),realmin);
computationalEmissionBasis = repmat(selectedEmissionBasis,1,measurementCount);
channelDetectorGain = repmat(selectedEmissionBasis.'*hybridGain, ...
    measurementCount,1);
computationalSystemMatrix = ...
    channelDetectorGain.*computationalConverterMatrix;
effectiveDark = selectedEmissionBasis.'*darkElectrons;
computationalDark = repmat(effectiveDark,measurementCount,1);
effectiveReadNoise = sqrt(sum((selectedEmissionBasis.*readNoise).^2));
computationalReadNoise = repmat(effectiveReadNoise,measurementCount,1);
singularValues = svd(computationalSystemMatrix,'econ');
rankTolerance = max(size(computationalSystemMatrix))*eps(max(singularValues));
numericalRank = sum(singularValues>rankTolerance);
if singularValues(end)>0
    conditionNumber = singularValues(1)/singularValues(end);
else
    conditionNumber = inf;
end

inputEnergy_eV = hc_eVnm./inputWavelength_nm;
energyEfficiencyByInput = (outputMatrix.'*outputEnergy_eV)./inputEnergy_eV;
if any(outputPhotonYieldByInput>1+128*eps) || ...
        any(energyEfficiencyByInput>1+128*eps)
    error('QDConverter:DownconversionEnergy', ...
        'Configured passive film bank violates photon or energy conservation.');
end

response = struct();
response.schemaVersion = config.schemaVersion;
response.selectorVoltage_V = selectorVoltage_V;
response.selectorWeights = selectorWeights;
response.selectedFilmIndex = selectedIndex;
response.selectedMaterial = config.film.material{selectedIndex};
response.inputWavelength_nm = inputWavelength_nm;
response.outputWavelength_nm = outputWavelength_nm;
response.absorptionProbabilityByFilm = absorptionMatrix;
response.converterResponse_photonsPerIncidentPhoton = converterMatrix;
response.emissionBasis_perBin = emissionBasis;
response.outputResponse_photonsPerIncidentPhoton = outputMatrix;
response.absorptionProbabilityByInput = absorptionProbabilityByInput;
response.outputPhotonYieldByInput = outputPhotonYieldByInput;
response.energyEfficiencyByInput = energyEfficiencyByInput;
response.emissionCenter_nm = emissionCenter_nm;
response.siQuantumEfficiency = siQE;
response.ingaasQuantumEfficiency = ingaasQE;
response.siRouteFraction = siRoute;
response.ingaasRouteFraction = ingaasRoute;
response.siDetectionGain_electronsPerPhoton = siGain;
response.ingaasDetectionGain_electronsPerPhoton = ingaasGain;
response.hybridDetectionGain_electronsPerPhoton = hybridGain;
response.effectiveDetectorQEByFilm = effectiveDetectorQEByFilm;
response.detectorMatrix_electronsPerIncidentPhoton = detectorMatrix;
response.darkElectronsExpected = darkElectrons;
response.readNoiseElectronsRMS = readNoise;
response.fullWellElectrons = config.detector.fullWellElectrons;
response.calibrationLabel = config.calibration.label;
response.isMeasuredCalibration = config.calibration.filmSpectraMeasured && ...
    config.calibration.detectorResponseMeasured;
% Generic reconstruction contract used by reconstructQDSpectrum.
response.systemMatrix_electronsPerIncidentPhoton = ...
    computationalSystemMatrix;
response.darkElectronsExpectedByMeasurement = computationalDark;
response.computational = struct( ...
    'converterResponse_photonsPerIncidentPhoton', ...
        computationalConverterMatrix, ...
    'emissionBasis_perBin',computationalEmissionBasis, ...
    'ccdDetectionGain_electronsPerOutputPhoton',channelDetectorGain, ...
    'systemMatrix_electronsPerIncidentPhoton', ...
        computationalSystemMatrix, ...
    'darkElectronsExpected',computationalDark, ...
    'readNoiseElectronsRMS',computationalReadNoise, ...
    'fullWellElectrons',config.detector.fullWellElectrons, ...
    'pixelIndex',pixelIndexByMeasurement, ...
    'biasIndex',biasIndexByMeasurement, ...
    'biasVoltage_V',filterBiasByMeasurement_V, ...
    'filterCenter_nm',filterCenter_nm, ...
    'filterFWHM_nm',filterFWHM_nm, ...
    'measurementCount',measurementCount, ...
    'numericalRank',numericalRank, ...
    'conditionNumber',conditionNumber);
% Keep the default dark field compatible with reconstructQDSpectrum. The
% spectral-detector dark vector remains available as detectorDarkElectrons.
response.detectorDarkElectrons = response.darkElectronsExpected;
response.darkElectronsExpected = computationalDark;
response.readNoiseElectronsRMSByMeasurement = computationalReadNoise;
response.numericalRank = numericalRank;
response.conditionNumber = conditionNumber;
response.filmTable = table((1:filmCount).', ...
    localChannelVoltages(config.selector),selectorWeights, ...
    string(config.film.material(:)),emissionCenter_nm, ...
    config.film.emissionFWHM_eV(:), ...
    config.film.photoluminescenceQuantumYield(:), ...
    config.film.extractionEfficiency(:),effectiveDetectorQEByFilm, ...
    'VariableNames',{'Film','SelectorVoltage_V','SelectorWeight','Material', ...
    'EmissionCenter_nm','EmissionFWHM_eV','PLQY','ExtractionEfficiency', ...
    'EffectiveDetectorQE'});
response.measurementTable = table((1:measurementCount).', ...
    pixelIndexByMeasurement,biasIndexByMeasurement, ...
    filterBiasByMeasurement_V,filterCenter_nm,filterFWHM_nm, ...
    channelDetectorGain, ...
    'VariableNames',{'Measurement','Pixel','BiasIndex','FilterBias_V', ...
    'UVFilterCenter_nm','UVFilterFWHM_nm','DetectorGain'});
end

function [weights,selectedIndex] = localSelectorWeights(voltage,selector)
channelVoltages = localChannelVoltages(selector);
[~,selectedIndex] = min(abs(voltage-channelVoltages));
weights = zeros(numel(channelVoltages),1);
weights(selectedIndex) = 1;
end

function localValidateConfig(config)
required = {'inputWavelength_nm','outputWavelength_nm','selector','film', ...
    'filmCount','detector','spectrometer','calibration'};
if ~isstruct(config) || ~isscalar(config) || ~all(isfield(config,required))
    error('QDConverter:DownconversionConfig', ...
        'Input must be a scalar qdDownconversionConfig structure.');
end
if numel(localChannelVoltages(config.selector))~=config.filmCount || ...
        numel(config.film.emissionCenter_nm)~=config.filmCount
    error('QDConverter:DownconversionConfig', ...
        'Film and selector dimensions in the configuration disagree.');
end
end

function voltages = localChannelVoltages(selector)
if ~isfield(selector,'channelVoltage_V')
    error('QDConverter:DownconversionConfig', ...
        'Selector configuration must define channelVoltage_V.');
end
voltages = selector.channelVoltage_V(:);
end
