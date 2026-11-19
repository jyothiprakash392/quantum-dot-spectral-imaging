function response = qdBuildSpectralResponse(config)
%QDBUILDSPECTRALRESPONSE Build conversion, visible-PL, and CCD matrices.
%   RESPONSE = QDBUILDSPECTRALRESPONSE(CONFIG) constructs the factorization
%
%      h = H*s                 visible photons in converter channels
%      v = P*h                 total visible spectrum for visualization
%      y = diag(g)*H*s + dark  CCD photoelectrons
%
%   where every row of H is one sensitizer pixel at one bias state, P
%   contains normalized visible PL spectra, and g contains optical
%   throughput, fill factor, and CCD quantum efficiency.

if nargin < 1 || isempty(config)
    config = qdUpconversionSpectrometerConfig();
end
localValidateConfig(config);

inputWavelength_nm = config.inputWavelength_nm(:);
visibleWavelength_nm = config.visibleWavelength_nm(:);
pixelCount = config.pixelCount;
biasCount = config.biasCount;
measurementCount = config.measurementCount;
inputCount = numel(inputWavelength_nm);
visibleCount = numel(visibleWavelength_nm);

converterMatrix = zeros(measurementCount,inputCount);
visibleBasis = zeros(visibleCount,measurementCount);
pixelIndexByMeasurement = zeros(measurementCount,1);
biasIndexByMeasurement = zeros(measurementCount,1);
biasByMeasurement_V = zeros(measurementCount,1);
inputCenter_nm = zeros(measurementCount,1);
inputFWHM_nm = zeros(measurementCount,1);
emissionCenter_nm = zeros(measurementCount,1);
emissionFWHM_nm = zeros(measurementCount,1);
peakPhotonEfficiency = zeros(measurementCount,1);
photonOrder = zeros(measurementCount,1);

biasMinimum = min(config.biasVoltages_V);
biasMaximum = max(config.biasVoltages_V);
if biasMaximum == biasMinimum
    normalizedBias = zeros(biasCount,1);
else
    normalizedBias = 2*(config.biasVoltages_V(:)-biasMinimum)/ ...
        (biasMaximum-biasMinimum)-1;
end

for biasIndex = 1:biasCount
    biasCoordinate = normalizedBias(biasIndex);
    for pixelIndex = 1:pixelCount
        measurementIndex = (biasIndex-1)*pixelCount+pixelIndex;
        pixelPhase = 2*pi*(pixelIndex-1)/max(pixelCount,1);
        center_nm = config.sensitizer.absorptionCenter_nm(pixelIndex)+ ...
            config.device.biasShiftRange_nm*biasCoordinate;
        width_nm = config.device.inputResponseFWHM_nm* ...
            (1+0.10*biasCoordinate*cos(pixelPhase));
        pixelUniformity = 0.90+0.10*cos(pixelPhase+0.35);
        biasActivation = 0.82+0.18*(biasCoordinate+1)/2;
        efficiency = config.device.peakExternalPhotonEfficiency* ...
            pixelUniformity*biasActivation;
        inputShape = exp(-4*log(2)* ...
            ((inputWavelength_nm-center_nm)/width_nm).^2);

        % A small, bias-dependent Stark shift is allowed on the visible
        % line. It is deliberately much smaller than the input-response
        % tuning because the latter is a device/ROIC effect.
        visibleCenter_nm = config.emitter.plCenter_nm(pixelIndex)+ ...
            1.5*biasCoordinate;
        visibleWidth_nm = max(8,config.emitter.plFWHM_nm(pixelIndex));
        visibleShape = exp(-4*log(2)* ...
            ((visibleWavelength_nm-visibleCenter_nm)/visibleWidth_nm).^2);
        visibleShape = visibleShape/sum(visibleShape);

        inputEnergy_eV = 1239.8419843320026/center_nm;
        visibleEnergy_eV = 1239.8419843320026/visibleCenter_nm;
        minimumPhotonOrder = max(1,ceil(visibleEnergy_eV/inputEnergy_eV-32*eps));
        if strcmp(config.conversionMechanism,'multiphoton')
            order = minimumPhotonOrder;
        else
            % A photodiode-to-QLED converter is linear in incident photon
            % count at its operating point. The voltage source supplies the
            % energy difference, so a passive photon-order bound does not apply.
            order = 1;
        end
        if strcmp(config.conversionMechanism,'multiphoton') && ...
                efficiency > 0.95/order
            error('QDConverter:SpectrometerEfficiency', ...
                ['Peak photon efficiency violates the conservative ' ...
                'multi-photon energy bound for measurement %d.'], ...
                measurementIndex);
        end

        converterMatrix(measurementIndex,:) = efficiency*inputShape.';
        visibleBasis(:,measurementIndex) = visibleShape;
        pixelIndexByMeasurement(measurementIndex) = pixelIndex;
        biasIndexByMeasurement(measurementIndex) = biasIndex;
        biasByMeasurement_V(measurementIndex) = ...
            config.biasVoltages_V(biasIndex);
        inputCenter_nm(measurementIndex) = center_nm;
        inputFWHM_nm(measurementIndex) = width_nm;
        emissionCenter_nm(measurementIndex) = visibleCenter_nm;
        emissionFWHM_nm(measurementIndex) = visibleWidth_nm;
        peakPhotonEfficiency(measurementIndex) = efficiency;
        photonOrder(measurementIndex) = order;
    end
