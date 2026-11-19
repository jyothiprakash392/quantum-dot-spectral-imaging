function modelFile = openQDDualConversionSystem()
%OPENQDDUALCONVERSIONSYSTEM Initialize and open the attached dual model.
rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
initQDVoltageTunableDualConverter(false);
modelFile = buildQDDualConversionSystem(false);
open_system('QDDualConversionSystem');
end
