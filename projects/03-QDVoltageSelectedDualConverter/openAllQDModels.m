function modelFiles = openAllQDModels(forceRebuild)
%OPENALLQDMODELS Build if needed, then open all three supported SLX models.

if nargin<1
    forceRebuild = false;
end
setupQDVoltageSelectedDualConverter();
modelFiles = buildAllQDModels(forceRebuild);
open_system(modelFiles.main);
open_system(modelFiles.uvDownconverter);
open_system(modelFiles.swirUpconverter);
end