end

% Smooth front-illuminated silicon CCD quantum-efficiency model. The exact
% curve is replaceable through a measured system matrix.
leftEdge = 1./(1+exp(-(visibleWavelength_nm-405)/18));
rightEdge = 1./(1+exp((visibleWavelength_nm-720)/22));
ccdQuantumEfficiency = config.ccd.quantumEfficiencyPeak*leftEdge.*rightEdge;
effectiveCCDQuantumEfficiency = visibleBasis.'*ccdQuantumEfficiency;
ccdDetectionGain = config.device.opticalTransmission*config.ccd.fillFactor* ...
    effectiveCCDQuantumEfficiency;
systemMatrix = ccdDetectionGain.*converterMatrix;
calibrationMode = config.calibration.mode;
calibrationLabel = config.calibration.label;

if ~isempty(config.measuredSystemResponse)
    measuredMatrix = config.measuredSystemResponse;
    if ~isequal(size(measuredMatrix),size(systemMatrix)) || ...
            ~isreal(measuredMatrix) || any(~isfinite(measuredMatrix(:))) || ...
            any(measuredMatrix(:)<0)
        error('QDConverter:MeasuredResponse', ...
            'Measured system response must be a finite nonnegative M-by-N matrix.');
    end
    systemMatrix = measuredMatrix;
    converterMatrix = systemMatrix./max(ccdDetectionGain,realmin);
    calibrationMode = config.calibration.mode;
    calibrationLabel = config.calibration.label;
end

darkElectronsExpected = config.ccd.darkCurrent_ePerSecond* ...
    config.ccd.exposureTime_s*ones(measurementCount,1);
if ~isempty(config.measuredDarkElectrons)
    darkElectronsExpected = config.measuredDarkElectrons(:);
    if numel(darkElectronsExpected)~=measurementCount || ...
            any(~isfinite(darkElectronsExpected)) || ...
            any(darkElectronsExpected<0)
        error('QDConverter:MeasuredDark', ...
            'Measured dark vector must contain one nonnegative value per measurement.');
    end
end

singularValues = svd(systemMatrix,'econ');
rankTolerance = max(size(systemMatrix))*eps(max(singularValues));
numericalRank = sum(singularValues>rankTolerance);
if singularValues(end) > 0
    conditionNumber = singularValues(1)/singularValues(end);
else
    conditionNumber = inf;
