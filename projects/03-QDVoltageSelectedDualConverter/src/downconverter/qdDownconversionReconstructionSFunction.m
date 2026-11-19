function qdDownconversionReconstructionSFunction(block)
%QDDOWNCONVERSIONRECONSTRUCTIONSFUNCTION Reconstruct UV spectrum in Simulink.
setup(block);
end

function setup(block)
config = localConfig();
block.NumDialogPrms = 0;
block.NumInputPorts = 2;
block.NumOutputPorts = 1;
block.InputPort(1).Dimensions = config.spectrometer.measurementCount;
block.InputPort(1).DatatypeID = 0;
block.InputPort(1).Complexity = 'Real';
block.InputPort(1).DirectFeedthrough = true;
block.InputPort(2).Dimensions = 1;
block.InputPort(2).DatatypeID = 0;
block.InputPort(2).Complexity = 'Real';
block.InputPort(2).DirectFeedthrough = true;
block.OutputPort(1).Dimensions = numel(config.inputWavelength_nm);
block.OutputPort(1).DatatypeID = 0;
block.OutputPort(1).Complexity = 'Real';
block.SampleTimes = [1 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('Outputs',@outputs);
end

function outputs(block)
config = localConfig();
response = qdBuildDownconversionResponse(config,block.InputPort(2).Data);
result = reconstructQDSpectrum(block.InputPort(1).Data,response, ...
    'Regularization',config.spectrometer.reconstructionRegularization, ...
    'MaxIterations',config.spectrometer.reconstructionMaxIterations);
block.OutputPort(1).Data = result.incidentPhotonsPerBin;
end

function config = localConfig()
if evalin('base',"exist('qdDownConfig','var')~=1")
    initQDUVDownconverter(false);
end
config = evalin('base','qdDownConfig');
end
