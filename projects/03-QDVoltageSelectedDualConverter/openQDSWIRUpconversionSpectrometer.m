function modelFile = openQDSWIRUpconversionSpectrometer()
%OPENQDSWIRUPCONVERSIONSPECTROMETER Initialize and open the SWIR branch.
setupQDVoltageSelectedDualConverter();
initQDSWIRUpconversionSpectrometer(false);
modelFile = buildQDSWIRUpconversionSpectrometer(false);
open_system(modelFile);
end
