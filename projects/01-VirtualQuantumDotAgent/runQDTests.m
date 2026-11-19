function report = runQDTests()
%RUNQDTESTS Numerical, physics-limit, dynamics, and Simulink regression tests.

rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
tests = cell(0,1);

% Published analytic CdSe strong-confinement regression point.
gold = qdBrusReference(3,300,1);
assert(abs(gold.bulkBandgap_eV-1.7567924528301888) < 1e-12);
assert(abs(gold.electronConfinement_eV-0.3213933009879792) < 2e-10);
assert(abs(gold.holeConfinement_eV-0.09284695361874955) < 2e-10);
assert(abs(gold.coulombCorrection_eV-0.09023777833146754) < 2e-10);
assert(abs(gold.transitionEnergy_eV-2.08079492910545) < 3e-10);
assert(abs(gold.wavelength_nm-595.850156427) < 2e-6);
tests{end+1} = 'CODATA/Brus golden regression';

defaultResult = simulateQD('Duration_ns',2);
assert(isfinite(defaultResult.plEnergy_eV) && defaultResult.plEnergy_eV > 1);
assert(defaultResult.emissionWavelength_nm > 350 && defaultResult.emissionWavelength_nm < 1200);
assert(defaultResult.modelConfidence > 0.7);
assert(defaultResult.probabilityResidual < 1e-12);
assert(abs(sum(defaultResult.finalProbabilities)-1) < 1e-12);
assert(all(defaultResult.finalProbabilities >= 0));
tests{end+1} = 'Finite-barrier default and probability conservation';

% Unequal-mass BenDaniel-Duke wells can have a valid root below pi/2. The
% shallow-state fixtures prevent regression to the old truncated search.
shallowInput = qdDefaultInputs();
shallowInput.radius_nm = 3;
shallowInput.shellThickness_nm = 0;
shallowInput.pumpIntensity_Wcm2 = 0;
shallowInput.holeBarrier_eV = 0.6;
shallowInput.electronBarrier_eV = 0.03;
unbound = simulateQD(shallowInput,'Duration_ns',0);
assert(bitand(uint32(round(unbound.validityFlags)),uint32(16)) ~= 0);
localAssertClose(unbound.electronConfinement_eV,0.03,0,1e-14);
shallowInput.electronBarrier_eV = 0.05;
bound005 = simulateQD(shallowInput,'Duration_ns',0);
localAssertClose(bound005.electronConfinement_eV,0.0492993938,0,2e-10);
assert(bitand(uint32(round(bound005.validityFlags)),uint32(16)) == 0);
shallowInput.electronBarrier_eV = 0.10;
bound010 = simulateQD(shallowInput,'Duration_ns',0);
localAssertClose(bound010.electronConfinement_eV,0.0801263360,0,2e-10);
tests{end+1} = 'Shallow unequal-mass finite-well bound-state roots';

small = simulateQD('radius_nm',2.5,'Duration_ns',0);
large = simulateQD('radius_nm',4.0,'Duration_ns',0);
assert(small.plEnergy_eV > large.plEnergy_eV);
assert(small.chargingEnergy_eV > large.chargingEnergy_eV);
tests{end+1} = 'Radius limiting behavior';

fieldPlus = simulateQD('electricField_kVcm',100,'Duration_ns',0);
fieldMinus = simulateQD('electricField_kVcm',-100,'Duration_ns',0);
assert(abs(fieldPlus.starkShift_eV-fieldMinus.starkShift_eV) < 1e-12);
assert(fieldPlus.starkShift_eV <= 0);
tests{end+1} = 'Quadratic Stark symmetry';

cold = simulateQD('temperature_K',100,'Duration_ns',0);
hot = simulateQD('temperature_K',400,'Duration_ns',0);
assert(cold.bulkBandgap_eV > hot.bulkBandgap_eV);
tests{end+1} = 'Varshni temperature trend';

solution = optimizeQDTarget(2.0,'RadiusBounds_nm',[1.5 10]);
assert(solution.reachableWithinBounds);
assert(solution.absoluteError_eV < 5e-3);
tests{end+1} = 'Autonomous target-radius search';

% The photon adapter must preserve legacy inputs and reproduce exact units.
newDefaults = qdDefaultInputs();
legacyDefaults = rmfield(newDefaults,{ ...
    'stokesShiftOverride_eV','incidentPhotonCount','inputWavelength_nm', ...
    'beamArea_um2','pumpDuration_ns'});
