function qdElectronicSelectorDecoderSFunction(block)
%QDELECTRONICSELECTORDECODERSFUNCTION ADC/window decoder for Simulink.
setup(block);
end

function setup(block)
config = localConfig();
block.NumDialogPrms = 0;
block.NumInputPorts = 1;
block.NumOutputPorts = 3;
block.InputPort(1).Dimensions = 1;
block.InputPort(1).DatatypeID = 0;
block.InputPort(1).Complexity = 'Real';
block.InputPort(1).DirectFeedthrough = true;
block.OutputPort(1).Dimensions = 1;
block.OutputPort(1).DatatypeID = 0;
block.OutputPort(1).Complexity = 'Real';
block.OutputPort(2).Dimensions = config.filmCount;
block.OutputPort(2).DatatypeID = 0;
block.OutputPort(2).Complexity = 'Real';
block.OutputPort(3).Dimensions = 6;
block.OutputPort(3).DatatypeID = 0;
block.OutputPort(3).Complexity = 'Real';
block.SampleTimes = [1 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('PostPropagationSetup',@postPropagationSetup);
block.RegBlockMethod('InitializeConditions',@initializeConditions);
block.RegBlockMethod('Outputs',@outputs);
block.RegBlockMethod('Update',@update);
end

function postPropagationSetup(block)
block.NumDworks = 1;
block.Dwork(1).Name = 'previousChannelIndex';
block.Dwork(1).Dimensions = 1;
block.Dwork(1).DatatypeID = 0;
block.Dwork(1).Complexity = 'Real';
block.Dwork(1).UsedAsDiscState = true;
end

function initializeConditions(block)
config = localConfig();
decoder = qdDecodeSelectorVoltage( ...
    config.selector.defaultVoltage_V,config);
block.Dwork(1).Data = decoder.selectedChannelIndex;
end

function outputs(block)
config = localConfig();
decoder = qdDecodeSelectorVoltage(block.InputPort(1).Data,config, ...
    'PreviousChannelIndex',block.Dwork(1).Data);
block.OutputPort(1).Data = decoder.selectedChannelVoltage_V;
block.OutputPort(2).Data = decoder.oneHotGates;
block.OutputPort(3).Data = [ ...
    decoder.commandVoltage_V; ...
    decoder.adcVoltage_V; ...
    decoder.selectedChannelIndex; ...
    decoder.selectedChannelVoltage_V; ...
    decoder.nominalEmissionWavelength_nm; ...
    decoder.thresholdMargin_V];
end

function update(block)
config = localConfig();
decoder = qdDecodeSelectorVoltage(block.InputPort(1).Data,config, ...
    'PreviousChannelIndex',block.Dwork(1).Data);
block.Dwork(1).Data = decoder.selectedChannelIndex;
end

function config = localConfig()
if evalin('base',"exist('qdDownConfig','var')~=1")
    initQDVoltageTunableDualConverter(false);
end
config = evalin('base','qdDownConfig');
end
