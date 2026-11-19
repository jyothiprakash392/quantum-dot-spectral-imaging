function report = runQDEnsembleTests()
%RUNQDENSEMBLETESTS Validate size ensembles, spectra, and detector accounting.

rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
tests = cell(0,1);

assert(numel(qdInputNames()) == 14);
assert(numel(qdOutputNames()) == 40);
baseInput = qdDefaultInputs();
single = simulateQD(baseInput,'Duration_ns',0);
mono = simulateQDEnsemble(baseInput,'RadiusCV',0,'Duration_ns',0, ...
    'EnergyGridSize',1001,'ReturnMembers',true);
assert(mono.distribution.memberCount == 1);
assert(mono.memberSummary.NumberWeight == 1);
assert(mono.numberWeightedOutputs.absorptionEnergy_eV == ...
    single.absorptionEnergy_eV);
assert(mono.numberWeightedOutputs.plEnergy_eV == single.plEnergy_eV);
assert(mono.numberWeightedOutputs.validityFlags == single.validityFlags);
assert(isequal(mono.spectrum.energy_eV,single.spectrum.energy_eV));
localAssertClose(max(abs(mono.spectrum.absorptionCrossSection_m2- ...
    single.spectrum.absorptionCrossSection_m2)),0,0,1e-30);
localAssertClose(max(abs(mono.spectrum.absorptionLineIntrinsic_m2_per_eV- ...
    single.spectrum.absorption_m2_per_eV)),0,0,1e-30);
tests{end+1} = 'Stable 14/40 contract and exact zero-dispersion limit';

% For a lognormal arithmetic mean m and CV c,
% E[R^3] = m^3*(1+c^2)^3. The absorption-line area scales as R^3.
lognormal = simulateQDEnsemble(baseInput,'RadiusCV',0.1, ...
    'QuadratureOrder',15,'Duration_ns',0,'EnergyGridSize',2001);
localAssertClose(lognormal.distribution.realizedMeanRadius_nm,3,2e-13,1e-13);
localAssertClose(lognormal.distribution.realizedRadiusCV,0.1,2e-13,1e-13);
material = qdMaterialDatabase(1);
expectedArea_m2 = material.absorptionCrossSectionAt350nm3nm_m2* ...
    (1+0.1^2)^3;
observedArea_m2 = trapz(lognormal.spectrum.energy_eV, ...
    lognormal.spectrum.absorptionLineIntrinsic_m2_per_eV);
localAssertClose(observedArea_m2,expectedArea_m2,2e-12,1e-30);
tests{end+1} = 'Lognormal moments and analytic R-cubed absorption area';

radii_nm = [2.8;3.2];
fractions = [1;3];
discrete = simulateQDEnsemble(baseInput,'Radii_nm',radii_nm, ...
    'NumberFractions',fractions,'Duration_ns',0,'ReturnMembers',true);
localAssertClose(sum(discrete.memberSummary.NumberWeight),1,0,1e-15);
localAssertClose(discrete.distribution.realizedMeanRadius_nm,3.1,0,1e-15);
first = simulateQD('radius_nm',radii_nm(1),'Duration_ns',0);
second = simulateQD('radius_nm',radii_nm(2),'Duration_ns',0);
expectedPL_eV = 0.25*first.plEnergy_eV+0.75*second.plEnergy_eV;
localAssertClose(discrete.numberWeightedPLEnergy_eV,expectedPL_eV,0,1e-14);
duplicate = simulateQDEnsemble(baseInput,'Radii_nm',[3;3], ...
    'NumberFractions',[0.13;0.87],'Duration_ns',0);
localAssertClose(duplicate.numberWeightedPLEnergy_eV,single.plEnergy_eV,0,1e-14);
tests{end+1} = 'Measured discrete number fractions and duplicate invariance';

rng(314159,'twister');
stateBefore = rng;
repeatA = simulateQDEnsemble(baseInput,'RadiusCV',0.07, ...
    'QuadratureOrder',9,'Duration_ns',0,'EnergyGridSize',701);
stateAfter = rng;
repeatB = simulateQDEnsemble(baseInput,'RadiusCV',0.07, ...
    'QuadratureOrder',9,'Duration_ns',0,'EnergyGridSize',701);