assert(isequal(qdPackInputs(newDefaults),qdPackInputs(legacyDefaults)));
photonInput = newDefaults;
photonInput.incidentPhotonCount = 1.0e8;
photonInput.inputWavelength_nm = 350;
photonInput.beamArea_um2 = 1.0e8; % exactly 1 cm^2
photonInput.pumpDuration_ns = 1;
[resolved,pump] = qdResolvePumpInputs(photonInput);
assert(abs(resolved.pumpPhotonEnergy_eV-3.54240566952) < 2e-11);
assert(abs(pump.photonFlux_cm2_s/1.0e17-1) < 1e-15);
assert(abs(resolved.pumpIntensity_Wcm2-0.0567555959185) < 2e-13);
tests{end+1} = 'Legacy-compatible lambda1 and photon-count conversion';

% Expected counts are the discrete rate integrals, not final-rate estimates.
photonResult = simulateQD('incidentPhotonCount',1,'inputWavelength_nm',450, ...
    'beamArea_um2',1,'pumpDuration_ns',1,'Duration_ns',5,'ReturnTrace',true);
stepDuration_s = photonResult.trace.stepDuration_ns*1.0e-9;
assert(abs(photonResult.lambda1_nm-450) < 1e-12);
assert(photonResult.lambda2_nm == photonResult.emissionWavelength_nm);
assert(abs(photonResult.absorbedPhotonCountExpectedPerDot- ...
    sum(stepDuration_s.*photonResult.trace.values(:,38))) < 1e-18);
assert(abs(photonResult.emittedPhotonCountExpectedPerDot- ...
    sum(stepDuration_s.*photonResult.trace.values(:,25))) < 1e-18);
assert(abs(photonResult.trappedPhotonCountExpectedPerDot- ...
    sum(stepDuration_s.*photonResult.trace.values(:,39))) < 1e-18);
photonResult2 = simulateQD('incidentPhotonCount',2,'inputWavelength_nm',450, ...
    'beamArea_um2',1,'pumpDuration_ns',1,'Duration_ns',5);
assert(photonResult2.absorbedPhotonCountExpectedPerDot > ...
    photonResult.absorbedPhotonCountExpectedPerDot);
zeroPump = simulateQD('pumpIntensity_Wcm2',0,'Duration_ns',1);
assert(zeroPump.absorbedPhotonCountExpectedPerDot == 0);
assert(zeroPump.emittedPhotonCountExpectedPerDot == 0);
tests{end+1} = 'Square-pulse gating and expected photon-count integration';

% Zero duration must be a pure observation. A sub-sample pulse must preserve
% its requested dose rather than being rounded up to the 10 ps output period.
initialProbabilities = [0.1;0.2;0.3;0.4];
zeroDuration = simulateQD('incidentPhotonCount',11,'inputWavelength_nm',450, ...
    'beamArea_um2',2.5,'pumpDuration_ns',0.003,'Duration_ns',0, ...
    'InitialProbabilities',initialProbabilities,'ReturnTrace',true);
