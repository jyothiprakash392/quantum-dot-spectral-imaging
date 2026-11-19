function report = runRealWorldValidationTests()
%RUNREALWORLDVALIDATIONTESTS Regression tests for empirical comparisons.

tests = { ...
    @testPublishedReferenceCheckpoints, ...
    @testIndependentReferenceSpread, ...
    @testSixNanometerPrediction, ...
    @testSmallDotWarningLevel, ...
    @testRadiativeLifetimeObservable, ...
    @testEmpiricalMaterialFiveCalibration, ...
    @testEmpiricalMaterialFiveEnvelope};
names = { ...
    'published reference checkpoints', ...
    'independent reference spread', ...
    '6 nm prediction and residuals', ...
    '3 nm small-dot error level', ...
    'intrinsic radiative-lifetime mapping', ...
    'materialID 5 fitted-curve accuracy and lifetime calibration', ...
    'materialID 5 calibration-envelope diagnostics'};

passed = false(numel(tests),1);
details = strings(numel(tests),1);
for k = 1:numel(tests)
    try
        tests{k}();
        passed(k) = true;
        details(k) = "PASS";
    catch exception
        details(k) = "FAIL: " + string(exception.message);
    end
end

report = struct();
report.table = table(string(names(:)),passed,details, ...
    'VariableNames',{'Test','Passed','Details'});
report.passed = sum(passed);
report.failed = sum(~passed);
report.timestamp = char(datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd HH:mm:ss Z'));

rootFolder = fileparts(mfilename('fullpath'));
save(fullfile(rootFolder,'RealWorldValidationTests.mat'),'report');
fileID = fopen(fullfile(rootFolder,'REAL_WORLD_VALIDATION_TESTS.txt'),'w');
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'Real-world validation workflow regression tests\n');
fprintf(fileID,'Timestamp: %s\n',report.timestamp);
fprintf(fileID,'Passed: %d/%d\n\n',report.passed,numel(tests));
for k = 1:numel(tests)
    fprintf(fileID,'%s: %s\n',names{k},details(k));
end

if report.failed > 0
    error('VirtualQD:RealValidationTests', ...
        '%d real-world validation workflow tests failed.',report.failed);
end
end

function testPublishedReferenceCheckpoints()
reference = qdCdSeEmpiricalReferences(6);
assert(abs(reference.YuEnergy_eV-1.9792011306) < 1e-9);
assert(abs(reference.JasieniakEnergy_eV-1.9724013070) < 1e-9);
assert(abs(reference.DonegaEnergy_eV-1.9778897015) < 1e-9);
end

function testIndependentReferenceSpread()
reference = qdCdSeEmpiricalReferences([3;4;5;6;7;8]);
assert(all(reference.InterCurveSpread_eV >= 0));
assert(abs(reference.InterCurveSpread_eV(4)-0.0067998236) < 1e-9);
assert(max(reference.InterCurveSpread_eV) > 0.040);
end

function testSixNanometerPrediction()
prediction = predictQDWithError(localMechanisticBenchmarkInputs(3.0),100);
assert(prediction.benchmark.available);
assert(abs(prediction.absorptionEnergy_eV-1.967753758824) < 1e-9);
assert(abs(prediction.benchmark.signedError_eV+0.011447371790) < 1e-9);
assert(abs(prediction.benchmark.signedErrorVsJasieniak_eV) < 0.005);
assert(strcmp(prediction.agreementGrade,'good (<=15 meV versus source mean)'));
end

function testSmallDotWarningLevel()
prediction = predictQDWithError(localMechanisticBenchmarkInputs(1.5),100);
assert(prediction.benchmark.available);
assert(prediction.benchmark.signedError_eV > 0.090);
assert(contains(prediction.agreementGrade,'poor'));
end

function testRadiativeLifetimeObservable()
prediction = predictQDWithError(localMechanisticBenchmarkInputs(3.0),100);
benchmark = prediction.radiativeLifetimeBenchmark;
assert(benchmark.available);
assert(abs(benchmark.modelIntrinsicRadiativeLifetime_ns-22.4390275697) < 1e-8);
assert(abs(benchmark.referenceRadiativeLifetime_ns-32.0622181045) < 1e-8);
assert(benchmark.relativeError_percent < -29);
end

function testEmpiricalMaterialFiveCalibration()
diameter_nm = (3:8).';
reference = qdCdSeEmpiricalReferences(diameter_nm);
predictedEnergy_eV = zeros(size(diameter_nm));
predictedRadiativeRate_Hz = zeros(size(diameter_nm));
expectedRadiativeRate_Hz = zeros(size(diameter_nm));
validityFlags = zeros(size(diameter_nm));

for k = 1:numel(diameter_nm)
    inputs = qdAccurateCdSeInputs(diameter_nm(k)/2);
    result = simulateQD(inputs,'Duration_ns',0);
    predictedEnergy_eV(k) = result.absorptionEnergy_eV;
    predictedRadiativeRate_Hz(k) = result.radiativeRate_Hz;
    expectedRadiativeRate_Hz(k) = ...
        (-0.1151+0.0753*result.plEnergy_eV)*1.0e9;
    validityFlags(k) = result.validityFlags;
    assert(result.material.id == 5);
    assert(contains(result.material.status,'empirically fitted'));
end

residual_eV = predictedEnergy_eV-reference.ReferenceMeanEnergy_eV;
rmse_eV = sqrt(mean(residual_eV.^2));
assert(rmse_eV < 0.008);
assert(max(abs(residual_eV)) < 0.015);
assert(all(bitand(uint32(round(validityFlags)),uint32(256)) == 0));
assert(all(bitand(uint32(round(validityFlags)),uint32(524288)) == 0));
relativeRateError = abs(predictedRadiativeRate_Hz-expectedRadiativeRate_Hz)./ ...
    expectedRadiativeRate_Hz;
assert(max(relativeRateError) < 1e-12);
end

function testEmpiricalMaterialFiveEnvelope()
inScope = qdAccurateCdSeInputs(3.0);
inScopeResult = simulateQD(inScope,'Duration_ns',0);
assert(bitand(uint32(round(inScopeResult.validityFlags)),uint32(524288)) == 0);

outOfScope = inScope;
outOfScope.temperature_K = 400;
outOfScopeResult = simulateQD(outOfScope,'Duration_ns',0);
assert(bitand(uint32(round(outOfScopeResult.validityFlags)),uint32(524288)) ~= 0);
assert(bitand(uint32(round(outOfScopeResult.validityFlags)),uint32(256)) == 0);
assert(outOfScopeResult.modelConfidence < inScopeResult.modelConfidence);
assert(any(contains(string(outOfScopeResult.warnings),'calibration envelope')));

didRejectRadius = false;
try
    qdAccurateCdSeInputs(1.49);
catch
    didRejectRadius = true;
end
assert(didRejectRadius);
end

function inputs = localMechanisticBenchmarkInputs(radius_nm)
% Match the explicit profile required by predictQDWithError benchmark scope.
inputs = qdDefaultInputs();
inputs.radius_nm = radius_nm;
inputs.temperature_K = 300;
inputs.electricField_kVcm = 0;
inputs.hydrostaticStrain_pct = 0;
inputs.pumpIntensity_Wcm2 = 0;
inputs.shellThickness_nm = 0;
inputs.surfaceTrapDensity_cm2 = 0;
inputs.environmentDielectric = 2.25;
inputs.electronBarrier_eV = 0;
inputs.holeBarrier_eV = 0;
inputs.targetEmission_eV = 0;
inputs.materialID = 1;
inputs.stokesShiftOverride_eV = 0;
end
