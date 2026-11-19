function [config,response,incidentSpectrum] = ...
    initQDSWIRUpconversionSpectrometer(forceReset)
%INITQDSWIRUPCONVERSIONSPECTROMETER Initialize only the powered SWIR branch.

if nargin<1
    forceReset = false;
end
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
    incidentSpectrum = localDefaultSWIRSpectrum(config.inputWavelength_nm);
else
    incidentSpectrum = evalin('base','qdIncidentSpectrum');
    incidentSpectrum = incidentSpectrum(:);
    if numel(incidentSpectrum)~=numel(config.inputWavelength_nm) || ...
            any(~isfinite(incidentSpectrum)) || any(incidentSpectrum<0)
        warning('QDConverter:WorkspaceSWIRSpectrum', ...
            ['Existing qdIncidentSpectrum was invalid and has been ' ...
            'reset.']);
        incidentSpectrum = localDefaultSWIRSpectrum(config.inputWavelength_nm);
    end
end

assignin('base','qdSpectrometerConfig',config);
assignin('base','qdSpectrometerResponse',response);
assignin('base','qdIncidentSpectrum',incidentSpectrum);
assignin('base','qdCCDdarkElectrons',response.darkElectronsExpected);
assignin('base','qdCCDNoiseElectrons',zeros(config.measurementCount,1));
end

function spectrum = localDefaultSWIRSpectrum(wavelength_nm)
wavelength_nm = wavelength_nm(:);
spectrum = 1.8e6*( ...
    0.80*localGaussian(wavelength_nm,1275,38)+ ...
    0.45*localGaussian(wavelength_nm,1435,62)+ ...
    1.00*localGaussian(wavelength_nm,1600,32))+2.5e4;
end

function shape = localGaussian(x,center,fwhm)
shape = exp(-4*log(2)*((x-center)/fwhm).^2);
end
