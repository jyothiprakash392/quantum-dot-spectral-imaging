function modelFile = openQDVoltageTunableDownconverter()
%OPENQDVOLTAGETUNABLEDOWNCONVERTER Initialize and open the focused model.
rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
initQDVoltageTunableDualConverter(false);
modelFile = buildQDVoltageTunableDownconverter(false);
open_system('QDVoltageTunableDownconverter');
end
