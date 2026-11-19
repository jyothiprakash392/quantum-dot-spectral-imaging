function modelFiles = startQDVoltageSelectedDualConverter(forceRebuild)
%STARTQDVOLTAGESELECTEDDUALCONVERTER Build, initialize, and open the system.

if nargin<1
    forceRebuild = false;
end
setupQDVoltageSelectedDualConverter();
modelFiles = buildAllQDModels(forceRebuild);
initQDVoltageSelectedDualConverter(false);
open_system(modelFiles.main);
end
