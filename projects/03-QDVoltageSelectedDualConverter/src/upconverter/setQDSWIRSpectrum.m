function incidentSpectrum = setQDSWIRSpectrum(varargin)
%SETQDSWIRSPECTRUM Set the SWIR branch spectrum without rebuilding a model.

if evalin('base',"exist('qdSpectrometerConfig','var')~=1")
    initQDSWIRUpconversionSpectrometer(false);
end
config = evalin('base','qdSpectrometerConfig');
if nargin==1
    incidentSpectrum = varargin{1}(:);
elseif nargin==2
    wavelength_nm = varargin{1}(:);
    supplied = varargin{2}(:);
    if numel(wavelength_nm)~=numel(supplied) || numel(wavelength_nm)<2 || ...
            any(~isfinite(wavelength_nm)) || any(diff(wavelength_nm)<=0)
        error('QDConverter:SpectralInputGrid', ...
            'Wavelength and count vectors must match and increase.');
    end
    incidentSpectrum = max(0,interp1(wavelength_nm,supplied, ...
        config.inputWavelength_nm(:),'pchip',0));
else
    error('QDConverter:SpectralInputArguments', ...
        'Use setQDSWIRSpectrum(counts) or setQDSWIRSpectrum(lambda,counts).');
end
if ~isnumeric(incidentSpectrum) || ~isreal(incidentSpectrum) || ...
        numel(incidentSpectrum)~=numel(config.inputWavelength_nm) || ...
        any(~isfinite(incidentSpectrum)) || any(incidentSpectrum<0)
    error('QDConverter:IncidentSpectrum', ...
        'Spectrum must have one finite nonnegative count per configured bin.');
end
assignin('base','qdIncidentSpectrum',incidentSpectrum);
end
