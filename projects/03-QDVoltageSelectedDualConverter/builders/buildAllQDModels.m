function modelFiles = buildAllQDModels(forceRebuild)
%BUILDALLQDMODELS Build the combined and two branch-level Simulink models.

if nargin<1
    forceRebuild = false;
end
setupQDVoltageSelectedDualConverter();
modelFiles = struct( ...
    'main',buildQDVoltageSelectedDualConverter(forceRebuild), ...
    'uvDownconverter',buildQDUVDownconverter(forceRebuild), ...
    'swirUpconverter',buildQDSWIRUpconversionSpectrometer(forceRebuild));
end