end
if strcmp(config.conversionMechanism,'multiphoton')
    energyRatio = (1239.8419843320026./emissionCenter_nm)./ ...
        (photonOrder.*(1239.8419843320026./inputCenter_nm));
    energyAccountingMode = 'passive multiphoton feasibility ratio';
else
    energyRatio = nan(measurementCount,1);
    energyAccountingMode = ['electrically assisted: optical-only energy ' ...
        'ratio is not applicable until electrical power is measured'];
end

response = struct();
response.schemaVersion = config.schemaVersion;
response.inputWavelength_nm = inputWavelength_nm;
response.visibleWavelength_nm = visibleWavelength_nm;
response.converterResponse_photonsPerIncidentPhoton = converterMatrix;
response.visibleEmissionBasis_perBin = visibleBasis;
response.ccdQuantumEfficiency = ccdQuantumEfficiency;
response.effectiveCCDQuantumEfficiency = effectiveCCDQuantumEfficiency;
response.ccdDetectionGain_electronsPerVisiblePhoton = ccdDetectionGain;
response.systemMatrix_electronsPerIncidentPhoton = systemMatrix;
response.darkElectronsExpected = darkElectronsExpected;
response.readNoiseElectronsRMS = config.ccd.readNoiseElectronsRMS;
response.fullWellElectrons = config.ccd.fullWellElectrons;
response.exposureTime_s = config.ccd.exposureTime_s;
response.pixelIndex = pixelIndexByMeasurement;
response.biasIndex = biasIndexByMeasurement;
response.biasVoltage_V = biasByMeasurement_V;
response.inputResponseCenter_nm = inputCenter_nm;
response.inputResponseFWHM_nm = inputFWHM_nm;
response.emissionCenter_nm = emissionCenter_nm;
response.emissionFWHM_nm = emissionFWHM_nm;
response.peakExternalPhotonEfficiency = peakPhotonEfficiency;
response.upconversionPhotonOrder = photonOrder;
response.energyConservationRatio = energyRatio;
response.energyAccountingMode = energyAccountingMode;
response.requiresExternalElectricalPower = ...
    strcmp(config.conversionMechanism,'electrically_assisted');
response.numericalRank = numericalRank;
response.conditionNumber = conditionNumber;
response.calibrationMode = calibrationMode;
response.calibrationLabel = calibrationLabel;
response.isMeasuredCalibration = config.calibration.responseMatrixMeasured;
response.measurementTable = table((1:measurementCount).', ...
    pixelIndexByMeasurement,biasIndexByMeasurement,biasByMeasurement_V, ...
    inputCenter_nm,inputFWHM_nm,emissionCenter_nm,emissionFWHM_nm, ...
    photonOrder,peakPhotonEfficiency,effectiveCCDQuantumEfficiency, ...
    'VariableNames',{'Measurement','Pixel','BiasIndex','Bias_V', ...
    'InputCenter_nm','InputFWHM_nm','VisibleCenter_nm','VisibleFWHM_nm', ...
    'PhotonOrder','PeakPhotonEfficiency','EffectiveCCDQuantumEfficiency'});
end

function localValidateConfig(config)
required = {'inputWavelength_nm','visibleWavelength_nm','biasVoltages_V', ...
    'pixelCount','biasCount','measurementCount','sensitizer','emitter', ...
    'device','ccd','calibration','measuredSystemResponse', ...
    'measuredDarkElectrons'};
if ~isstruct(config) || ~isscalar(config) || ...
        ~all(isfield(config,required))
    error('QDConverter:SpectrometerConfig', ...
        'Input must be a scalar qdUpconversionSpectrometerConfig structure.');
end
if config.measurementCount ~= config.pixelCount*config.biasCount || ...
        numel(config.biasVoltages_V) ~= config.biasCount || ...
        numel(config.sensitizer.absorptionCenter_nm) ~= config.pixelCount || ...
        numel(config.emitter.plCenter_nm) ~= config.pixelCount
    error('QDConverter:SpectrometerConfig', ...
        'Pixel, bias, or measurement dimensions in the configuration disagree.');
end
end
