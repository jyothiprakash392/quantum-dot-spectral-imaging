function qdSpectralTelemetrySFunction(block)
%QDSPECTRALTELEMETRYSFUNCTION Compute peak, centroid, and photon totals.
setup(block);
end

function setup(block)
wavelength_nm = localWavelength();
block.NumDialogPrms = 0;
block.NumInputPorts = 2;
block.NumOutputPorts = 1;
for inputIndex = 1:2
    block.InputPort(inputIndex).Dimensions = numel(wavelength_nm);
    block.InputPort(inputIndex).DatatypeID = 0;
    block.InputPort(inputIndex).Complexity = 'Real';
    block.InputPort(inputIndex).DirectFeedthrough = true;
end
block.OutputPort(1).Dimensions = 4;
block.OutputPort(1).DatatypeID = 0;
block.OutputPort(1).Complexity = 'Real';
block.SampleTimes = [1 0];
block.SimStateCompliance = 'DefaultSimState';
block.RegBlockMethod('Outputs',@outputs);
end

function outputs(block)
wavelength_nm = localWavelength();
photons = max(0,block.InputPort(1).Data(:));
electrons = max(0,block.InputPort(2).Data(:));
totalPhotons = sum(photons);
if totalPhotons>0
    [~,peakIndex] = max(photons);
    peak_nm = wavelength_nm(peakIndex);
    centroid_nm = sum(wavelength_nm.*photons)/totalPhotons;
else
    peak_nm = NaN;
    centroid_nm = NaN;
end
block.OutputPort(1).Data = [peak_nm;centroid_nm;totalPhotons;sum(electrons)];
end

function wavelength_nm = localWavelength()
if evalin('base',"exist('qdCommonOutputWavelength_nm','var')~=1")
    initQDUVDownconverter(false);
end
wavelength_nm = evalin('base','qdCommonOutputWavelength_nm');
wavelength_nm = wavelength_nm(:);
end
