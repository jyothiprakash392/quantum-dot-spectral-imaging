function qdAgentSFunction(block)
%QDAGENTSFUNCTION Interpreted Level-2 S-function for the Simulink agent.
%   Keeping the high-fidelity finite-well solver interpreted avoids a long
%   code-generation compile and makes calibration edits immediately active.
setup(block);
end

function setup(block)
block.NumDialogPrms = 0;
block.NumInputPorts = 1;
block.NumOutputPorts = 1;

block.InputPort(1).Dimensions = 14;
block.InputPort(1).DatatypeID = 0; % double
block.InputPort(1).Complexity = 'Real';
block.InputPort(1).DirectFeedthrough = true;

block.OutputPort(1).Dimensions = 40;
block.OutputPort(1).DatatypeID = 0; % double
block.OutputPort(1).Complexity = 'Real';

block.SampleTimes = [1.0e-11 0];
block.SimStateCompliance = 'DefaultSimState';

block.RegBlockMethod('PostPropagationSetup',@postPropagationSetup);
block.RegBlockMethod('InitializeConditions',@initializeConditions);
block.RegBlockMethod('Outputs',@outputs);
block.RegBlockMethod('Update',@update);
block.RegBlockMethod('Terminate',@terminate);
end

function postPropagationSetup(block)
block.NumDworks = 1;
block.Dwork(1).Name = 'populations';
block.Dwork(1).Dimensions = 4;
block.Dwork(1).DatatypeID = 0;
block.Dwork(1).Complexity = 'Real';
block.Dwork(1).UsedAsDiscState = true;
end

function initializeConditions(block)
block.Dwork(1).Data = [1;0;0;0];
end

function outputs(block)
[yCurrent,~] = qdPhysicsStep(block.InputPort(1).Data,block.Dwork(1).Data,0);
[yInterval,~] = qdPhysicsStep(block.InputPort(1).Data,block.Dwork(1).Data,1.0e-11);
% Populations and static observables describe the current timestamp. The
% three event-rate outputs are exact averages over the upcoming sample, so
% the external discrete accumulators reproduce the integrated Markov rewards.
yCurrent([25 38 39]) = yInterval([25 38 39]);
yCurrent(31) = double(bitor(uint32(round(yCurrent(31))), ...
    uint32(round(yInterval(31)))));
block.OutputPort(1).Data = yCurrent;
end

function update(block)
[~,pNext] = qdPhysicsStep(block.InputPort(1).Data,block.Dwork(1).Data);
block.Dwork(1).Data = pNext;
end

function terminate(~)
end