assert(isequal(stateBefore,stateAfter));
assert(isequaln(repeatA,repeatB));
tests{end+1} = 'Deterministic quadrature is repeatable and RNG-independent';

energyGrid = lognormal.spectrum.energy_eV;
wavelengthGrid = lognormal.spectrum.wavelengthAscending_nm;
localAssertClose(trapz(energyGrid, ...
    lognormal.spectrum.plProbabilityObserved_per_eV),1,0,2e-12);
localAssertClose(trapz(wavelengthGrid, ...
    lognormal.spectrum.plProbabilityObserved_per_nm),1,0,2e-12);
absorptionEnergyArea = trapz(energyGrid, ...
    lognormal.spectrum.absorptionLineObserved_m2_per_eV);
absorptionWavelengthArea = trapz(wavelengthGrid, ...
    lognormal.spectrum.absorptionLineObserved_m2_per_nm);
localAssertClose(absorptionWavelengthArea,absorptionEnergyArea,1e-6,1e-30);
tests{end+1} = 'Ensemble spectral areas and energy-wavelength Jacobian';

unbroadened = simulateQDEnsemble(baseInput,'RadiusCV',0.06, ...
    'QuadratureOrder',15,'Duration_ns',0,'InstrumentFWHM_eV',0);
broadened = simulateQDEnsemble(baseInput,'RadiusCV',0.06, ...
    'QuadratureOrder',15,'Duration_ns',0,'InstrumentFWHM_eV',0.04);
assert(broadened.plFWHM_eV > unbroadened.plFWHM_eV);
areaBefore = trapz(unbroadened.spectrum.energy_eV, ...
    unbroadened.spectrum.absorptionLineObserved_m2_per_eV);
areaAfter = trapz(broadened.spectrum.energy_eV, ...
    broadened.spectrum.absorptionLineObserved_m2_per_eV);
localAssertClose(areaAfter,areaBefore,2e-12,1e-30);
tests{end+1} = 'Gaussian instrument broadening preserves area and widens PL';

photonInput = qdDefaultInputs();
photonInput.incidentPhotonCount = 1e8;
photonInput.inputWavelength_nm = 405;
photonInput.beamArea_um2 = 100;
photonInput.pumpDuration_ns = 0.02;
dynamic = simulateQDEnsemble(photonInput,'Radii_nm',radii_nm, ...
    'NumberFractions',[0.4;0.6],'Duration_ns',0.05, ...
    'NumberOfDots',1e4,'CollectionEfficiency',0.1, ...
    'OpticalTransmission',0.5,'DetectorQuantumEfficiency',0.8, ...
    'DarkCountRate_Hz',100,'ExposureTime_ns',0.1, ...
    'ReadNoiseElectronsRMS',2,'DetectorPixelCount',4, ...
    'ExcessNoiseFactor',1.2,'ReturnMembers',true);
memberWeights = dynamic.memberSummary.NumberWeight;
expectedAbsorbedPerDot = sum(memberWeights.* ...
    dynamic.memberSummary.AbsorbedPhotonCountExpectedPerDot);
expectedEmittedPerDot = sum(memberWeights.* ...
    dynamic.memberSummary.TotalEmittedPhotonCountExpectedPerDot);
expectedBandEdgePerDot = sum(memberWeights.* ...
    dynamic.memberSummary.BandEdgePhotonCountExpectedPerDot);
expectedTrapPerDot = sum(memberWeights.* ...
    dynamic.memberSummary.TrapEmissionPhotonCountExpectedPerDot);
localAssertClose(dynamic.photonAccounting. ...
    averageAbsorbedPhotonCountExpectedPerDot,expectedAbsorbedPerDot,0,1e-20);
localAssertClose(dynamic.photonAccounting. ...
    averageEmittedPhotonCountExpectedPerDot,expectedEmittedPerDot,0,1e-20);
bandEdgeEnergyIntegral = trapz(dynamic.spectrum.energy_eV, ...
    dynamic.spectrum.bandEdgePLEpisodePhotonsObservedPerDot_per_eV);
