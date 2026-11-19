function [dualConfig,downConfig,upConfig] = ...
    initQDVoltageTunableDualConverter(forceReset)
%INITQDVOLTAGETUNABLEDUALCONVERTER Initialize both conversion branches.
%   The routine preserves valid workspace inputs and selector values unless
%   FORCERESET is true. Conversion mode 0 is powered SWIR-to-visible
%   up-conversion; mode 1 is passive UV-to-visible/NIR down-conversion.

if nargin<1
    forceReset = false;
end
rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);

% Reuse the validated up-conversion initialization and response.
[upConfig,upResponse,swirSpectrum] = ...
    initQDUpconversionSpectrometer(forceReset);

hasDownConfig = evalin('base', ...
    "exist('qdDownConfig','var')==1 && isstruct(qdDownConfig)");
if forceReset || ~hasDownConfig
    downConfig = qdDownconversionConfig();
else
    downConfig = evalin('base','qdDownConfig');
    try
        qdBuildDownconversionResponse(downConfig, ...
            downConfig.selector.defaultVoltage_V);
        if ~isfield(downConfig.selector,'channelVoltage_V')
            downConfig.selector.channelVoltage_V = ...
                downConfig.selector.detentVoltage_V;
        end
        if strcmp(downConfig.selector.mode,'nearest_detent')
            downConfig.selector.mode = 'nearest_channel';
        elseif strcmp(downConfig.selector.mode,'adjacent_crossfade')
            downConfig.selector.mode = 'adjacent_channel_blend';
        end
        channelVoltages_V = downConfig.selector.channelVoltage_V(:);
        if ~isfield(downConfig.selector,'thresholdVoltage_V')
            downConfig.selector.thresholdVoltage_V = 0.5*( ...
                channelVoltages_V(1:end-1)+channelVoltages_V(2:end));
        end
        if ~isfield(downConfig.selector,'hysteresis_V')
            downConfig.selector.hysteresis_V = min(0.02, ...
                0.1*min(diff(channelVoltages_V)));
        end
        if ~isfield(downConfig.selector,'adc')
            referenceVoltage_V = max(3.3,channelVoltages_V(end));
            resolution_bits = 12;
            downConfig.selector.adc = struct( ...
                'resolution_bits',resolution_bits, ...
                'referenceVoltage_V',referenceVoltage_V, ...
                'leastSignificantBit_V',referenceVoltage_V/ ...
                    (2^resolution_bits-1));
        end
        if ~isfield(downConfig.selector,'hardwareArchitecture')
            downConfig.selector.hardwareArchitecture = [ ...
                'ADC plus voltage-window decoder driving an analog ' ...
                'multiplexer, electronic shutter, or electro-optic gate bank'];
        end
        if ~isfield(downConfig.selector,'logicOutput')
            downConfig.selector.logicOutput = ...
                'one-hot 1-of-6 solid-state gate command';
        end
    catch
        warning('VirtualQD:WorkspaceDownConfig', ...
            'Existing qdDownConfig was invalid and has been reset.');
        downConfig = qdDownconversionConfig();
    end
end

hasUVSpectrum = evalin('base', ...
    "exist('qdUVIncidentSpectrum','var')==1 && isnumeric(qdUVIncidentSpectrum)");
if forceReset || ~hasUVSpectrum
    uvSpectrum = localDefaultUVSpectrum(downConfig.inputWavelength_nm);
else
    uvSpectrum = evalin('base','qdUVIncidentSpectrum');
    uvSpectrum = uvSpectrum(:);
    if numel(uvSpectrum)~=numel(downConfig.inputWavelength_nm) || ...
            any(~isfinite(uvSpectrum)) || any(uvSpectrum<0)
        warning('VirtualQD:WorkspaceUVSpectrum', ...
            'Existing qdUVIncidentSpectrum was invalid and has been reset.');
        uvSpectrum = localDefaultUVSpectrum(downConfig.inputWavelength_nm);
    end
end

hasSelector = evalin('base', ...
    "exist('qdSelectorVoltage_V','var')==1 && isnumeric(qdSelectorVoltage_V) && isscalar(qdSelectorVoltage_V)");
hasLegacySelector = evalin('base', ...
    "exist('qdRotorVoltage_V','var')==1 && isnumeric(qdRotorVoltage_V) && isscalar(qdRotorVoltage_V)");
if forceReset || (~hasSelector && ~hasLegacySelector)
    selectorVoltage_V = downConfig.selector.defaultVoltage_V;
elseif hasSelector
    selectorVoltage_V = evalin('base','qdSelectorVoltage_V');
else
    % Import the old variable once so saved scripts remain usable.
    selectorVoltage_V = evalin('base','qdRotorVoltage_V');
