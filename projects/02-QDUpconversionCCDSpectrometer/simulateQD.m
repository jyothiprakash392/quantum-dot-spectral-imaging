function result = simulateQD(varargin)
%SIMULATEQD Callable tool for the virtual quantum-dot physics engine.
%   RESULT = SIMULATEQD('radius_nm',3,'temperature_K',300,...)
%   accepts every qdDefaultInputs field plus Duration_ns and
%   InitialProbabilities. A structure may be supplied as the first input.
%   incidentPhotonCount > 0 enables the lambda1/count square-pulse adapter.

inputs = qdDefaultInputs();
if ~isempty(varargin) && isstruct(varargin{1})
    supplied = varargin{1};
    suppliedNames = fieldnames(supplied);
    for k = 1:numel(suppliedNames)
        if ~isfield(inputs,suppliedNames{k})
            error('VirtualQD:UnknownInput', ...
                'Unknown structure field "%s".',suppliedNames{k});
        end
        inputs.(suppliedNames{k}) = supplied.(suppliedNames{k});
    end
    varargin = varargin(2:end);
end

parser = inputParser;
parser.FunctionName = 'simulateQD';
inputNames = qdPublicInputNames();
scalarValidator = @(x)isnumeric(x)&&isscalar(x)&&isreal(x)&&isfinite(x);
for k = 1:numel(inputNames)
    addParameter(parser,inputNames{k},inputs.(inputNames{k}),scalarValidator);
end
addParameter(parser,'Duration_ns',50, ...
    @(x)scalarValidator(x)&&x>=0);
addParameter(parser,'InitialProbabilities',[1;0;0;0], ...
    @(x)isnumeric(x)&&isreal(x)&&numel(x)==4&&all(isfinite(x(:))));
addParameter(parser,'ReturnTrace',false, ...
    @(x)(islogical(x)||isnumeric(x))&&isscalar(x)&&isfinite(x));
parse(parser,varargin{:});

for k = 1:numel(inputNames)
    inputs.(inputNames{k}) = parser.Results.(inputNames{k});
end
[effectiveInput,pump] = qdResolvePumpInputs(inputs);
u = qdPackInputs(inputs);
p = parser.Results.InitialProbabilities(:);
dt_ns = 0.01;
requestedDuration_ns = parser.Results.Duration_ns;

% Construct an exact integration grid, including a fractional final step and
% the pulse edge. This prevents sub-10-ps pulses from receiving excess dose.
if requestedDuration_ns == 0
    timeEdges_ns = 0;
else
    timeEdges_ns = (0:dt_ns:requestedDuration_ns).';
    tolerance_ns = 64*eps(max(1,requestedDuration_ns));
    if isempty(timeEdges_ns) || ...
            abs(timeEdges_ns(end)-requestedDuration_ns) > tolerance_ns
        timeEdges_ns(end+1,1) = requestedDuration_ns;
    else
        timeEdges_ns(end) = requestedDuration_ns;
    end
    if inputs.incidentPhotonCount > 0 && inputs.pumpDuration_ns > 0 && ...
            inputs.pumpDuration_ns < requestedDuration_ns
        timeEdges_ns(end+1,1) = inputs.pumpDuration_ns;
    end
    timeEdges_ns = unique(sort(timeEdges_ns));
end
nSteps = max(0,numel(timeEdges_ns)-1);
absorbedPhotonCount = 0;
emittedPhotonCount = 0;
trappedPhotonCount = 0;
aggregateFlags = uint32(0);

if logical(parser.Results.ReturnTrace)
    trace = zeros(40,nSteps);
    traceStepDuration_ns = diff(timeEdges_ns);
else
    trace = zeros(40,0);
    traceStepDuration_ns = zeros(0,1);
end
for step = 1:nSteps
    stepInput = u;
    intervalStart_ns = timeEdges_ns(step);
    intervalDuration_ns = timeEdges_ns(step+1)-intervalStart_ns;
    if inputs.incidentPhotonCount > 0 && intervalStart_ns >= inputs.pumpDuration_ns
        stepInput(5) = 0;
    end
    [yStep,p] = qdPhysicsStep(stepInput,p,intervalDuration_ns*1.0e-9);
    intervalDuration_s = intervalDuration_ns*1.0e-9;
    absorbedPhotonCount = absorbedPhotonCount+yStep(38)*intervalDuration_s;
    emittedPhotonCount = emittedPhotonCount+yStep(25)*intervalDuration_s;
    trappedPhotonCount = trappedPhotonCount+yStep(39)*intervalDuration_s;
    aggregateFlags = bitor(aggregateFlags,uint32(round(yStep(31))));
    if logical(parser.Results.ReturnTrace)
        trace(:,step) = yStep;
    end
