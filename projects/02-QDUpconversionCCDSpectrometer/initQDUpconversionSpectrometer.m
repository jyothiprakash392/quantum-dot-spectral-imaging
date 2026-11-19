function [config,response,incidentSpectrum] = initQDUpconversionSpectrometer(forceReset)
%INITQDUPCONVERSIONSPECTROMETER Initialize base-workspace Simulink variables.
%   INITQDUPCONVERSIONSPECTROMETER preserves an existing spectral input by
%   default. Pass TRUE to restore the supplied demonstration spectrum.

if nargin < 1
    forceReset = false;
end
rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);

hasConfig = evalin('base', ...
    "exist('qdSpectrometerConfig','var')==1 && isstruct(qdSpectrometerConfig)");
if forceReset || ~hasConfig
    config = qdUpconversionSpectrometerConfig();
else
    config = evalin('base','qdSpectrometerConfig');
end
response = qdBuildSpectralResponse(config);

hasSpectrum = evalin('base', ...
    "exist('qdIncidentSpectrum','var')==1 && isnumeric(qdIncidentSpectrum)");
if forceReset || ~hasSpectrum
    wavelength_nm = config.inputWavelength_nm(:);
    incidentSpectrum = 1.8e6*( ...
        0.80*localGaussian(wavelength_nm,1275,38)+ ...
        0.45*localGaussian(wavelength_nm,1435,62)+ ...
        1.00*localGaussian(wavelength_nm,1600,32))+2.5e4;
else
    incidentSpectrum = evalin('base','qdIncidentSpectrum');
    incidentSpectrum = incidentSpectrum(:);
    if numel(incidentSpectrum)~=numel(config.inputWavelength_nm) || ...
            any(~isfinite(incidentSpectrum)) || any(incidentSpectrum<0)
        warning('VirtualQD:WorkspaceSpectrum', ...
            'Existing qdIncidentSpectrum was invalid and has been reset.');
        wavelength_nm = config.inputWavelength_nm(:);
        incidentSpectrum = 1.8e6*( ...
            0.80*localGaussian(wavelength_nm,1275,38)+ ...
            0.45*localGaussian(wavelength_nm,1435,62)+ ...
            1.00*localGaussian(wavelength_nm,1600,32))+2.5e4;
    end
end

measurementCount = config.measurementCount;
qdCCDdarkElectrons = response.darkElectronsExpected;
qdCCDNoiseElectrons = zeros(measurementCount,1);

assignin('base','qdSpectrometerConfig',config);
assignin('base','qdSpectrometerResponse',response);
assignin('base','qdIncidentSpectrum',incidentSpectrum);
assignin('base','qdCCDdarkElectrons',qdCCDdarkElectrons);
assignin('base','qdCCDNoiseElectrons',qdCCDNoiseElectrons);
end

function shape = localGaussian(x,center,fwhm)
shape = exp(-4*log(2)*((x-center)/fwhm).^2);
end
