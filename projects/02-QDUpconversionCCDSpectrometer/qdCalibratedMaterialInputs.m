function inputs = qdCalibratedMaterialInputs(materialID,sourceSize_nm)
%QDCALIBRATEDMATERIALINPUTS Create source-scoped inputs for IDs 2 through 4.
%   ID 2 interprets SOURCE_SIZE_NM as the regular-tetrahedron core edge.
%   ID 3 interprets it as PbS core diameter. ID 4 interprets it as nanocube
%   edge length. Non-spherical sources are converted to an equal-volume-
%   sphere radius because the physics engine retains one scalar radius input.

validateattributes(materialID,{'numeric'}, ...
    {'real','finite','scalar','integer','>=',2,'<=',4});
validateattributes(sourceSize_nm,{'numeric'}, ...
    {'real','finite','scalar','positive'});

if materialID == 2 && (sourceSize_nm^3/(6*sqrt(2)) < 1.0-64*eps || ...
        sourceSize_nm^3/(6*sqrt(2)) > 10.0+64*eps)
    error('VirtualQD:CalibrationSize', ...
        'InP calibrated tetrahedral core volume is 1 through 10 nm^3.');
elseif materialID == 3 && (sourceSize_nm < 3.9 || sourceSize_nm > 13.3)
    error('VirtualQD:CalibrationSize', ...
        'PbS calibrated core diameter is 3.9 through 13.3 nm.');
elseif materialID == 4 && (sourceSize_nm < 3.0 || sourceSize_nm > 12.8)
    error('VirtualQD:CalibrationSize', ...
        'CsPbBr3 calibrated nanocube edge length is 3.0 through 12.8 nm.');
end

inputs = qdDefaultInputs();
if materialID == 2
    volume_nm3 = sourceSize_nm^3/(6*sqrt(2));
    inputs.radius_nm = (3*volume_nm3/(4*pi))^(1/3);
elseif materialID == 4
    inputs.radius_nm = (3/(4*pi))^(1/3)*sourceSize_nm;
else
    inputs.radius_nm = sourceSize_nm/2;
end
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
inputs.materialID = materialID;
inputs.stokesShiftOverride_eV = 0;
end