bandEdgeWavelengthIntegral = trapz( ...
    dynamic.spectrum.wavelengthAscending_nm, ...
    dynamic.spectrum.bandEdgePLEpisodePhotonsObservedPerDot_per_nm);
localAssertClose(bandEdgeEnergyIntegral,expectedBandEdgePerDot,2e-12,1e-20);
localAssertClose(bandEdgeWavelengthIntegral,expectedBandEdgePerDot,1e-6,1e-20);
localAssertClose(dynamic.spectrum. ...
    unresolvedTrapEmissionPhotonCountExpectedPerDot,expectedTrapPerDot,0,1e-20);
localAssertClose(expectedBandEdgePerDot+expectedTrapPerDot, ...
    expectedEmittedPerDot,0,1e-18);
expectedSignal = 1e4*expectedEmittedPerDot*0.1*0.5*0.8;
localAssertClose(dynamic.detector.signalPhotoelectronCountExpected, ...
    expectedSignal,2e-13,1e-20);
expectedDark = 100*0.1e-9;
localAssertClose(dynamic.detector.darkCountExpected,expectedDark,0,1e-20);
localAssertClose(dynamic.detector.totalDetectorCountExpected, ...
    expectedSignal+expectedDark,2e-13,1e-20);
expectedVariance = 1.2*expectedSignal+expectedDark+4*2^2;
localAssertClose(dynamic.detector.totalNoiseVariance, ...
    expectedVariance,2e-13,1e-14);
assert(all(dynamic.memberSummary.TrapEmissionPhotonCountExpectedPerDot <= ...
    dynamic.memberSummary.TotalEmittedPhotonCountExpectedPerDot+1e-18));
tests{end+1} = 'Photon, detector-efficiency, dark, and read-noise accounting';

thick = simulateQDEnsemble(photonInput,'Radii_nm',radii_nm, ...
    'NumberFractions',[0.4;0.6],'Duration_ns',0.05, ...
    'NumberOfDots',1e30);
assert(thick.photonAccounting.pumpDepletionIndicator > 0.05);
assert(~thick.photonAccounting.opticallyThinApproximationLikelyValid);
tests{end+1} = 'Optically thin photon-budget diagnostic';

legacyBudget = simulateQDEnsemble(baseInput,'RadiusCV',0,'Duration_ns',0);
assert(isnan(legacyBudget.photonAccounting.pumpDepletionIndicator));
assert(isnan(legacyBudget.photonAccounting. ...
    opticallyThinApproximationLikelyValid));
assert(contains(legacyBudget.photonAccounting.pumpDepletionAssessment, ...
    'not assessed'));
tests{end+1} = 'Unspecified photon budget reports depletion as not assessed';

bounded = simulateQDEnsemble(baseInput,'RadiusCV',0.5, ...
    'RadiusBounds_nm',[1 8],'QuadratureOrder',3,'Duration_ns',0);
assert(contains(bounded.distribution.kind,'conditioned'));
assert(bounded.distribution.excludedTailProbability > 0.02);
assert(all(bounded.memberSummary.Radius_nm >= 1 & ...
    bounded.memberSummary.Radius_nm <= 8));
tests{end+1} = 'Non-negligible lognormal tails force bounded conditioning';

zeroWeight = simulateQDEnsemble(baseInput,'Radii_nm',[0.6;3.0], ...
    'NumberFractions',[0;1],'Duration_ns',0);
assert(zeroWeight.distribution.memberCount == 1);
assert(zeroWeight.memberSummary.Radius_nm == 3.0);
assert(zeroWeight.validity.aggregateFlags == ...
    mono.validity.aggregateFlags);
tests{end+1} = 'Zero-fraction histogram bins have no ensemble effect';

scopedInput = qdAccurateCdSeInputs(3.0);
scopeMix = simulateQDEnsemble(scopedInput,'Radii_nm',[1.4;3.0], ...
    'NumberFractions',[0.25;0.75],'Duration_ns',0);
localAssertClose(scopeMix.validity.opticalCalibrationWeightFraction, ...
    0.75,0,1e-15);
assert(bitand(uint32(scopeMix.validity.aggregateFlags),uint32(524288)) ~= 0);
assert(~scopeMix.validity.allMembersOpticallyInScope);
tests{end+1} = 'Bitwise flag union and calibration-scope weight coverage';

