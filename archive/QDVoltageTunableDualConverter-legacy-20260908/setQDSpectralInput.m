function incidentSpectrum = setQDSpectralInput(varargin)
%SETQDSPECTRALINPUT Set the Simulink input spectrum without rebuilding.
%   SETQDSPECTRALINPUT(COUNTS) sets one photon count per configured bin.
%   SETQDSPECTRALINPUT(LAMBDA,COUNTS) interpolates measurements supplied on
%   a strictly increasing wavelength grid. Counts are treated as values per
%   bin, not a continuous density.

if evalin('base',"exist('qdSpectrometerConfig','var')~=1")
    initQDUpconversionSpectrometer();
end
config = evalin('base','qdSpectrometerConfig');
if nargin == 1
    incidentSpectrum = varargin{1}(:);
elseif nargin == 2
    wavelength_nm = varargin{1}(:);
    supplied = varargin{2}(:);
    if numel(wavelength_nm)~=numel(supplied) || numel(wavelength_nm)<2 || ...
            any(~isfinite(wavelength_nm)) || any(diff(wavelength_nm)<=0)
        error('VirtualQD:SpectralInputGrid', ...
            'Wavelength and count vectors must match and wavelengths must increase.');
    end
    incidentSpectrum = interp1(wavelength_nm,supplied, ...
        config.inputWavelength_nm(:),'pchip',0);
    incidentSpectrum = max(0,incidentSpectrum);
else
    error('VirtualQD:SpectralInputArguments', ...
        'Use setQDSpectralInput(counts) or setQDSpectralInput(lambda,counts).');
end
if numel(incidentSpectrum)~=numel(config.inputWavelength_nm) || ...
        ~isnumeric(incidentSpectrum) || ~isreal(incidentSpectrum) || ...
        any(~isfinite(incidentSpectrum)) || any(incidentSpectrum<0)
    error('VirtualQD:IncidentSpectrum', ...
        'Spectrum must contain one finite nonnegative count per configured bin.');
end
assignin('base','qdIncidentSpectrum',incidentSpectrum);
end
