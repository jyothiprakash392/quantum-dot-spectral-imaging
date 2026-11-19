function observation = simulateQDUpconversionCCD(incidentPhotonsPerBin, ...
    config,varargin)
%SIMULATEQDUPCONVERSIONCCD Forward model: NIR -> visible PL -> CCD counts.
%   O = SIMULATEQDUPCONVERSIONCCD(S,CONFIG) applies the configured
%   sensitizer/emitter response, synthesizes the visible PL spectrum, and
%   models CCD shot, dark, and read noise. S is one photon count per input
%   wavelength bin, per converter pixel, per bias-state exposure.
%
%   Name-value options:
%     AddNoise            true by default
%     Seed                local deterministic random-stream seed
%     ReadNoiseElectronsRMS  override the configured read noise
%     EnforceFullWell     clip at the configured CCD full well (default true)
%
%   The global MATLAB random-number state is never modified.

if nargin < 2 || isempty(config)
    config = qdUpconversionSpectrometerConfig();
end
response = qdBuildSpectralResponse(config);

parser = inputParser;
parser.FunctionName = 'simulateQDUpconversionCCD';
addParameter(parser,'AddNoise',true, ...
    @(x)(islogical(x)||isnumeric(x))&&isscalar(x)&&isfinite(x));
addParameter(parser,'Seed',config.randomSeed, ...
    @(x)isnumeric(x)&&isscalar(x)&&isreal(x)&&isfinite(x)&&x==fix(x)&&x>=0);
addParameter(parser,'ReadNoiseElectronsRMS',response.readNoiseElectronsRMS, ...
    @(x)isnumeric(x)&&isscalar(x)&&isreal(x)&&isfinite(x)&&x>=0);
addParameter(parser,'EnforceFullWell',true, ...
    @(x)(islogical(x)||isnumeric(x))&&isscalar(x)&&isfinite(x));
parse(parser,varargin{:});
options = parser.Results;

incident = incidentPhotonsPerBin(:);
inputCount = numel(response.inputWavelength_nm);
if ~isnumeric(incidentPhotonsPerBin) || ~isreal(incidentPhotonsPerBin) || ...
        numel(incident)~=inputCount || any(~isfinite(incident)) || ...
        any(incident<0)
    error('VirtualQD:IncidentSpectrum', ...
        'Incident spectrum must contain one finite nonnegative count per input bin.');
end

converterMatrix = response.converterResponse_photonsPerIncidentPhoton;
visibleChannelPhotons = converterMatrix*incident;
visibleSpectrumPhotonsPerBin = ...
    response.visibleEmissionBasis_perBin*visibleChannelPhotons;
signalElectronsExpected = ...
    response.systemMatrix_electronsPerIncidentPhoton*incident;
darkElectronsExpected = response.darkElectronsExpected;
totalElectronsExpected = signalElectronsExpected+darkElectronsExpected;
readNoiseRMS = options.ReadNoiseElectronsRMS;
noiseVariance = totalElectronsExpected+readNoiseRMS^2;

if logical(options.AddNoise)
    stream = RandStream('mt19937ar','Seed',double(options.Seed));
    measuredElectrons = localPoissonVector(totalElectronsExpected,stream)+ ...
        readNoiseRMS*randn(stream,size(totalElectronsExpected));
else
    measuredElectrons = totalElectronsExpected;
end
measuredElectrons = max(0,measuredElectrons);
preClipElectrons = measuredElectrons;
if logical(options.EnforceFullWell)
    measuredElectrons = min(measuredElectrons,response.fullWellElectrons);
end
saturated = preClipElectrons>response.fullWellElectrons;

hc_Jm = 6.62607015e-34*299792458;
inputPhotonEnergy_J = hc_Jm./(response.inputWavelength_nm*1e-9);
visiblePhotonEnergy_J = hc_Jm./(response.emissionCenter_nm*1e-9);
inputEnergyPerPixelExposure_J = sum(incident.*inputPhotonEnergy_J);
visibleEnergyByMeasurement_J = visibleChannelPhotons.*visiblePhotonEnergy_J;

% This is a mechanistic feasibility ratio for each emitted photon: the PL
% photon energy divided by m sensitizer photons at the response center.
% It does not estimate heat or nonradiative losses.
energyFeasibilityRatio = response.energyConservationRatio;

