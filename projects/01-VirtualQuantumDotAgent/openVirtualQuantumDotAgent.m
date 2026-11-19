function modelFile = openVirtualQuantumDotAgent()
%OPENVIRTUALQUANTUMDOTAGENT One-command launcher for MATLAB/Simulink.
rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
qdEnsureWorkspace();
modelFile = fullfile(rootFolder,'VirtualQuantumDotAgent.slx');
if ~isfile(modelFile)
    modelFile = buildVirtualQuantumDotAgent(false);
else
    load_system(modelFile);
    open_system('VirtualQuantumDotAgent');
end
end
