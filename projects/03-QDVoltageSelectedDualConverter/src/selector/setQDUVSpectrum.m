function incidentSpectrum = setQDUVSpectrum(varargin)
%SETQDUVSPECTRUM Set the UV branch spectrum without rebuilding a model.

if evalin('base',"exist('qdDownConfig','var')~=1")
    initQDUVDownconverter(false);
end
config = evalin('base','qdDownConfig');
incidentSpectrum = localValidateSpectrum(config.inputWavelength_nm,varargin{:});
assignin('base','qdUVIncidentSpectrum',incidentSpectrum);
end

function spectrum = localValidateSpectrum(targetWavelength_nm,varargin)
if isscalar(varargin)
    spectrum = varargin{1}(:);
elseif numel(varargin)==2
    wavelength_nm = varargin{1}(:);
    supplied = varargin{2}(:);
    if numel(wavelength_nm)~=numel(supplied) || numel(wavelength_nm)<2 || ...
            any(~isfinite(wavelength_nm)) || any(diff(wavelength_nm)<=0)
        error('QDConverter:SpectralInputGrid', ...
            'Wavelength and count vectors must match and increase.');
    end
    spectrum = max(0,interp1(wavelength_nm,supplied, ...
        targetWavelength_nm(:),'pchip',0));
else
    error('QDConverter:SpectralInputArguments', ...
        'Use setQDUVSpectrum(counts) or setQDUVSpectrum(lambda,counts).');
end
if ~isnumeric(spectrum) || ~isreal(spectrum) || ...
        numel(spectrum)~=numel(targetWavelength_nm) || ...
        any(~isfinite(spectrum)) || any(spectrum<0)
    error('QDConverter:IncidentSpectrum', ...
        'Spectrum must have one finite nonnegative count per configured bin.');
end
end
