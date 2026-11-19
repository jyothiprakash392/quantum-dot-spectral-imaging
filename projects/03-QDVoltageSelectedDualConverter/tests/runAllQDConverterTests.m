function summary = runAllQDConverterTests()
%RUNALLQDCONVERTERTESTS Run both validation suites and write one summary.

paths = setupQDVoltageSelectedDualConverter();
uvAndDual = testQDUVAndDualConversion();
swir = testQDSWIRUpconversion();
summary = struct();
summary.package = 'QDVoltageSelectedDualConverter';
summary.timestamp = char(datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd HH:mm:ss Z'));
summary.matlabVersion = version;
summary.uvAndDual = uvAndDual;
summary.swir = swir;
summary.passed = uvAndDual.passed+swir.passed;
summary.failed = uvAndDual.failed+swir.failed;
summary.allPassed = summary.failed==0;

jsonFile = fullfile(paths.reports,'validation-summary.json');
fileID = fopen(jsonFile,'w');
if fileID<0
    error('QDConverter:ArtifactWrite','Cannot write validation JSON.');
end
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'%s\n',jsonencode(summary,'PrettyPrint',true));
clear cleanup

markdownFile = fullfile(paths.reports,'validation-summary.md');
fileID = fopen(markdownFile,'w');
if fileID<0
    error('QDConverter:ArtifactWrite','Cannot write validation summary.');
end
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'# Validation summary\n\n');
fprintf(fileID,'- Package: `%s`\n',summary.package);
fprintf(fileID,'- Timestamp: %s\n',summary.timestamp);
fprintf(fileID,'- MATLAB: %s\n',summary.matlabVersion);
fprintf(fileID,'- Passed: %d\n',summary.passed);
fprintf(fileID,'- Failed: %d\n',summary.failed);
fprintf(fileID,'- Overall: %s\n',localStatus(summary.allPassed));
end

function value = localStatus(passed)
if passed
    value = 'PASS';
else
    value = 'FAIL';
end
end
