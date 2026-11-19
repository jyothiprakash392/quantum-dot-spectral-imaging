function [dualConfig,downConfig,upConfig] = ...
    initQDVoltageSelectedDualConverter(forceReset)
%INITQDVOLTAGESELECTEDDUALCONVERTER Compose the two independent branches.
%   Mode 0 is powered SWIR-to-visible upconversion. Mode 1 is passive,
%   voltage-selected UV-to-visible/NIR downconversion.

if nargin<1
    forceReset = false;
end
[upConfig,upResponse,swirSpectrum] = ...
    initQDSWIRUpconversionSpectrometer(forceReset);
[downConfig,downResponse] = initQDUVDownconverter(forceReset);

hasMode = evalin('base', ...
    "exist('qdConversionMode','var')==1 && isnumeric(qdConversionMode) && isscalar(qdConversionMode)");
if forceReset || ~hasMode
    conversionMode = 1;
else
    conversionMode = evalin('base','qdConversionMode');
    if ~isfinite(conversionMode) || ~any(round(conversionMode)==[0 1])
        warning('QDConverter:WorkspaceConversionMode', ...
            'Existing conversion mode was invalid and has been reset.');
        conversionMode = 1;
    else
        conversionMode = round(conversionMode);
    end
end

commonWavelength_nm = downConfig.outputWavelength_nm(:);
upToCommonMatrix = localPhotonConservingMap( ...
    upConfig.visibleWavelength_nm(:),commonWavelength_nm);
dualConfig = struct();
dualConfig.schemaVersion = '2.0.0';
dualConfig.systemName = 'QD Voltage-Selected Dual Converter';
dualConfig.mode = struct('upconversion',0,'downconversion',1, ...
    'default',conversionMode);
dualConfig.commonOutputWavelength_nm = commonWavelength_nm;
dualConfig.upToCommonMatrix = upToCommonMatrix;
dualConfig.detectorArchitecture = downConfig.detector.architecture;
dualConfig.calibrationLabel = ['UNMEASURED SYNTHETIC DEFAULT - both ' ...
    'branches require measured end-to-end calibration'];

assignin('base','qdDualConfig',dualConfig);
assignin('base','qdConversionMode',conversionMode);
assignin('base','qdCommonOutputWavelength_nm',commonWavelength_nm);
assignin('base','qdUpToCommonMatrix',upToCommonMatrix);
assignin('base','qdIncidentSpectrum',swirSpectrum);
assignin('base','qdSpectrometerConfig',upConfig);
assignin('base','qdSpectrometerResponse',upResponse);
assignin('base','qdHybridDetectorGain_ePerPhoton', ...
    downResponse.hybridDetectionGain_electronsPerPhoton);
end

function map = localPhotonConservingMap(source_nm,target_nm)
source_nm = source_nm(:);
target_nm = target_nm(:);
if source_nm(1)<target_nm(1) || source_nm(end)>target_nm(end)
    error('QDConverter:CommonOutputGrid', ...
        'Common output grid must contain the complete upconversion grid.');
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
