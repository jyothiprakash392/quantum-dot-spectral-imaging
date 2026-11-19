function report = testQDUVAndDualConversion()
%TESTQDUVANDDUALCONVERSION Validate physics, controls, and both SLX paths.

paths = setupQDVoltageSelectedDualConverter();
tests = cell(0,1);
[dualConfig,config,upConfig] = initQDVoltageSelectedDualConverter(true);
truth = evalin('base','qdUVIncidentSpectrum');
inputCount = numel(config.inputWavelength_nm);
outputCount = numel(config.outputWavelength_nm);
measurementCount = config.spectrometer.measurementCount;

assert(config.filmCount==numel(config.selector.channelVoltage_V));
assert(all(config.film.emissionCenter_nm>max(config.inputWavelength_nm)));
assert(strcmp(config.selector.mode,'nearest_channel'));
assert(config.validity.passiveOnePhotonDownconversion);
assert(config.validity.selectorVoltageIsElectronicCommand);
assert(~config.validity.mechanicalMotionRequired);
assert(~config.validity.singleFilmWideVoltageTuningClaim);
for channelIndex = 1:config.filmCount
    decoder = qdDecodeSelectorVoltage( ...
        config.selector.channelVoltage_V(channelIndex),config);
    assert(decoder.selectedChannelIndex==channelIndex);
    assert(sum(decoder.oneHotGates)==1);
    assert(decoder.oneHotGates(channelIndex)==1);
    assert(abs(decoder.adcVoltage_V-decoder.commandVoltage_V)<= ...
        0.5*config.selector.adc.leastSignificantBit_V+eps);
end
firstThreshold_V = config.selector.thresholdVoltage_V(1);
holdUp = qdDecodeSelectorVoltage(firstThreshold_V+ ...
    0.25*config.selector.hysteresis_V,config, ...
    'PreviousChannelIndex',1);
switchUp = qdDecodeSelectorVoltage(firstThreshold_V+ ...
    config.selector.hysteresis_V,config,'PreviousChannelIndex',1);
holdDown = qdDecodeSelectorVoltage(firstThreshold_V- ...
    0.25*config.selector.hysteresis_V,config, ...
    'PreviousChannelIndex',2);
switchDown = qdDecodeSelectorVoltage(firstThreshold_V- ...
    config.selector.hysteresis_V,config,'PreviousChannelIndex',2);
assert(holdUp.selectedChannelIndex==1 && switchUp.selectedChannelIndex==2);
assert(holdDown.selectedChannelIndex==2 && switchDown.selectedChannelIndex==1);
tests{end+1} = ['Configuration and ADC decoder provide one-hot selection ' ...
    'with hysteresis'];

maximumCondition = 0;
minimumCorrelation = inf;
for filmIndex = 1:config.filmCount
    voltage = config.selector.channelVoltage_V(filmIndex);
    response = qdBuildDownconversionResponse(config,voltage);
    assert(isequal(size(response.outputResponse_photonsPerIncidentPhoton), ...
        [outputCount inputCount]));
    assert(isequal(size(response.systemMatrix_electronsPerIncidentPhoton), ...
        [measurementCount inputCount]));
    assert(all(isfinite(response.systemMatrix_electronsPerIncidentPhoton),'all'));
    assert(all(response.systemMatrix_electronsPerIncidentPhoton>=0,'all'));
    localAssertClose(max(abs(sum(response.emissionBasis_perBin,1)-1)), ...
        0,0,4e-14);
    assert(max(response.outputPhotonYieldByInput)<=1+128*eps);
    assert(max(response.energyEfficiencyByInput)<=1+128*eps);
    assert(response.numericalRank==inputCount);
    assert(response.conditionNumber<10);
    assert(response.selectedFilmIndex==filmIndex);
    maximumCondition = max(maximumCondition,response.conditionNumber);
end
tests{end+1} = 'All voltage channels have passive, nonnegative full-rank operators';

for filmIndex = 1:config.filmCount
    voltage = config.selector.channelVoltage_V(filmIndex);
    observation = simulateQDDownconversion(truth,voltage,config, ...
        'AddNoise',false);
    assert(abs(observation.conversion.peakWavelength_nm- ...
        config.film.emissionCenter_nm(filmIndex))<=5);
    assert(observation.validity.passiveEnergyConservation);
    assert(observation.validity.singlePhotonYieldAtMostOne);
    assert(~observation.validity.anyComputationalCCDSaturation);
