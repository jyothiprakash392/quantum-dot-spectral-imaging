# Reproducibility instructions — version 1.5.1

## Environment

The frozen publication audit was run with MATLAB R2026a Update 4. Simulink is
required for the core and multi-material integration suites. Statistics and
Machine Learning Toolbox is required to regenerate the optional model-selection
benchmark, but not to execute the frozen regressions.

## Run from the exact package folder

```matlab
cd('/Users/jyohtiprakash/Documents/Codex/2026-08-19/yo/outputs/VirtualQuantumDotAgent')
restoredefaultpath
addpath(pwd)

core = runQDTests;
empirical = runRealWorldValidationTests;
materials = runMultiMaterialCalibrationTests;
hybrid = runQDHybridTests;
ensemble = runQDEnsembleTests;

assert(core.failed == 0 && empirical.failed == 0 && ...
       materials.failed == 0 && hybrid.failed == 0 && ...
       ensemble.failed == 0)
assert(core.passed + empirical.passed + materials.passed + ...
       hybrid.passed + ensemble.passed == 73)
```

Expected suite counts are 20, 7, 22, 10, and 14.

## Static analysis and manifest

```matlab
files = dir('*.m');
issueCount = 0;
for k = 1:numel(files)
    issueCount = issueCount + numel(checkcode(files(k).name,'-id'));
end
assert(issueCount == 0)

runQDEnsembleDemo;
manifest = writeValidationManifest;
```

`VALIDATION_MANIFEST.json` records the tested MATLAB release, suite counts,
validation metadata, and SHA-256 hashes. Because the manifest hashes itself only
indirectly through its listed artifacts, regenerate it last after every source,
documentation, or frozen-result change.

## Simulink integrity

The v1.5.1 publication corrections do not require rebuilding
`VirtualQuantumDotAgent.slx`; they preserve the fixed 14-input/40-output model.
The core and multi-material suites load, update, and execute the model and compare
selected outputs with the direct engine. Record the `.slx` SHA-256 from the
manifest for the submitted release.

## Generated artifacts

Test functions overwrite their corresponding MAT/TXT/CSV reports. The ensemble
demo overwrites its PNG, MAT, and comparison CSV. Timestamps therefore change on
reproduction. Scientific metric values and suite counts should remain fixed
within the stated numeric tolerances.

## Archival recommendation

For publication, archive a clean release containing source code, the `.slx`
model, permitted reference/derived data, frozen reports, documentation, license,
and manifest. Exclude autosave, Simulink cache, and machine-specific build
directories unless the target repository explicitly requests them.