end
if ~isfinite(selectorVoltage_V) || ...
        selectorVoltage_V<downConfig.selector.minimumVoltage_V || ...
        selectorVoltage_V>downConfig.selector.maximumVoltage_V
    warning('VirtualQD:WorkspaceSelectorVoltage', ...
        'Existing selector voltage was out of range and has been reset.');
    selectorVoltage_V = downConfig.selector.defaultVoltage_V;
end

hasMode = evalin('base', ...
    "exist('qdConversionMode','var')==1 && isnumeric(qdConversionMode) && isscalar(qdConversionMode)");
if forceReset || ~hasMode
    conversionMode = 1;
else
    conversionMode = evalin('base','qdConversionMode');
    if ~isfinite(conversionMode) || ~any(round(conversionMode)==[0 1])
        warning('VirtualQD:WorkspaceConversionMode', ...
            'Existing qdConversionMode was invalid and has been reset.');
        conversionMode = 1;
    else
        conversionMode = round(conversionMode);
    end
end

downDecoder = qdDecodeSelectorVoltage(selectorVoltage_V,downConfig);
downResponse = qdBuildDownconversionResponse(downConfig,selectorVoltage_V);
commonWavelength_nm = downConfig.outputWavelength_nm(:);
upToCommonMatrix = localPhotonConservingMap( ...
    upConfig.visibleWavelength_nm(:),commonWavelength_nm);

dualConfig = struct();
dualConfig.schemaVersion = '1.0.0';
dualConfig.systemName = 'QD Dual Up/Down Conversion and Detection System';
dualConfig.mode = struct('upconversion',0,'downconversion',1, ...
    'default',conversionMode);
dualConfig.commonOutputWavelength_nm = commonWavelength_nm;
dualConfig.upToCommonMatrix = upToCommonMatrix;
dualConfig.detectorArchitecture = downConfig.detector.architecture;
dualConfig.calibrationLabel = ['COMBINED SYNTHETIC DEFAULT - both device ' ...
    'branches require measured end-to-end calibration'];

assignin('base','qdDualConfig',dualConfig);
assignin('base','qdDownConfig',downConfig);
assignin('base','qdDownResponseAtSelector',downResponse);
assignin('base','qdSelectorDecoderAtCommand',downDecoder);
assignin('base','qdDownResponseAtRotor',downResponse); % Legacy alias.
assignin('base','qdUVIncidentSpectrum',uvSpectrum);
assignin('base','qdSelectorVoltage_V',selectorVoltage_V);
assignin('base','qdRotorVoltage_V',selectorVoltage_V); % Legacy alias.
assignin('base','qdConversionMode',conversionMode);
assignin('base','qdCommonOutputWavelength_nm',commonWavelength_nm);
assignin('base','qdUpToCommonMatrix',upToCommonMatrix);
assignin('base','qdHybridDetectorGain_ePerPhoton', ...
    downResponse.hybridDetectionGain_electronsPerPhoton);
assignin('base','qdSiDetectorGain_ePerPhoton', ...
    downResponse.siDetectionGain_electronsPerPhoton);
assignin('base','qdInGaAsDetectorGain_ePerPhoton', ...
    downResponse.ingaasDetectionGain_electronsPerPhoton);
assignin('base','qdDualDetectorDarkElectrons', ...
    downResponse.detectorDarkElectrons);
assignin('base','qdDualDetectorNoiseElectrons', ...
    zeros(numel(commonWavelength_nm),1));
assignin('base','qdIncidentSpectrum',swirSpectrum);
assignin('base','qdSpectrometerConfig',upConfig);
assignin('base','qdSpectrometerResponse',upResponse);
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

function map = localPhotonConservingMap(source_nm,target_nm)
% Piecewise-linear bin mapping with every source-column summing to one.
source_nm = source_nm(:);
target_nm = target_nm(:);
if source_nm(1)<target_nm(1) || source_nm(end)>target_nm(end)
    error('VirtualQD:CommonOutputGrid', ...
        'Common output grid must contain the complete up-conversion grid.');
end
map = zeros(numel(target_nm),numel(source_nm));
for sourceIndex = 1:numel(source_nm)
    value = source_nm(sourceIndex);
    upperIndex = find(target_nm>=value,1,'first');
    if target_nm(upperIndex)==value || upperIndex==1
        map(upperIndex,sourceIndex) = 1;
    else
        lowerIndex = upperIndex-1;
        upperWeight = (value-target_nm(lowerIndex))/ ...
            (target_nm(upperIndex)-target_nm(lowerIndex));
        map(lowerIndex,sourceIndex) = 1-upperWeight;
        map(upperIndex,sourceIndex) = upperWeight;
    end
end
end
