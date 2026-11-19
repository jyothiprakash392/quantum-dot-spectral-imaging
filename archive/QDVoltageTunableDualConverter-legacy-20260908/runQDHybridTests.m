function report = runQDHybridTests()
%RUNQDHYBRIDTESTS Validate physics-constrained ML selection and deployment.

rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
tests = cell(0,1);

benchmark = benchmarkQDHybridModels(false);
assert(strcmp(benchmark.optical.selectedModel,'constant'));
assert(isempty(intersect(benchmark.optical.developmentIndices, ...
    benchmark.optical.holdoutIndices)));
assert(numel(benchmark.optical.developmentIndices) == 4);
assert(numel(benchmark.optical.holdoutIndices) == 3);
tests{end+1} = 'Optical model selection uses disjoint development/frozen sizes';

localAssertClose(benchmark.optical.selectedInnerCVRMSE_eV, ...
    0.0118791260774366,0,5e-13);
localAssertClose(benchmark.optical.baselineHoldoutRMSE_eV, ...
    0.0725149409891967,0,5e-13);
localAssertClose(benchmark.optical.hybridHoldoutRMSE_eV, ...
    0.0370127080356124,0,5e-13);
localAssertClose(benchmark.optical.hybridHoldoutBias_eV, ...
    -0.0042159090909091,0,5e-13);
assert(benchmark.optical.hybridHoldoutRMSE_eV < ...
    benchmark.optical.baselineHoldoutRMSE_eV);
tests{end+1} = 'Optical frozen-size metrics reproduce and improve baseline';

deployed = benchmark.kinetic.deployedModel;
assert(deployed.selectedLambda == 0.1);
assert(deployed.selectedDevelopmentCompositeRatio < 0.85);
expectedTau = [3.183780018375221;0.25057345676543119; ...
    1.2345240813129643;-0.58043503257099538];
expectedQY = [0.94968446323147371;0.056978284696460949; ...
    0.048363733662658483;-0.074033041351858522];
localAssertClose(max(abs(deployed.lifetimeCoefficients-expectedTau)),0,0,5e-13);
localAssertClose(max(abs(deployed.plqyCoefficients-expectedQY)),0,0,5e-13);
expectedKinetic = [0.0145593421577936,0.0103094382867921, ...
    0.0896422531098704,3.48660783201446];
localAssertClose(max(abs(deployed.frozenHoldoutMetrics-expectedKinetic)), ...
    0,0,5e-12);
localAssertClose(deployed.frozenRadiativeLifetimeRMSE_ns, ...
    0.180420528355052,0,5e-12);
tests{end+1} = 'Kinetic development selection, coefficients, and frozen metrics';

repeat = benchmarkQDHybridModels(false);
assert(strcmp(repeat.optical.selectedModel,benchmark.optical.selectedModel));
localAssertClose(repeat.optical.hybridHoldoutRMSE_eV, ...
    benchmark.optical.hybridHoldoutRMSE_eV,0,1e-15);
localAssertClose(repeat.kinetic.deployedModel.selectedDevelopmentCompositeRatio, ...
    deployed.selectedDevelopmentCompositeRatio,0,1e-15);
tests{end+1} = 'Seeded candidate benchmark is repeatable';

referenceInput = qdCalibratedMaterialInputs(4,4.3);
source = predictQDHybrid(referenceInput,'OpticalProtocol','brennan2017', ...
    'NumberOfSamples',100);
mondal = predictQDHybrid(referenceInput,'OpticalProtocol','mondal2019', ...
    'NumberOfSamples',100);
unknown = predictQDHybrid(referenceInput,'NumberOfSamples',100);
assert(~source.mlOpticalAdaptationActive);
assert(mondal.mlOpticalAdaptationActive && unknown.mlOpticalAdaptationActive);
localAssertClose(mondal.absorptionEnergy_eV- ...
    source.absorptionEnergy_eV,-0.0667159090909091,0,3e-13);
localAssertClose(unknown.absorptionEnergy_eV,0.5*( ...
    source.absorptionEnergy_eV+mondal.absorptionEnergy_eV),0,3e-13);
assert(unknown.engineeringEnvelopeLow_eV <= mondal.absorptionEnergy_eV);
assert(unknown.engineeringEnvelopeHigh_eV >= source.absorptionEnergy_eV);
tests{end+1} = 'All optical protocols, robust midpoint, and model envelope';

assert(source.lambda2_nm == mondal.lambda2_nm);
assert(source.lambda2_nm == unknown.lambda2_nm);
assert(~source.mlPLAdaptationActive && ~mondal.mlPLAdaptationActive && ...
    ~unknown.mlPLAdaptationActive);
