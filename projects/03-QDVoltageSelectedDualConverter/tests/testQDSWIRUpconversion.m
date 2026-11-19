function report = testQDSWIRUpconversion()
%TESTQDSWIRUPCONVERSION Validate conversion, CCD, inversion, and Simulink.

paths = setupQDVoltageSelectedDualConverter();
tests = cell(0,1);

config = qdUpconversionSpectrometerConfig();
response = qdBuildSpectralResponse(config);
inputCount = numel(config.inputWavelength_nm);
visibleCount = numel(config.visibleWavelength_nm);
measurementCount = config.measurementCount;
assert(isequal(size(response.systemMatrix_electronsPerIncidentPhoton), ...
    [measurementCount inputCount]));
assert(isequal(size(response.visibleEmissionBasis_perBin), ...
    [visibleCount measurementCount]));
assert(all(isfinite(response.systemMatrix_electronsPerIncidentPhoton),'all'));
assert(all(response.systemMatrix_electronsPerIncidentPhoton>=0,'all'));
localAssertClose(max(abs(sum(response.visibleEmissionBasis_perBin,1)-1)), ...
    0,0,2e-14);
tests{end+1} = 'Response factorization dimensions, positivity, and PL normalization';

assert(response.numericalRank==inputCount);
assert(response.conditionNumber<100);
assert(config.validity.sensitizerOpticalCalibrationCoverage==1);
assert(config.validity.allEmitterReferencePointsInScope);
tests{end+1} = 'Full numerical rank and focused material-reference coverage';

assert(response.requiresExternalElectricalPower);
assert(all(isnan(response.energyConservationRatio)));
assert(strcmp(config.conversionMechanism,'electrically_assisted'));
tests{end+1} = 'Active upconversion is explicitly electrically powered';

zeroInput = zeros(inputCount,1);
zeroObservation = simulateQDUpconversionCCD(zeroInput,config,'AddNoise',false);
localAssertClose(max(abs(zeroObservation.ccd.signalElectronsExpected)), ...
    0,0,1e-20);
localAssertClose(max(abs(zeroObservation.ccd.measuredElectrons- ...
    response.darkElectronsExpected)),0,0,1e-20);
tests{end+1} = 'Zero optical input produces dark expectation only';

lineInput = zeros(inputCount,1);
lineIndex = round(0.62*inputCount);
lineInput(lineIndex) = 1e6;
lineObservation = simulateQDUpconversionCCD(lineInput,config,'AddNoise',false);
expectedColumn = response.systemMatrix_electronsPerIncidentPhoton(:,lineIndex)*1e6;
localAssertClose(max(abs(lineObservation.ccd.signalElectronsExpected- ...
    expectedColumn)),0,0,1e-12);
tests{end+1} = 'Monochromatic unit-column response is exact';

firstInput = lineInput;
secondInput = zeros(inputCount,1);
secondInput(round(0.30*inputCount)) = 0.7e6;
sumObservation = simulateQDUpconversionCCD(firstInput+secondInput,config, ...
    'AddNoise',false);
firstObservation = simulateQDUpconversionCCD(firstInput,config,'AddNoise',false);
secondObservation = simulateQDUpconversionCCD(secondInput,config,'AddNoise',false);
localAssertClose(max(abs(sumObservation.ccd.signalElectronsExpected- ...
    firstObservation.ccd.signalElectronsExpected- ...
    secondObservation.ccd.signalElectronsExpected)),0,0,2e-12);
tests{end+1} = 'Electrically assisted operating-point forward model is linear';

[~,~,truth] = initQDSWIRUpconversionSpectrometer(true);
noiseless = simulateQDComputationalSpectrometer(truth,config, ...
    'AddNoise',false,'Regularization',0.002,'UseNoiseWeights',false);
assert(noiseless.metrics.normalizedRMSEByMean<0.12);
assert(noiseless.metrics.spectralCorrelation>0.995);
assert(noiseless.reconstruction.nonnegative);
tests{end+1} = 'Noiseless nonnegative reconstruction recovers a broadband mixture';

noisyA = simulateQDComputationalSpectrometer(truth,config, ...
    'AddNoise',true,'Seed',314159);
noisyB = simulateQDComputationalSpectrometer(truth,config, ...
    'AddNoise',true,'Seed',314159);
assert(isequal(noisyA.observation.ccd.measuredElectrons, ...
    noisyB.observation.ccd.measuredElectrons));
assert(noisyA.metrics.normalizedRMSEByMean<0.15);
assert(noisyA.metrics.spectralCorrelation>0.99);
assert(~noisyA.observation.validity.anyCCDSaturation);
tests{end+1} = 'Seeded shot/read noise is repeatable and reconstruction remains accurate';