end

% Report the physical state exactly at the requested stop time. At the pulse
% boundary the strict square-pulse gate has already turned the pump off.
finalInput = u;
if inputs.incidentPhotonCount > 0 && ...
        requestedDuration_ns >= inputs.pumpDuration_ns
    finalInput(5) = 0;
end
[y,~] = qdPhysicsStep(finalInput,p,0);
aggregateFlags = bitor(aggregateFlags,uint32(round(y(31))));

result = qdUnpackOutputs(y);
result.biexcitonAugerLifetime_ps = 1.0e12/max(result.augerRate_Hz,realmin);
% Clear semantic alias: output 39 is radiative emission from the trap state,
% not capture of a photon, and it is already included in plPhotonRate_Hz.
result.trapEmissionPhotonRate_Hz = result.trappedPhotonRate_Hz;
result.inputs = inputs;
result.effectiveInputs = effectiveInput;
result.pumpMode = pump.mode;
result.lambda1_nm = pump.effectiveWavelength_nm;
result.lambda2_nm = result.emissionWavelength_nm;
result.effectivePumpPhotonEnergy_eV = pump.effectivePhotonEnergy_eV;
result.effectivePumpIntensity_Wcm2 = pump.effectiveIntensity_Wcm2;
result.pumpPhotonFlux_cm2_s = pump.photonFlux_cm2_s;
result.requestedPumpFluence_photons_cm2 = pump.fluence_photons_cm2;
result.incidentPhotonCount = inputs.incidentPhotonCount;
result.requestedIncidentPhotonCount = inputs.incidentPhotonCount;
if inputs.incidentPhotonCount > 0
    deliveredDuration_ns = min(requestedDuration_ns,inputs.pumpDuration_ns);
    result.deliveredIncidentPhotonCount = inputs.incidentPhotonCount* ...
        deliveredDuration_ns/inputs.pumpDuration_ns;
    result.deliveredPumpFluence_photons_cm2 = pump.photonFlux_cm2_s* ...
        deliveredDuration_ns*1.0e-9;
    result.incidentCountDefined = true;
else
    result.deliveredIncidentPhotonCount = 0;
    result.deliveredPumpFluence_photons_cm2 = pump.photonFlux_cm2_s* ...
        requestedDuration_ns*1.0e-9;
    result.incidentCountDefined = false;
end
result.pumpFluence_photons_cm2 = result.deliveredPumpFluence_photons_cm2;
result.absorbedPhotonCountExpectedPerDot = absorbedPhotonCount;
result.emittedPhotonCountExpectedPerDot = emittedPhotonCount;
result.trappedPhotonCountExpectedPerDot = trappedPhotonCount;
result.trapEmissionPhotonCountExpectedPerDot = trappedPhotonCount;
if absorbedPhotonCount > 0
    result.episodeQuantumYield = emittedPhotonCount/absorbedPhotonCount;
else
    result.episodeQuantumYield = 0;
end
result.material = qdMaterialDatabase(inputs.materialID);
mechanisticEnergy_eV = result.bulkBandgap_eV+ ...
    result.electronConfinement_eV+result.holeConfinement_eV- ...
    result.excitonBinding_eV+result.polarizationShift_eV+ ...
    result.starkShift_eV+result.strainShift_eV;
result.mechanisticEnergyBeforeCalibration_eV = mechanisticEnergy_eV;
result.calibrationCorrection_eV = ...
    result.absorptionEnergy_eV-mechanisticEnergy_eV;
result.calibration = qdCalibrationStatus(effectiveInput,result);
result.finalProbabilities = p;
result.duration_ns = requestedDuration_ns;
result.sampleTime_ns = dt_ns;
result.finalValidityFlags = result.validityFlags;
result.aggregateValidityFlags = double(aggregateFlags);
result.validityFlags = double(aggregateFlags);
result.warnings = qdDecodeFlags(result.aggregateValidityFlags);
result.spectrum = qdGenerateSpectra(result,effectiveInput.temperature_K);
if logical(parser.Results.ReturnTrace)
    result.trace.time_ns = timeEdges_ns(2:end);
    if nSteps == 0
        result.trace.time_ns = 0;
        result.trace.values = y.';
        result.trace.stepDuration_ns = 0;
    else
        result.trace.values = trace.';
        result.trace.stepDuration_ns = traceStepDuration_ns;
    end
    result.trace.names = qdOutputNames();
end
end
