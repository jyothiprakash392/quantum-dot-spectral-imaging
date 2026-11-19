function demos = runAllQDConverterDemos()
%RUNALLQDCONVERTERDEMOS Generate the three canonical demonstrations.

setupQDVoltageSelectedDualConverter();
demos = struct();
demos.selector = runQDSelectorDemo();
demos.uvDownconverter = runQDUVDownconverterDemo();
demos.swirUpconverter = runQDSWIRUpconversionDemo();
demos.modelDiagrams = exportQDModelDiagrams();
end