end
midpointProbe_V = mean(config.selector.channelVoltage_V(2:3))+0.05;
midpointResponse = qdBuildDownconversionResponse(config,midpointProbe_V);
assert(midpointResponse.selectedFilmIndex==3);
tests{end+1} = 'Voltage decoder selects nearest fixed emission channel without saturation';

zeroInput = zeros(inputCount,1);
zeroObservation = simulateQDDownconversion(zeroInput, ...
    config.selector.defaultVoltage_V,config,'AddNoise',false);
localAssertClose(max(abs(zeroObservation.detector.signalElectronsExpected)), ...
    0,0,1e-20);
localAssertClose(max(abs(zeroObservation.detector.measuredElectrons- ...
    zeroObservation.response.detectorDarkElectrons)),0,0,1e-20);
localAssertClose(max(abs(zeroObservation.computationalCCD.measuredElectrons- ...
    zeroObservation.response.darkElectronsExpected)),0,0,1e-20);
tests{end+1} = 'Zero optical input produces only the correct detector dark vectors';

response = qdBuildDownconversionResponse(config, ...
    config.selector.defaultVoltage_V);
lineInput = zeros(inputCount,1);
lineIndex = round(0.61*inputCount);
lineInput(lineIndex) = 1e5;
lineObservation = simulateQDDownconversion(lineInput, ...
    config.selector.defaultVoltage_V,config,'AddNoise',false, ...
    'EnforceFullWell',false);
expectedColumn = response.systemMatrix_electronsPerIncidentPhoton(:,lineIndex)*1e5;
localAssertClose(max(abs(lineObservation.computationalCCD. ...
    signalElectronsExpected-expectedColumn)),0,1e-13,1e-10);
tests{end+1} = 'Computational CCD matches the exact calibrated response column';

rngState = rng;
noisyA = simulateQDDownconversion(truth,config.selector.defaultVoltage_V, ...
    config,'AddNoise',true,'Seed',config.randomSeed,'ReconstructSpectrum',true);
postState = rng;
noisyB = simulateQDDownconversion(truth,config.selector.defaultVoltage_V, ...
    config,'AddNoise',true,'Seed',config.randomSeed,'ReconstructSpectrum',true);
assert(isequal(rngState,postState));
assert(isequal(noisyA.computationalCCD.measuredElectrons, ...
    noisyB.computationalCCD.measuredElectrons));
coefficients = corrcoef(truth,noisyA.reconstruction.incidentPhotonsPerBin);
assert(coefficients(1,2)>0.999);
assert(~noisyA.validity.anyComputationalCCDSaturation);
tests{end+1} = 'Seeded detector noise is local, repeatable, and accurately inverted';

for filmIndex = 1:config.filmCount
    observation = simulateQDDownconversion(truth, ...
        config.selector.channelVoltage_V(filmIndex),config, ...
        'AddNoise',true,'Seed',config.randomSeed+filmIndex, ...
        'ReconstructSpectrum',true);
    coefficients = corrcoef(truth, ...
        observation.reconstruction.incidentPhotonsPerBin);
    minimumCorrelation = min(minimumCorrelation,coefficients(1,2));
    assert(coefficients(1,2)>0.999);
end
tests{end+1} = 'Noisy UV reconstruction remains accurate at every voltage channel';

blueResponse = qdBuildDownconversionResponse(config, ...
    config.selector.channelVoltage_V(1));
[~,blueIndex] = min(abs(config.outputWavelength_nm-470));
[~,nirIndex] = min(abs(config.outputWavelength_nm-1410));
assert(blueResponse.siDetectionGain_electronsPerPhoton(blueIndex)> ...
    blueResponse.ingaasDetectionGain_electronsPerPhoton(blueIndex));
assert(blueResponse.ingaasDetectionGain_electronsPerPhoton(nirIndex)> ...
    blueResponse.siDetectionGain_electronsPerPhoton(nirIndex));
tests{end+1} = 'Dichroic routing uses silicon for visible and InGaAs for long NIR';

localAssertError(@()qdBuildDownconversionResponse(config,0), ...
    'QDConverter:SelectorVoltage');
localAssertError(@()simulateQDDownconversion(ones(inputCount-1,1), ...
    config.selector.defaultVoltage_V,config),'QDConverter:IncidentSpectrum');
