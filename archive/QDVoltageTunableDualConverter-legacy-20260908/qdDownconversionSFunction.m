function qdDownconversionSFunction(block)
%QDDOWNCONVERSIONSFUNCTION Level-2 Simulink passive film-bank block.
setup(block);
end

function setup(block)
config = localConfig();
block.NumDialogPrms = 0;
block.NumInputPorts = 2;
block.NumOutputPorts = 3;

block.InputPort(1).Dimensions = numel(config.inputWavelength_nm);
block.InputPort(1).DatatypeID = 0;
block.InputPort(1).Complexity = 'Real';
block.InputPort(1).DirectFeedthrough = true;
block.InputPort(2).Dimensions = 1;
block.InputPort(2).DatatypeID = 0;
block.InputPort(2).Complexity = 'Real';
block.InputPort(2).DirectFeedthrough = true;

block.OutputPort(1).Dimensions = numel(config.outputWavelength_nm);
block.OutputPort(1).DatatypeID = 0;
block.OutputPort(1).Complexity = 'Real';
block.OutputPort(2).Dimensions = config.spectrometer.measurementCount;
block.OutputPort(2).DatatypeID = 0;
block.OutputPort(2).Complexity = 'Real';
block.OutputPort(3).Dimensions = 8;
block.OutputPort(3).DatatypeID = 0;
block.OutputPort(3).Complexity = 'Real';

block.SampleTimes = [1 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('Outputs',@outputs);
end

function outputs(block)
config = localConfig();
selectorVoltage_V = block.InputPort(2).Data;
observation = simulateQDDownconversion(block.InputPort(1).Data, ...
    selectorVoltage_V,config,'AddNoise',false);
block.OutputPort(1).Data = observation.conversion. ...
    outputSpectrumPhotonCountExpectedPerBin;
block.OutputPort(2).Data = observation.computationalCCD.totalElectronsExpected;
selectedIndex = observation.control.selectedFilmIndex;
block.OutputPort(3).Data = [ ...
    selectorVoltage_V; ...
    selectedIndex; ...
    config.film.emissionCenter_nm(selectedIndex); ...
    observation.conversion.peakWavelength_nm; ...
    observation.conversion.centroidWavelength_nm; ...
    observation.conversion.totalOutputPhotons; ...
    observation.conversion.photonYieldPerIncidentPhoton; ...
    observation.conversion.opticalEnergyEfficiency];
end

function config = localConfig()
if evalin('base',"exist('qdDownConfig','var')~=1")
    initQDVoltageTunableDualConverter(false);
end
config = evalin('base','qdDownConfig');
end