weightedState = [dynamic.numberWeightedOutputs.groundProbability; ...
    dynamic.numberWeightedOutputs.excitonProbability; ...
    dynamic.numberWeightedOutputs.biexcitonProbability; ...
    dynamic.numberWeightedOutputs.trapProbability];
localAssertClose(sum(weightedState),1,0,2e-13);
expectedMeanExciton = weightedState(2)+2*weightedState(3)+weightedState(4);
localAssertClose(dynamic.numberWeightedOutputs.meanExcitonNumber, ...
    expectedMeanExciton,0,2e-13);
assert(dynamic.photonAccounting.totalEmittedPhotonCountExpected >= 0);
tests{end+1} = 'Weighted population and additive count physicality';

localAssertError(@()simulateQDEnsemble(baseInput,'Radii_nm',[2;3], ...
    'NumberFractions',1),'VirtualQD:EnsembleDistribution');
localAssertError(@()simulateQDEnsemble(baseInput,'Radii_nm',[2;3], ...
    'NumberFractions',[1;-1]),'VirtualQD:EnsembleDistribution');
localAssertError(@()simulateQDEnsemble(baseInput,'Radii_nm',[0.2;3], ...
    'NumberFractions',[1;1]),'VirtualQD:EnsembleDistribution');
localAssertError(@()simulateQDEnsemble(baseInput,'CollectionEfficiency',1.1), ...
    'MATLAB:InputParser:ArgumentFailedValidation');
localAssertError(@()simulateQDEnsemble(-1), ...
    'VirtualQD:EnsembleRadius');
tests{end+1} = 'Strict distribution, efficiency, and radius validation';

report = struct();
report.passed = numel(tests);
report.failed = 0;
report.tests = tests;
report.timestamp = char(datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd HH:mm:ss Z'));
report.matlabVersion = version;
report.lognormalFixture = struct( ...
    'meanRadius_nm',3,'radiusCV',0.1, ...
    'realizedMeanRadius_nm',lognormal.distribution.realizedMeanRadius_nm, ...
    'realizedRadiusCV',lognormal.distribution.realizedRadiusCV, ...
    'expectedAbsorptionArea_m2',expectedArea_m2, ...
    'observedAbsorptionArea_m2',observedArea_m2);
report.detectorFixture = dynamic.detector;
save(fullfile(rootFolder,'QDEnsembleValidationTests.mat'),'report');

fileID = fopen(fullfile(rootFolder,'QD_ENSEMBLE_TEST_RESULTS.txt'),'w');
if fileID < 0
    error('VirtualQD:ArtifactWrite','Cannot write ensemble test report.');
end
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'Virtual Quantum Dot Agent - Ensemble Observation Tests\n');
fprintf(fileID,'Timestamp: %s\nMATLAB: %s\nPassed: %d\nFailed: %d\n\n', ...
    report.timestamp,report.matlabVersion,report.passed,report.failed);
for k = 1:numel(tests)
    fprintf(fileID,'PASS  %s\n',tests{k});
end
fprintf(fileID,'\nLognormal mean radius: %.12f nm\n', ...
    report.lognormalFixture.realizedMeanRadius_nm);
fprintf(fileID,'Lognormal radius CV: %.12f\n', ...
    report.lognormalFixture.realizedRadiusCV);
fprintf(fileID,'Expected R^3 absorption area: %.12g m^2\n', ...
    expectedArea_m2);
fprintf(fileID,'Observed R^3 absorption area: %.12g m^2\n', ...
    observedArea_m2);
end

function localAssertClose(actual,expected,relativeTolerance,absoluteTolerance)
allowed = max(absoluteTolerance,relativeTolerance*max(abs(actual),abs(expected)));
assert(abs(actual-expected) <= allowed, ...
    'Expected %.17g, received %.17g (allowed error %.3g).', ...
    expected,actual,allowed);
end

function localAssertError(functionHandle,expectedIdentifier)
received = '';
try
    functionHandle();
catch exception
    received = exception.identifier;
end
assert(strcmp(received,expectedIdentifier), ...
    'Expected error %s, received %s.',expectedIdentifier,received);
end
