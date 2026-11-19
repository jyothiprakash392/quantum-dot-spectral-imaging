function result = simulateQDComputationalSpectrometer(incidentPhotonsPerBin, ...
    config,varargin)
%SIMULATEQDCOMPUTATIONALSPECTROMETER End-to-end forward/inverse simulation.
%   RESULT = SIMULATEQDCOMPUTATIONALSPECTROMETER(S,CONFIG) converts the
%   incoming spectrum to visible PL, detects it with the CCD model, and
%   reconstructs S from the pixel/bias measurements.

if nargin < 2 || isempty(config)
    config = qdUpconversionSpectrometerConfig();
end
parser = inputParser;
parser.FunctionName = 'simulateQDComputationalSpectrometer';
addParameter(parser,'AddNoise',true, ...
    @(x)(islogical(x)||isnumeric(x))&&isscalar(x)&&isfinite(x));
addParameter(parser,'Seed',config.randomSeed, ...
    @(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=0);
addParameter(parser,'Regularization',config.reconstruction.regularization, ...
    @(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=0);
addParameter(parser,'UseNoiseWeights',true, ...
    @(x)(islogical(x)||isnumeric(x))&&isscalar(x)&&isfinite(x));
parse(parser,varargin{:});
options = parser.Results;

observation = simulateQDUpconversionCCD(incidentPhotonsPerBin,config, ...
    'AddNoise',options.AddNoise,'Seed',options.Seed);
if logical(options.UseNoiseWeights) && logical(options.AddNoise)
    noiseVariance = observation.ccd.noiseVariance_e2;
else
    noiseVariance = [];
end
reconstruction = reconstructQDSpectrum( ...
    observation.ccd.measuredElectrons,observation.response, ...
    'NoiseVariance',noiseVariance, ...
    'Regularization',options.Regularization, ...
    'MaxIterations',config.reconstruction.maxIterations);

truth = incidentPhotonsPerBin(:);
estimate = reconstruction.incidentPhotonsPerBin;
errorVector = estimate-truth;
normalizedRMSE = sqrt(mean(errorVector.^2))/max(mean(truth),eps);
if std(truth)>0 && std(estimate)>0
    correlationMatrix = corrcoef(truth,estimate);
    spectralCorrelation = correlationMatrix(1,2);
else
    spectralCorrelation = double(isequal(truth,estimate));
end
denominator = norm(truth)*norm(estimate);
if denominator>0
    spectralAngle_deg = acosd(max(-1,min(1,dot(truth,estimate)/denominator)));
else
    spectralAngle_deg = NaN;
end

result = struct();
result.observation = observation;
result.reconstruction = reconstruction;
result.metrics = struct( ...
    'RMSE_photonsPerBin',sqrt(mean(errorVector.^2)), ...
    'normalizedRMSEByMean',normalizedRMSE, ...
    'spectralCorrelation',spectralCorrelation, ...
    'spectralAngle_deg',spectralAngle_deg, ...
    'totalPhotonRelativeError',(sum(estimate)-sum(truth))/max(sum(truth),eps));
end
