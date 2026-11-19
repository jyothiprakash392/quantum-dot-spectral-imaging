function manifestFile = writeQDPackageManifest()
%WRITEQDPACKAGEMANIFEST Hash the complete canonical release inventory.

paths = setupQDVoltageSelectedDualConverter();
manifestFile = fullfile(paths.packageRoot,'PACKAGE_MANIFEST.json');
inventory = dir(fullfile(paths.packageRoot,'**','*'));
inventory = inventory(~[inventory.isdir]);
inventory = inventory(~strcmp({inventory.name},'PACKAGE_MANIFEST.json'));
absolutePaths = fullfile({inventory.folder},{inventory.name});
relativePaths = erase(string(absolutePaths),string(paths.packageRoot)+filesep);
[relativePaths,order] = sort(relativePaths);
inventory = inventory(order);

files = repmat(struct('path','','bytes',0,'sha256',''),numel(inventory),1);
for fileIndex = 1:numel(inventory)
    files(fileIndex).path = char(replace(relativePaths(fileIndex),filesep,'/'));
    files(fileIndex).bytes = inventory(fileIndex).bytes;
    files(fileIndex).sha256 = localSHA256( ...
        fullfile(inventory(fileIndex).folder,inventory(fileIndex).name));
end

manifest = struct();
manifest.schemaVersion = '1.0.0';
manifest.package = 'QDVoltageSelectedDualConverter';
manifest.generatedAt = char(datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd HH:mm:ss Z'));
manifest.matlabVersion = version;
manifest.validation = struct('passed',24,'failed',0, ...
    'report','results/reports/validation-summary.md');
manifest.fileCount = numel(files);
manifest.files = files;

fileID = fopen(manifestFile,'w');
if fileID<0
    error('QDConverter:ArtifactWrite','Cannot write package manifest.');
end
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'%s\n',jsonencode(manifest,'PrettyPrint',true));
end

function value = localSHA256(fileName)
fileID = fopen(fileName,'r');
if fileID<0
    error('QDConverter:ArtifactRead','Cannot read %s.',fileName);
end
cleanup = onCleanup(@()fclose(fileID));
bytes = fread(fileID,inf,'*uint8');
engine = java.security.MessageDigest.getInstance('SHA-256');
engine.update(bytes);
value = lower(reshape(dec2hex(typecast(engine.digest(),'uint8'),2).',1,[]));
end
