function qdSpectralReconstructionSFunction(block)
%QDSPECTRALRECONSTRUCTIONSFUNCTION Interpreted Simulink reconstruction block.
setup(block);
end

function setup(block)
response = localResponse();
block.NumDialogPrms = 0;
block.NumInputPorts = 1;
block.NumOutputPorts = 1;
block.InputPort(1).Dimensions = ...
    size(response.systemMatrix_electronsPerIncidentPhoton,1);
block.InputPort(1).DatatypeID = 0;
block.InputPort(1).Complexity = 'Real';
block.InputPort(1).DirectFeedthrough = true;
block.OutputPort(1).Dimensions = ...
    size(response.systemMatrix_electronsPerIncidentPhoton,2);
block.OutputPort(1).DatatypeID = 0;
block.OutputPort(1).Complexity = 'Real';
block.SampleTimes = [1 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('Outputs',@outputs);
end

function outputs(block)
response = localResponse();
config = evalin('base','qdSpectrometerConfig');
result = reconstructQDSpectrum(block.InputPort(1).Data,response, ...
    'Regularization',config.reconstruction.regularization, ...
    'MaxIterations',config.reconstruction.maxIterations);
block.OutputPort(1).Data = result.incidentPhotonsPerBin;
end

function response = localResponse()
if evalin('base',"exist('qdSpectrometerResponse','var')~=1")
    initQDSWIRUpconversionSpectrometer();
end
response = evalin('base','qdSpectrometerResponse');
end