assert(zeroDuration.duration_ns == 0);
assert(zeroDuration.deliveredIncidentPhotonCount == 0);
assert(zeroDuration.deliveredPumpFluence_photons_cm2 == 0);
assert(zeroDuration.absorbedPhotonCountExpectedPerDot == 0);
assert(zeroDuration.emittedPhotonCountExpectedPerDot == 0);
assert(zeroDuration.trappedPhotonCountExpectedPerDot == 0);
assert(max(abs(zeroDuration.finalProbabilities-initialProbabilities)) < 1e-15);
assert(isequal(zeroDuration.trace.time_ns,0));
assert(isequal(zeroDuration.trace.stepDuration_ns,0));
assert(max(abs(zeroDuration.trace.values(20:23).'-initialProbabilities)) < 1e-15);

photonCount = 7;
beamArea_um2 = 2.5;
pulseDuration_ns = 0.003;
subStepPulse = simulateQD('incidentPhotonCount',photonCount, ...
    'inputWavelength_nm',450,'beamArea_um2',beamArea_um2, ...
    'pumpDuration_ns',pulseDuration_ns,'Duration_ns',0.020,'ReturnTrace',true);
expectedFullFluence = photonCount*1.0e8/beamArea_um2;
localAssertClose(subStepPulse.requestedIncidentPhotonCount,photonCount,0,0);
localAssertClose(subStepPulse.deliveredIncidentPhotonCount,photonCount,1e-13,1e-14);
localAssertClose(subStepPulse.requestedPumpFluence_photons_cm2, ...
    expectedFullFluence,1e-13,1e-8);
localAssertClose(subStepPulse.deliveredPumpFluence_photons_cm2, ...
    expectedFullFluence,1e-13,1e-8);
localAssertClose(sum(subStepPulse.trace.stepDuration_ns),0.020,1e-13,1e-15);
localAssertClose(subStepPulse.trace.stepDuration_ns(1),pulseDuration_ns, ...
    1e-13,1e-15);
assert(subStepPulse.trace.values(1,13) > 0);
assert(all(subStepPulse.trace.values(2:end,13) == 0));
subStepDuration_s = subStepPulse.trace.stepDuration_ns*1.0e-9;
localAssertClose(subStepPulse.absorbedPhotonCountExpectedPerDot, ...
    sum(subStepDuration_s.*subStepPulse.trace.values(:,38)),1e-12,1e-20);
localAssertClose(subStepPulse.emittedPhotonCountExpectedPerDot, ...
    sum(subStepDuration_s.*subStepPulse.trace.values(:,25)),1e-12,1e-20);
localAssertClose(subStepPulse.trappedPhotonCountExpectedPerDot, ...
    sum(subStepDuration_s.*subStepPulse.trace.values(:,39)),1e-12,1e-20);

partialPulse = simulateQD('incidentPhotonCount',photonCount, ...
    'inputWavelength_nm',450,'beamArea_um2',beamArea_um2, ...
    'pumpDuration_ns',pulseDuration_ns,'Duration_ns',0.001,'ReturnTrace',true);
expectedDeliveredCount = photonCount*0.001/pulseDuration_ns;
localAssertClose(partialPulse.deliveredIncidentPhotonCount, ...
    expectedDeliveredCount,1e-13,1e-14);
localAssertClose(partialPulse.deliveredPumpFluence_photons_cm2, ...
    expectedFullFluence*0.001/pulseDuration_ns,1e-13,1e-8);
assert(partialPulse.requestedIncidentPhotonCount == photonCount);
assert(partialPulse.deliveredIncidentPhotonCount < ...
    partialPulse.requestedIncidentPhotonCount);
assert(partialPulse.incidentCountDefined);
tests{end+1} = 'Exact zero-duration, sub-step pulse, and delivered-dose accounting';

% The augmented exponential must be semigroup-consistent for both state and
% integrated event rewards: one 10 ps interval equals two 5 ps intervals.
rewardInput = qdDefaultInputs();
rewardInput.pumpIntensity_Wcm2 = 1.0e5;
rewardU = qdPackInputs(rewardInput);
p0 = [1;0;0;0];
[oneStep,pOne] = qdPhysicsStep(rewardU,p0,1.0e-11);
[halfOne,pHalf] = qdPhysicsStep(rewardU,p0,5.0e-12);
[halfTwo,pTwo] = qdPhysicsStep(rewardU,pHalf,5.0e-12);
oneCounts = oneStep([38 25 39])*1.0e-11;
twoCounts = (halfOne([38 25 39])+halfTwo([38 25 39]))*5.0e-12;
localAssertClose(max(abs(pOne-pTwo)),0,0,2e-14);
localAssertClose(max(abs(oneCounts-twoCounts)),0,0,2e-14);
assert(oneCounts(3) <= oneCounts(2)+1e-18);
tests{end+1} = 'Exact Markov propagation and integrated reward semigroup';

% Energy- and wavelength-domain spectral densities must be related by
% |dE/dlambda| = hc/lambda^2 and conserve their integrated quantities.
spectrum = defaultResult.spectrum;
hc_eVnm = 1239.841984332;
jacobian_eV_per_nm = hc_eVnm./spectrum.wavelength_nm.^2;
expectedAbsorptionPerNm = flipud( ...
    spectrum.absorption_m2_per_eV.*jacobian_eV_per_nm);
expectedPLPerNm = flipud(spectrum.plPhotons_Hz_per_eV.*jacobian_eV_per_nm);
assert(isequal(spectrum.wavelengthAscending_nm,flipud(spectrum.wavelength_nm)));
localAssertClose(max(abs(spectrum.absorption_m2_per_nm- ...
    expectedAbsorptionPerNm)),0,0,64*eps(max(expectedAbsorptionPerNm)));
localAssertClose(max(abs(spectrum.plPhotons_Hz_per_nm-expectedPLPerNm)), ...
    0,0,64*eps(max(expectedPLPerNm)));
absorptionIntegralEnergy = trapz(spectrum.energy_eV, ...
    spectrum.absorption_m2_per_eV);
absorptionIntegralWavelength = trapz(spectrum.wavelengthAscending_nm, ...
    spectrum.absorption_m2_per_nm);
plIntegralEnergy = trapz(spectrum.energy_eV,spectrum.plPhotons_Hz_per_eV);
plIntegralWavelength = trapz(spectrum.wavelengthAscending_nm, ...
    spectrum.plPhotons_Hz_per_nm);
localAssertClose(absorptionIntegralEnergy,defaultResult.absorptionCrossSection_m2, ...
    1e-12,1e-30);
localAssertClose(plIntegralEnergy,defaultResult.plPhotonRate_Hz,1e-12,1e-12);
localAssertClose(absorptionIntegralWavelength,absorptionIntegralEnergy,2e-4,1e-30);
localAssertClose(plIntegralWavelength,plIntegralEnergy,2e-4,1e-12);
assert(all(diff(spectrum.wavelengthAscending_nm) > 0));
tests{end+1} = 'Spectrum wavelength Jacobian and integrated-density conservation';

% The pump response is C1 at the absorption edge, is normalized to the
% measured 350 nm size law, and does not alter the intrinsic spectrum.
staticResult = simulateQD('pumpIntensity_Wcm2',0,'Duration_ns',0);
edgeEnergy = staticResult.absorptionEnergy_eV;
edgeDelta = 1.0e-6;
edgeBase = qdDefaultInputs();
edgeBase.pumpIntensity_Wcm2 = 1;
edgeBase.pumpPhotonEnergy_eV = edgeEnergy-edgeDelta;
belowEdge = simulateQD(edgeBase,'Duration_ns',0);
edgeBase.pumpPhotonEnergy_eV = edgeEnergy;
atEdge = simulateQD(edgeBase,'Duration_ns',0);
edgeBase.pumpPhotonEnergy_eV = edgeEnergy+edgeDelta;
aboveEdge = simulateQD(edgeBase,'Duration_ns',0);
leftDerivative = (atEdge.absorptionCrossSection_m2- ...
    belowEdge.absorptionCrossSection_m2)/edgeDelta;
rightDerivative = (aboveEdge.absorptionCrossSection_m2- ...
    atEdge.absorptionCrossSection_m2)/edgeDelta;
assert(abs(leftDerivative-rightDerivative)/max(abs(leftDerivative),realmin) < 1e-3);
at350 = simulateQD('pumpIntensity_Wcm2',1, ...
    'pumpPhotonEnergy_eV',3.5424,'Duration_ns',0);
localAssertClose(at350.absorptionCrossSection_m2,1.48527e-18,0,2e-30);
pump500 = simulateQD('pumpIntensity_Wcm2',1, ...
    'pumpPhotonEnergy_eV',1239.841984332/500,'Duration_ns',0);
localAssertClose(max(abs(at350.spectrum.absorptionCrossSection_m2- ...
    pump500.spectrum.absorptionCrossSection_m2)),0,0,2e-30);
localAssertClose(max(abs(at350.spectrum.absorption_m2_per_eV- ...
    pump500.spectrum.absorption_m2_per_eV)),0,0,2e-30);
tests{end+1} = 'C1 pump edge, 350 nm calibration, and intrinsic spectrum invariance';

% A positive Stokes override changes only PL-side quantities. Zero retains the
% material preset and the absorption transition remains invariant.
presetStokes = simulateQD('pumpIntensity_Wcm2',0,'Duration_ns',0);
overrideStokes = simulateQD('pumpIntensity_Wcm2',0, ...
    'stokesShiftOverride_eV',0.080,'Duration_ns',0);
localAssertClose(presetStokes.stokesShift_eV,0.025,0,1e-14);
localAssertClose(overrideStokes.stokesShift_eV,0.080,0,1e-14);
localAssertClose(overrideStokes.absorptionEnergy_eV, ...
    presetStokes.absorptionEnergy_eV,0,1e-12);
localAssertClose(overrideStokes.plEnergy_eV, ...
    overrideStokes.absorptionEnergy_eV-0.080,0,1e-12);
localAssertClose(overrideStokes.emissionWavelength_nm, ...
    hc_eVnm/overrideStokes.plEnergy_eV,1e-13,1e-12);
assert(overrideStokes.emissionWavelength_nm > presetStokes.emissionWavelength_nm);
tests{end+1} = 'Stokes-shift preset and explicit override';

% High-level inputs fail explicitly rather than reaching the low-level
% replacement/clipping path or producing a nonfinite photon dose.
badInput = qdDefaultInputs();
badInput.radius_nm = NaN;
localAssertError(@()qdResolvePumpInputs(badInput),'VirtualQD:InputType');
badInput = qdDefaultInputs();
badInput.radius_nm = 0;
localAssertError(@()qdResolvePumpInputs(badInput),'VirtualQD:Radius');
badInput = qdDefaultInputs();
badInput.incidentPhotonCount = -1;
localAssertError(@()qdResolvePumpInputs(badInput),'VirtualQD:PhotonCount');
badInput = qdDefaultInputs();
badInput.incidentPhotonCount = 1;
badInput.inputWavelength_nm = 0;
localAssertError(@()qdResolvePumpInputs(badInput),'VirtualQD:PumpWavelength');
badInput = qdDefaultInputs();
badInput.materialID = 5.5;
localAssertError(@()qdResolvePumpInputs(badInput),'VirtualQD:Material');
badInput = qdDefaultInputs();
badInput.stokesShiftOverride_eV = 1.01;
localAssertError(@()qdResolvePumpInputs(badInput),'VirtualQD:StokesShift');
badInput = qdDefaultInputs();
badInput.incidentPhotonCount = realmax;
badInput.beamArea_um2 = realmin;
badInput.pumpDuration_ns = realmin;
localAssertError(@()qdResolvePumpInputs(badInput),'VirtualQD:PhotonDose');
unknownInput = qdDefaultInputs();
unknownInput.misspelledRadius = 3;
localAssertError(@()simulateQD(unknownInput,'Duration_ns',0), ...
    'VirtualQD:UnknownInput');
tests{end+1} = 'Strict finite, range, photon-dose, and structure validation';

% Material 5 must be accepted as the in-scope empirical CdSe profile without
% being marked preliminary or outside its calibration envelope.
accurateInputs = qdAccurateCdSeInputs(3.0);
accurateResult = simulateQD(accurateInputs,'Duration_ns',0);
assert(accurateResult.material.id == 5);
assert(contains(accurateResult.material.status,'empirically fitted'));
assert(bitand(uint32(round(accurateResult.validityFlags)),uint32(256)) == 0);
assert(bitand(uint32(round(accurateResult.validityFlags)),uint32(524288)) == 0);
accurateReference = qdCdSeEmpiricalReferences(6);
assert(abs(accurateResult.absorptionEnergy_eV- ...
    accurateReference.ReferenceMeanEnergy_eV) < 0.015);
expectedAccurateRadiativeRate = ...
    (-0.1151+0.0753*accurateResult.plEnergy_eV)*1.0e9;
localAssertClose(accurateResult.radiativeRate_Hz, ...
    expectedAccurateRadiativeRate,1e-12,1e-5);
tests{end+1} = 'Calibrated materialID 5 interface and 6 nm checkpoint';

modelFile = fullfile(rootFolder,'VirtualQuantumDotAgent.slx');
if ~isfile(modelFile)
    buildVirtualQuantumDotAgent(false);
else
    load_system(modelFile);
end
initVirtualQuantumDotAgent();
set_param('VirtualQuantumDotAgent','SimulationCommand','update');
simOut = sim('VirtualQuantumDotAgent','StopTime','1e-9','ReturnWorkspaceOutputs','on');
logged = simOut.get('qdOutput');
assert(~isempty(logged.signals.values));
assert(all(isfinite(logged.signals.values(end,:))));
assert(~isempty(find_system('VirtualQuantumDotAgent','SearchDepth',1, ...
    'Name','Photon Count and Lambda1 Adapter')));
assert(~isempty(find_system('VirtualQuantumDotAgent','SearchDepth',1, ...
    'Name','Photon Count Accumulator')));
tests{end+1} = 'Simulink compile and execution';

editedInput = qdDefaultInputs();
editedInput.radius_nm = 2.8;
assignin('base','qdInput',editedInput);
editedOut = sim('VirtualQuantumDotAgent','StopTime','1e-11','ReturnWorkspaceOutputs','on');
editedLogged = editedOut.get('qdOutput');
preservedInput = evalin('base','qdInput');
assert(abs(preservedInput.radius_nm-2.8) < eps);
assert(abs(editedLogged.signals.values(end,9)-defaultResult.plEnergy_eV) > 1e-3);
tests{end+1} = 'Edited input persists and changes model output';

initVirtualQuantumDotAgent();
setQDInput('incidentPhotonCount',1,'inputWavelength_nm',450, ...
    'beamArea_um2',1,'pumpDuration_ns',1);
photonSimOut = sim('VirtualQuantumDotAgent','StopTime','5e-9', ...
    'ReturnWorkspaceOutputs','on');
photonLogged = photonSimOut.get('qdOutput');
countLogged = photonSimOut.get('qdPhotonCounts');
finalCounts = countLogged.signals.values(end,:);
assert(numel(finalCounts) == 4 && all(isfinite(finalCounts)));
localAssertClose(finalCounts(1),photonResult.deliveredIncidentPhotonCount, ...
    1e-12,1e-12);
assert(all(finalCounts(2:4) >= 0));
assert(abs(photonLogged.signals.values(end,10)-photonResult.lambda2_nm) < 1e-9);
tests{end+1} = 'Simulink photon inputs, lambda2, and count accumulator';

% The duty-corrected Simulink adapter must conserve delivered photons for
% pulses that do not land on the 10 ps reporting grid.
nonGridDurations_ns = [0.005 0.015 1.005];
nonGridStops_s = [3.0e-11 4.0e-11 1.03e-9];
for caseIndex = 1:numel(nonGridDurations_ns)
    initVirtualQuantumDotAgent();
    setQDInput('incidentPhotonCount',100,'inputWavelength_nm',450, ...
        'beamArea_um2',1,'pumpDuration_ns',nonGridDurations_ns(caseIndex));
    nonGridOut = sim('VirtualQuantumDotAgent', ...
        'StopTime',num2str(nonGridStops_s(caseIndex),17), ...
        'ReturnWorkspaceOutputs','on');
    nonGridCounts = nonGridOut.get('qdPhotonCounts');
    delivered = nonGridCounts.signals.values(end,1);
    localAssertClose(delivered,100,1e-12,1e-10);
end
tests{end+1} = 'Simulink non-grid pulse delivered-photon conservation';
initVirtualQuantumDotAgent();

report = struct();
report.passed = numel(tests);
report.failed = 0;
report.tests = tests;
report.matlabVersion = version;
report.timestamp = char(datetime('now','TimeZone','local','Format','yyyy-MM-dd HH:mm:ss Z'));
report.defaultFiniteBarrierResult = defaultResult;
report.inverseDesignResult = solution;

save(fullfile(rootFolder,'QDValidationResults.mat'),'report');
fileID = fopen(fullfile(rootFolder,'VALIDATION_RESULTS.txt'),'w');
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'Virtual Quantum Dot Agent - Validation Results\n');
fprintf(fileID,'Timestamp: %s\nMATLAB: %s\nPassed: %d\nFailed: %d\n\n', ...
    report.timestamp,report.matlabVersion,report.passed,report.failed);
for k = 1:numel(tests)
    fprintf(fileID,'PASS  %s\n',tests{k});
end
fprintf(fileID,'\nDefault PL energy: %.9f eV\n',defaultResult.plEnergy_eV);
fprintf(fileID,'Default wavelength: %.6f nm\n',defaultResult.emissionWavelength_nm);
fprintf(fileID,'Default confidence: %.6f\n',defaultResult.modelConfidence);
fprintf(fileID,'Target-search radius: %.9f nm\n',solution.radius_nm);
fprintf(fileID,'Target-search error: %.9g eV\n',solution.absoluteError_eV);
end

function localAssertClose(actual,expected,relativeTolerance,absoluteTolerance)
allowed = max(absoluteTolerance,relativeTolerance*max(abs(actual),abs(expected)));
assert(abs(actual-expected) <= allowed, ...
    'Expected %.17g, received %.17g (allowed error %.3g).', ...
    expected,actual,allowed);
end

function localAssertError(functionHandle,expectedIdentifier)
didThrow = false;
try
    functionHandle();
catch exception
    didThrow = true;
    assert(strcmp(exception.identifier,expectedIdentifier), ...
        'Expected error %s, received %s: %s', ...
        expectedIdentifier,exception.identifier,exception.message);
end
assert(didThrow,'Expected error %s was not thrown.',expectedIdentifier);
end
