function modelFile = openQDVoltageSelectedDualConverter()
%OPENQDVOLTAGESELECTEDDUALCONVERTER Initialize and open the combined model.
setupQDVoltageSelectedDualConverter();
initQDVoltageSelectedDualConverter(false);
modelFile = buildQDVoltageSelectedDualConverter(false);
open_system(modelFile);
end
