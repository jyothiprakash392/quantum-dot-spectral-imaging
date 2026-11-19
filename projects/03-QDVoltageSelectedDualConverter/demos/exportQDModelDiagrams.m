function diagramFiles = exportQDModelDiagrams()
%EXPORTQDMODELDIAGRAMS Export readable PNG previews of all supported models.

paths = setupQDVoltageSelectedDualConverter();
models = buildAllQDModels(false);
modelFiles = {models.main;models.uvDownconverter;models.swirUpconverter};
outputNames = { ...
    'qd-voltage-selected-dual-converter-diagram.png'; ...
    'uv-downconverter-diagram.png'; ...
    'swir-upconversion-spectrometer-diagram.png'};
diagramFiles = strings(numel(modelFiles),1);
for modelIndex = 1:numel(modelFiles)
    modelFile = modelFiles{modelIndex};
    [~,modelName] = fileparts(modelFile);
    if bdIsLoaded(modelName), close_system(modelName,0); end
    load_system(modelFile);
    set_param(modelName,'ZoomFactor','FitSystem');
    diagramFiles(modelIndex) = fullfile(paths.figures, ...
        outputNames{modelIndex});
    print(['-s' modelName],'-dpng','-r180',diagramFiles(modelIndex));
    close_system(modelName,0);
end
end
