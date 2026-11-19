function [config,response,incidentSpectrum] = initQDUVDownconverter(forceReset)
%INITQDUVDOWNCONVERTER Initialize only the passive UV-downconversion branch.

if nargin<1
    forceReset = false;
end

hasConfig = evalin('base', ...
    "exist('qdDownConfig','var')==1 && isstruct(qdDownConfig)");
if forceReset || ~hasConfig
    config = qdDownconversionConfig();
else
    config = evalin('base','qdDownConfig');
    try
        qdBuildDownconversionResponse(config, ...
            config.selector.defaultVoltage_V);
    catch
        warning('QDConverter:WorkspaceDownConfig', ...
            'Existing qdDownConfig was invalid and has been reset.');
        config = qdDownconversionConfig();
    end
end

hasSpectrum = evalin('base', ...
    "exist('qdUVIncidentSpectrum','var')==1 && isnumeric(qdUVIncidentSpectrum)");
if forceReset || ~hasSpectrum
    incidentSpectrum = localDefaultUVSpectrum(config.inputWavelength_nm);
else
    incidentSpectrum = evalin('base','qdUVIncidentSpectrum');
    incidentSpectrum = incidentSpectrum(:);
    if numel(incidentSpectrum)~=numel(config.inputWavelength_nm) || ...
            any(~isfinite(incidentSpectrum)) || any(incidentSpectrum<0)
        warning('QDConverter:WorkspaceUVSpectrum', ...
            ['Existing qdUVIncidentSpectrum was invalid and has been ' ...
            'reset.']);
        incidentSpectrum = localDefaultUVSpectrum(config.inputWavelength_nm);
    end
end

hasSelector = evalin('base', ...
    "exist('qdSelectorVoltage_V','var')==1 && isnumeric(qdSelectorVoltage_V) && isscalar(qdSelectorVoltage_V)");
if forceReset || ~hasSelector
    selectorVoltage_V = config.selector.defaultVoltage_V;
else
    selectorVoltage_V = evalin('base','qdSelectorVoltage_V');
end
if ~isfinite(selectorVoltage_V) || ...
        selectorVoltage_V<config.selector.minimumVoltage_V || ...
        selectorVoltage_V>config.selector.maximumVoltage_V
    warning('QDConverter:WorkspaceSelectorVoltage', ...
        'Existing selector voltage was out of range and has been reset.');
    selectorVoltage_V = config.selector.defaultVoltage_V;
end

decoder = qdDecodeSelectorVoltage(selectorVoltage_V,config);
response = qdBuildDownconversionResponse(config,selectorVoltage_V);
commonWavelength_nm = config.outputWavelength_nm(:);

assignin('base','qdDownConfig',config);
assignin('base','qdDownResponseAtSelector',response);
assignin('base','qdSelectorDecoderAtCommand',decoder);
assignin('base','qdUVIncidentSpectrum',incidentSpectrum);
assignin('base','qdSelectorVoltage_V',selectorVoltage_V);
assignin('base','qdCommonOutputWavelength_nm',commonWavelength_nm);
assignin('base','qdHybridDetectorGain_ePerPhoton', ...
    response.hybridDetectionGain_electronsPerPhoton);
assignin('base','qdSiDetectorGain_ePerPhoton', ...
    response.siDetectionGain_electronsPerPhoton);
assignin('base','qdInGaAsDetectorGain_ePerPhoton', ...
    response.ingaasDetectionGain_electronsPerPhoton);
assignin('base','qdDualDetectorDarkElectrons', ...
    response.detectorDarkElectrons);
assignin('base','qdDualDetectorNoiseElectrons', ...
    zeros(numel(commonWavelength_nm),1));
end

function spectrum = localDefaultUVSpectrum(wavelength_nm)
wavelength_nm = wavelength_nm(:);
spectrum = 2.0e5*( ...
    0.65*localGaussian(wavelength_nm,300,18)+ ...
    1.00*localGaussian(wavelength_nm,365,24)+ ...
    0.55*localGaussian(wavelength_nm,405,14))+2.5e3;
end

function shape = localGaussian(x,center,fwhm)
shape = exp(-4*log(2)*((x-center)/fwhm).^2);
end