localAssertError(@()qdDownconversionConfig('EmitterCenter_nm', ...
    [350 535 625 905 1275 1410].'),'QDConverter:DownconversionEnergy');
tests{end+1} = 'Invalid voltage, spectrum, and anti-Stokes passive setup are rejected';

assert(isequal(size(dualConfig.upToCommonMatrix), ...
    [outputCount numel(upConfig.visibleWavelength_nm)]));
localAssertClose(max(abs(sum(dualConfig.upToCommonMatrix,1)-1)),0,0,1e-15);
tests{end+1} = 'Up-conversion mapping to the shared grid conserves photon count';

canonicalResponse = setQDSelectorVoltage(config.selector.defaultVoltage_V);
canonicalDecoder = qdDecodeSelectorVoltage( ...
    config.selector.defaultVoltage_V,config);
assert(canonicalResponse.selectedFilmIndex== ...
    canonicalDecoder.selectedChannelIndex);
tests{end+1} = 'Electronic voltage setter selects the decoded fixed channel';

downModelFile = buildQDUVDownconverter(true);
if bdIsLoaded('QDUVDownconverter'), close_system('QDUVDownconverter',0); end
load_system(downModelFile);
downBinding = get_param( ...
    'QDUVDownconverter/Selector Voltage Slider','Binding');
downLimits = get_param( ...
    'QDUVDownconverter/Selector Voltage Slider','Limits');
assert(downBinding.isBound);
localAssertClose(downLimits(1),config.selector.minimumVoltage_V,0,eps);
localAssertClose(downLimits(3),config.selector.maximumVoltage_V,0,eps);
assert(isempty(find_system('QDUVDownconverter', ...
    'BlockType','RotarySwitchBlock')));
setQDSelectorVoltage(config.selector.defaultVoltage_V);
downOutput = sim('QDUVDownconverter','StopTime','0', ...
    'ReturnWorkspaceOutputs','on');
simOutputSpectrum = localLastVector( ...
    downOutput.get('qdDownOutputSpectrumSim'));
simCCD = localLastVector(downOutput.get('qdDownCCDMeasurementSim'));
simReconstruction = localLastVector( ...
    downOutput.get('qdDownReconstructedUVSim'));
simGates = localLastVector(downOutput.get('qdDownElectronicGatesSim'));
simDecoderTelemetry = localLastVector( ...
    downOutput.get('qdDownDecoderTelemetrySim'));
direct = simulateQDDownconversion(truth,config.selector.defaultVoltage_V, ...
    config,'AddNoise',false,'ReconstructSpectrum',true);
localAssertClose(max(abs(simOutputSpectrum-direct.conversion. ...
    outputSpectrumPhotonCountExpectedPerBin)),0,1e-12,1e-8);
localAssertClose(max(abs(simCCD-direct.computationalCCD. ...
    totalElectronsExpected)),0,1e-12,1e-8);
directSimulinkReconstruction = reconstructQDSpectrum( ...
    direct.computationalCCD.totalElectronsExpected,direct.response, ...
    'Regularization',config.spectrometer.reconstructionRegularization, ...
    'MaxIterations',config.spectrometer.reconstructionMaxIterations);
localAssertClose(max(abs(simReconstruction-directSimulinkReconstruction. ...
    incidentPhotonsPerBin)),0,1e-10,1e-6);
assert(sum(simGates)==1 && ...
    simGates(direct.response.selectedFilmIndex)==1);
assert(simDecoderTelemetry(3)==direct.response.selectedFilmIndex);
assert(simDecoderTelemetry(4)== ...
    config.selector.channelVoltage_V(direct.response.selectedFilmIndex));
assert(getSimulinkBlockHandle( ...
    'QDUVDownconverter/ADC Window Decoder + Gate Driver')>0);

endpointIndices = [1 config.filmCount];
for endpoint = 1:numel(endpointIndices)
    filmIndex = endpointIndices(endpoint);
    setQDSelectorVoltage(config.selector.channelVoltage_V(filmIndex));
    endpointOutput = sim('QDUVDownconverter','StopTime','0', ...
        'ReturnWorkspaceOutputs','on');
    endpointSpectrum = localLastVector( ...
        endpointOutput.get('qdDownOutputSpectrumSim'));
    endpointGates = localLastVector( ...
        endpointOutput.get('qdDownElectronicGatesSim'));
    [~,peakIndex] = max(endpointSpectrum);
    assert(abs(config.outputWavelength_nm(peakIndex)- ...
        config.film.emissionCenter_nm(filmIndex))<=5);
    assert(sum(endpointGates)==1 && endpointGates(filmIndex)==1);
end
setQDSelectorVoltage(config.selector.defaultVoltage_V);
close_system('QDUVDownconverter',0);
tests{end+1} = ['Down-converter voltage slider binds, changes channels, ' ...
    'and matches MATLAB equations'];

dualModelFile = buildQDVoltageSelectedDualConverter(true);
if bdIsLoaded('QDVoltageSelectedDualConverter')
    close_system('QDVoltageSelectedDualConverter',0);
end
load_system(dualModelFile);
modeBinding = get_param( ...
    'QDVoltageSelectedDualConverter/Conversion Mode Switch','Binding');
wavelengthBinding = get_param( ...
    'QDVoltageSelectedDualConverter/Selector Voltage Slider','Binding');
assert(modeBinding.isBound && wavelengthBinding.isBound);
modeStates = get_param( ...
    'QDVoltageSelectedDualConverter/Conversion Mode Switch','States');
assert(isequal(sort(cell2mat({modeStates.Value})),[0 1]));
assert(isempty(find_system('QDVoltageSelectedDualConverter', ...
    'BlockType','RotarySwitchBlock')));

setQDConversionMode(0);
upOutput = sim('QDVoltageSelectedDualConverter','StopTime','0', ...
    'ReturnWorkspaceOutputs','on');
selectedUp = localLastVector(upOutput.get('qdDualSelectedSpectrumSim'));
upResponse = evalin('base','qdSpectrometerResponse');
swirTruth = evalin('base','qdIncidentSpectrum');
expectedUp = dualConfig.upToCommonMatrix* ...
    upResponse.visibleEmissionBasis_perBin* ...
    upResponse.converterResponse_photonsPerIncidentPhoton*swirTruth;
localAssertClose(max(abs(selectedUp-expectedUp)),0,1e-12,1e-8);

setQDConversionMode(1);
setQDSelectorVoltage(config.selector.defaultVoltage_V);
downModeOutput = sim('QDVoltageSelectedDualConverter','StopTime','0', ...
    'ReturnWorkspaceOutputs','on');
selectedDown = localLastVector( ...
    downModeOutput.get('qdDualSelectedSpectrumSim'));
dualGates = localLastVector( ...
    downModeOutput.get('qdDualElectronicGatesSim'));
dualDecoderTelemetry = localLastVector( ...
    downModeOutput.get('qdDualDecoderTelemetrySim'));
localAssertClose(max(abs(selectedDown-direct.conversion. ...
    outputSpectrumPhotonCountExpectedPerBin)),0,1e-12,1e-8);
assert(sum(dualGates)==1 && ...
    dualGates(direct.response.selectedFilmIndex)==1);
assert(dualDecoderTelemetry(3)==direct.response.selectedFilmIndex);
close_system('QDVoltageSelectedDualConverter',0);
tests{end+1} = 'Combined SLX electronic controls select exact optical branches';

report = struct();
report.passed = numel(tests);
report.failed = 0;
report.tests = tests;
report.timestamp = char(datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd HH:mm:ss Z'));
report.matlabVersion = version;
report.maximumResponseConditionNumber = maximumCondition;
report.minimumNoisyCorrelation = minimumCorrelation;
report.downconversionModel = downModelFile;
report.dualConversionModel = dualModelFile;
fileID = fopen(fullfile(paths.reports,'uv-and-dual-validation.txt'),'w');
if fileID<0
    error('QDConverter:ArtifactWrite','Cannot write downconversion test report.');
end
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'QD Downconversion and Dual-Mode Simulink Tests\n');
fprintf(fileID,'Timestamp: %s\nMATLAB: %s\nPassed: %d\nFailed: %d\n\n', ...
    report.timestamp,report.matlabVersion,report.passed,report.failed);
for testIndex = 1:numel(tests)
    fprintf(fileID,'PASS  %s\n',tests{testIndex});
end
fprintf(fileID,'\nMaximum response condition number: %.12g\n', ...
    maximumCondition);
fprintf(fileID,'Minimum noisy reconstruction correlation: %.12g\n', ...
    minimumCorrelation);
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
