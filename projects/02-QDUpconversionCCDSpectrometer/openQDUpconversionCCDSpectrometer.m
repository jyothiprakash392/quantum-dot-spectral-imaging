function openQDUpconversionCCDSpectrometer()
%OPENQDUPCONVERSIONCCDSPECTROMETER Initialize and open the runnable model.
rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
initQDUpconversionSpectrometer(false);
modelFile = buildQDUpconversionCCDSpectrometer(false);
open_system(modelFile);
end
