function modelFile = openQDUVDownconverter()
%OPENQDUVDOWNCONVERTER Initialize and open the standalone UV branch.
setupQDVoltageSelectedDualConverter();
initQDUVDownconverter(false);
modelFile = buildQDUVDownconverter(false);
open_system(modelFile);
end
