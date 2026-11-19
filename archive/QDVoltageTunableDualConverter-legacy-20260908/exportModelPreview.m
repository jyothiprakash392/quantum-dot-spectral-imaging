function previewFile = exportModelPreview()
%EXPORTMODELPREVIEW Save a readable PNG of the generated Simulink diagram.
rootFolder = fileparts(mfilename('fullpath'));
modelName = 'VirtualQuantumDotAgent';
modelFile = fullfile(rootFolder,[modelName '.slx']);
addpath(rootFolder);
if ~isfile(modelFile)
    buildVirtualQuantumDotAgent(false);
else
    load_system(modelFile);
end
previewFile = fullfile(rootFolder,'VirtualQuantumDotAgent_Diagram.png');
set_param(modelName,'ZoomFactor','FitSystem');
print(['-s' modelName],'-dpng','-r160',previewFile);
end
