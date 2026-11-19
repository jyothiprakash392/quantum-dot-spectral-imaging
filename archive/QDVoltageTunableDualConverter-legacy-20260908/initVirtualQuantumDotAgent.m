function qdInput = initVirtualQuantumDotAgent()
%INITVIRTUALQUANTUMDOTAGENT Put documented model variables in the base workspace.

modelFolder = fileparts(mfilename('fullpath'));
addpath(modelFolder);
qdInput = qdDefaultInputs();
QD_SAMPLE_TIME_S = 1.0e-11;
QD_OUTPUT_NAMES = qdOutputNames();
QD_INPUT_NAMES = qdInputNames();
QD_PUBLIC_INPUT_NAMES = qdPublicInputNames();
QD_PHOTON_COUNT_NAMES = qdPhotonCountNames();
QD_MODEL_VERSION = '1.5.1';

assignin('base','qdInput',qdInput);
assignin('base','QD_SAMPLE_TIME_S',QD_SAMPLE_TIME_S);
assignin('base','QD_OUTPUT_NAMES',QD_OUTPUT_NAMES);
assignin('base','QD_INPUT_NAMES',QD_INPUT_NAMES);
assignin('base','QD_PUBLIC_INPUT_NAMES',QD_PUBLIC_INPUT_NAMES);
assignin('base','QD_PHOTON_COUNT_NAMES',QD_PHOTON_COUNT_NAMES);
assignin('base','QD_MODEL_VERSION',QD_MODEL_VERSION);
end
