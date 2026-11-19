function calibratedConfig = qdApplyMeasuredSpectralCalibration(config, ...
    measuredWavelength_nm,measuredSystemResponse,varargin)
%QDAPPLYMEASUREDSPECTRALCALIBRATION Install a measured response matrix.
%   C = QDAPPLYMEASUREDSPECTRALCALIBRATION(CONFIG,LAMBDA,D) interpolates
%   detector response D onto CONFIG.inputWavelength_nm. D must contain one
%   row per pixel/bias measurement and one column per LAMBDA sample. Values
%   are absolute CCD electrons per incident photon per wavelength bin.
%
%   Name-value options:
%     DarkElectrons   measured dark/offset vector for one exposure
%     Label           traceable calibration identifier
%     ResponseScale   scalar unit conversion applied before interpolation

parser = inputParser;
parser.FunctionName = 'qdApplyMeasuredSpectralCalibration';
addParameter(parser,'DarkElectrons',[], ...
    @(x)isempty(x)||(isnumeric(x)&&isvector(x)&&isreal(x)&& ...
    all(isfinite(x(:)))&&all(x(:)>=0)));
addParameter(parser,'Label','measured device response', ...
    @(x)ischar(x)||(isstring(x)&&isscalar(x)));
addParameter(parser,'ResponseScale',1, ...
    @(x)isnumeric(x)&&isscalar(x)&&isreal(x)&&isfinite(x)&&x>0);
parse(parser,varargin{:});
options = parser.Results;

lambda = measuredWavelength_nm(:);
if ~isnumeric(lambda) || numel(lambda)<3 || any(~isfinite(lambda)) || ...
        any(diff(lambda)<=0)
    error('VirtualQD:MeasuredWavelength', ...
        'Measured wavelengths must be a strictly increasing finite vector.');
end
if ~isnumeric(measuredSystemResponse) || ~isreal(measuredSystemResponse) || ...
        any(~isfinite(measuredSystemResponse(:))) || ...
        any(measuredSystemResponse(:)<0) || ...
        size(measuredSystemResponse,1)~=config.measurementCount || ...
        size(measuredSystemResponse,2)~=numel(lambda)
    error('VirtualQD:MeasuredResponse', ...
        'D must be a nonnegative measurementCount-by-numel(lambda) matrix.');
end

targetLambda = config.inputWavelength_nm(:).';
interpolated = zeros(config.measurementCount,numel(targetLambda));
for rowIndex = 1:config.measurementCount
    interpolated(rowIndex,:) = interp1(lambda, ...
        options.ResponseScale*measuredSystemResponse(rowIndex,:), ...
        targetLambda,'pchip',0);
end
interpolated = max(0,interpolated);

dark = options.DarkElectrons;
if ~isempty(dark) && numel(dark)~=config.measurementCount
    error('VirtualQD:MeasuredDark', ...
        'DarkElectrons must have one entry per measurement.');
end

calibratedConfig = config;
calibratedConfig.measuredSystemResponse = interpolated;
calibratedConfig.measuredDarkElectrons = dark(:);
calibratedConfig.calibration.mode = 'measured system response matrix';
calibratedConfig.calibration.label = char(options.Label);
calibratedConfig.calibration.absoluteEfficiencyMeasured = true;
calibratedConfig.calibration.responseMatrixMeasured = true;
calibratedConfig.validity.quantitativeHardwarePrediction = true;
calibratedConfig.validity.reason = ['Quantitative only within the wavelength, ' ...
    'bias, irradiance, temperature, and exposure scope of the supplied calibration.'];
end