tests{end+1} = 'Absorption adaptation never fabricates a PL/lambda2 correction';

boundaryCases = [3.0 293;3.0 300;6.2 293;6.2 300];
for k = 1:size(boundaryCases,1)
    boundaryInput = qdCalibratedMaterialInputs(4,boundaryCases(k,1));
    boundaryInput.temperature_K = boundaryCases(k,2);
    boundary = predictQDHybrid(boundaryInput,'OpticalProtocol','mondal2019', ...
        'NumberOfSamples',100);
    assert(boundary.mlOpticalAdaptationActive);
end
outsideSize = qdCalibratedMaterialInputs(4,6.21);
outsideTemperature = qdCalibratedMaterialInputs(4,4.3);
outsideTemperature.temperature_K = 292;
outsideShell = qdCalibratedMaterialInputs(4,4.3);
outsideShell.shellThickness_nm = 0.1;
outsideField = qdCalibratedMaterialInputs(4,4.3);
outsideField.electricField_kVcm = 1;
outsideCases = {outsideSize,outsideTemperature,outsideShell,outsideField};
for k = 1:numel(outsideCases)
    outside = predictQDHybrid(outsideCases{k}, ...
        'OpticalProtocol','mondal2019','NumberOfSamples',100);
    assert(~outside.mlOpticalAdaptationActive);
    assert(outside.absorptionEnergy_eV == outside.nominal.absorptionEnergy_eV);
end
tests{end+1} = 'Optical adapter includes exact boundaries and blocks extrapolation';

for materialID = [2 3 5]
    if materialID == 2
        fallbackInput = qdCalibratedMaterialInputs(2,2.5);
    elseif materialID == 3
        fallbackInput = qdCalibratedMaterialInputs(3,6.2);
    else
        fallbackInput = qdAccurateCdSeInputs(3.0);
    end
    fallback = predictQDHybrid(fallbackInput,'NumberOfSamples',100);
    assert(~fallback.mlOpticalAdaptationActive);
    assert(fallback.absorptionEnergy_eV == fallback.nominal.absorptionEnergy_eV);
end
tests{end+1} = 'IDs 2, 3, and 5 safely retain their optical models';

invalidRejected = false;
try
    predictQDHybrid(referenceInput,'OpticalProtocol','invented', ...
        'NumberOfSamples',100);
catch exception
    invalidRejected = strcmp(exception.identifier,'VirtualQD:OpticalProtocol');
end
assert(invalidRejected);
tests{end+1} = 'Invalid optical protocol is rejected';

pbS = qdPbSCdSReferenceData();
for k = 1:numel(pbS.Series)
    [rate_Hz,tau_ps,inScope] = qdPbSCdSAugerModel( ...
        pbS.PbSCoreDiameter_nm(k),pbS.CdSShellThickness_nm(k));
    assert(inScope && rate_Hz >= 0 && tau_ps > 0);
    localAssertClose(rate_Hz*tau_ps,1e12,0,2e-4);
end
[~,~,convexHullRejects] = qdPbSCdSAugerModel(5.32,0.84);
assert(~convexHullRejects);
tests{end+1} = 'ID3 Auger learner is physical and convex-hull gated';

report = struct();
report.passed = numel(tests);
report.failed = 0;
report.tests = tests;
report.timestamp = char(datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd HH:mm:ss Z'));
report.matlabVersion = version;
report.optical = benchmark.optical;
report.kinetic = benchmark.kinetic.deployedModel;
save(fullfile(rootFolder,'QDHybridValidationTests.mat'),'report');

fileID = fopen(fullfile(rootFolder,'QD_HYBRID_TEST_RESULTS.txt'),'w');
if fileID < 0
    error('VirtualQD:ArtifactWrite','Cannot write hybrid test report.');
end
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'Virtual Quantum Dot Agent - Hybrid Validation Tests\n');
fprintf(fileID,'Timestamp: %s\nMATLAB: %s\nPassed: %d\nFailed: %d\n\n', ...
    report.timestamp,report.matlabVersion,report.passed,report.failed);
for k = 1:numel(tests)
    fprintf(fileID,'PASS  %s\n',tests{k});
end
end

function localAssertClose(actual,expected,relativeTolerance,absoluteTolerance)
allowed = max(absoluteTolerance,relativeTolerance*max(abs(actual),abs(expected)));
assert(abs(actual-expected) <= allowed, ...
    'Expected %.17g, received %.17g (allowed error %.3g).', ...
    expected,actual,allowed);
end