observation = struct();
observation.schemaVersion = config.schemaVersion;
observation.config = config;
observation.response = response;
observation.input = struct( ...
    'wavelength_nm',response.inputWavelength_nm, ...
    'incidentPhotonsPerBin',incident, ...
    'definition',config.inputDefinition, ...
    'energyPerPixelExposure_J',inputEnergyPerPixelExposure_J);
observation.conversion = struct( ...
    'visibleChannelPhotonCountExpected',visibleChannelPhotons, ...
    'visibleWavelength_nm',response.visibleWavelength_nm, ...
    'visibleSpectrumPhotonCountExpectedPerBin',visibleSpectrumPhotonsPerBin, ...
    'emissionCenter_nm',response.emissionCenter_nm, ...
    'upconversionPhotonOrder',response.upconversionPhotonOrder, ...
    'visibleEnergyByMeasurement_J',visibleEnergyByMeasurement_J, ...
    'energyFeasibilityRatio',energyFeasibilityRatio);
observation.conversion.energyAccountingMode = response.energyAccountingMode;
observation.conversion.requiresExternalElectricalPower = ...
    response.requiresExternalElectricalPower;
observation.ccd = struct( ...
    'signalElectronsExpected',signalElectronsExpected, ...
    'darkElectronsExpected',darkElectronsExpected, ...
    'totalElectronsExpected',totalElectronsExpected, ...
    'noiseVariance_e2',noiseVariance, ...
    'readNoiseElectronsRMS',readNoiseRMS, ...
    'measuredElectrons',measuredElectrons, ...
    'preClipElectrons',preClipElectrons, ...
    'saturated',saturated, ...
    'fullWellElectrons',response.fullWellElectrons, ...
    'addNoise',logical(options.AddNoise), ...
    'seed',double(options.Seed));
observation.validity = struct( ...
    'responseMatrixMeasured',response.isMeasuredCalibration, ...
    'calibrationLabel',response.calibrationLabel, ...
    'syntheticDeviceResponse',~response.isMeasuredCalibration, ...
    'allEnergyRatiosAtMostOneOrNotApplicable', ...
        all(isnan(energyFeasibilityRatio) | energyFeasibilityRatio<=1+64*eps), ...
    'anyCCDSaturation',any(saturated), ...
    'sensitizerOpticalCalibrationCoverage', ...
        config.validity.sensitizerOpticalCalibrationCoverage, ...
    'quantitativeHardwarePrediction', ...
        config.validity.quantitativeHardwarePrediction);
end

function samples = localPoissonVector(lambda,stream)
% Exact inversion for small means and PTRS transformed rejection otherwise.
samples = zeros(size(lambda));
for index = 1:numel(lambda)
    meanValue = lambda(index);
    if meanValue <= 0
        samples(index) = 0;
    elseif meanValue < 30
        threshold = exp(-meanValue);
        product = 1;
        count = 0;
        while product > threshold
            count = count+1;
            product = product*rand(stream);
        end
        samples(index) = count-1;
    else
        % Hormann's PTRS algorithm. It avoids a Statistics Toolbox
        % dependency while retaining an exact Poisson acceptance test.
        squareRoot = sqrt(meanValue);
        b = 0.931+2.53*squareRoot;
        a = -0.059+0.02483*b;
        inverseAlpha = 1.1239+1.1328/(b-3.4);
        vLimit = 0.9277-3.6224/(b-2);
        accepted = false;
        while ~accepted
            u = rand(stream)-0.5;
            v = rand(stream);
            uSmall = 0.5-abs(u);
            candidate = floor((2*a/uSmall+b)*u+meanValue+0.43);
            if uSmall>=0.07 && v<=vLimit
                accepted = candidate>=0;
            elseif candidate>=0 && ~(uSmall<0.013 && v>uSmall)
                logarithmicTest = log(v*inverseAlpha/ ...
                    (a/(uSmall*uSmall)+b));
                accepted = logarithmicTest <= ...
                    -meanValue+candidate*log(meanValue)-gammaln(candidate+1);
            end
        end
        samples(index) = candidate;
    end
end
end