calibrated = qdApplyMeasuredSpectralCalibration(config, ...
    config.inputWavelength_nm,1.1*response.systemMatrix_electronsPerIncidentPhoton, ...
    'DarkElectrons',3*ones(measurementCount,1),'Label','synthetic calibration fixture');
calibratedResponse = qdBuildSpectralResponse(calibrated);
localAssertClose(max(abs(calibratedResponse. ...
    systemMatrix_electronsPerIncidentPhoton- ...
    1.1*response.systemMatrix_electronsPerIncidentPhoton),[],'all'),0,0,1e-15);
assert(calibratedResponse.isMeasuredCalibration);
assert(all(calibratedResponse.darkElectronsExpected==3));
tests{end+1} = 'Measured end-to-end response and dark calibration replace defaults';

localAssertError(@()simulateQDUpconversionCCD(ones(inputCount-1,1),config), ...
    'QDConverter:IncidentSpectrum');
localAssertError(@()qdApplyMeasuredSpectralCalibration(config,[1200;1300], ...
    ones(measurementCount,2)),'QDConverter:MeasuredWavelength');
localAssertError(@()reconstructQDSpectrum(ones(measurementCount-1,1),response), ...
    'QDConverter:ReconstructionMeasurement');
tests{end+1} = 'Strict input, calibration, and reconstruction validation';

% Build, compile, close/reopen, and simulate the actual SLX artifact.
modelFile = buildQDSWIRUpconversionSpectrometer(true);
[~,modelName] = fileparts(modelFile);
if bdIsLoaded(modelName), close_system(modelName,0); end
load_system(modelFile);
set_param(modelName,'SimulationCommand','update');
simulationOutput = sim(modelName,'StopTime','0','ReturnWorkspaceOutputs','on');
simInput = localLastVector(simulationOutput.get('qdInputSpectrumSim'));
simMeasurement = localLastVector(simulationOutput.get('qdCCDMeasurementSim'));
simReconstruction = localLastVector( ...
    simulationOutput.get('qdReconstructedSpectrumSim'));
localAssertClose(max(abs(simInput-truth)),0,0,1e-12);
expectedMeasurement = response.systemMatrix_electronsPerIncidentPhoton*truth+ ...
    response.darkElectronsExpected;
localAssertClose(max(abs(simMeasurement-expectedMeasurement)),0,1e-12,1e-10);
directReconstruction = reconstructQDSpectrum(expectedMeasurement,response, ...
    'Regularization',config.reconstruction.regularization, ...
    'MaxIterations',config.reconstruction.maxIterations);
localAssertClose(max(abs(simReconstruction- ...
    directReconstruction.incidentPhotonsPerBin)),0,1e-11,1e-7);
close_system(modelName,0);
assert(isfile(modelFile));
tests{end+1} = 'Generated SLX closes, reloads, compiles, and matches MATLAB equations';

report = struct();
report.passed = numel(tests);
report.failed = 0;
report.tests = tests;
report.timestamp = char(datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd HH:mm:ss Z'));
report.matlabVersion = version;
report.responseRank = response.numericalRank;
report.responseConditionNumber = response.conditionNumber;
report.noisyDemoMetrics = noisyA.metrics;
report.simulinkModel = modelFile;
fileID = fopen(fullfile(paths.reports,'swir-upconversion-validation.txt'),'w');
if fileID<0
    error('QDConverter:ArtifactWrite','Cannot write upconversion test report.');
end
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'QD Upconversion CCD Computational Spectrometer Tests\n');
fprintf(fileID,'Timestamp: %s\nMATLAB: %s\nPassed: %d\nFailed: %d\n\n', ...
    report.timestamp,report.matlabVersion,report.passed,report.failed);
for testIndex = 1:numel(tests)
    fprintf(fileID,'PASS  %s\n',tests{testIndex});
end
fprintf(fileID,'\nResponse rank: %d\n',report.responseRank);
fprintf(fileID,'Response condition number: %.12g\n', ...
    report.responseConditionNumber);
fprintf(fileID,'Noisy demo normalized RMSE: %.12g\n', ...
    report.noisyDemoMetrics.normalizedRMSEByMean);
fprintf(fileID,'Noisy demo spectral correlation: %.12g\n', ...
    report.noisyDemoMetrics.spectralCorrelation);
end

function vector = localLastVector(workspaceStructure)
values = workspaceStructure.signals.values;
if isvector(values)
    vector = values(:);
elseif ismatrix(values)
    vector = values(:,end);
else
    vector = values(:,1,end);
end
end

function localAssertClose(actual,expected,relativeTolerance,absoluteTolerance)
allowed = max(absoluteTolerance, ...
    relativeTolerance*max(abs(actual),abs(expected)));
assert(abs(actual-expected)<=allowed, ...
    'Expected %.17g, received %.17g (allowed %.3g).', ...
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
