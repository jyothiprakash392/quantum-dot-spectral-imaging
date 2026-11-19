function inputs = qdAccurateCdSeInputs(radius_nm)
%QDACCURATECDSEINPUTS Calibration-scoped profile for empirical CdSe cores.
%   INPUTS = QDACCURATECDSEINPUTS(RADIUS_NM) prepares the highest-accuracy
%   delivered optical-energy profile. Its published-curve calibration scope is
%   diameter 3-8 nm, near 300 K, zero field/strain, organic environment.

if nargin < 1
    radius_nm = 3.0;
end
validateattributes(radius_nm,{'numeric'}, ...
    {'real','finite','scalar','>=',1.5,'<=',4.0});

inputs = qdDefaultInputs();
inputs.radius_nm = radius_nm;
inputs.temperature_K = 300;
inputs.electricField_kVcm = 0;
inputs.hydrostaticStrain_pct = 0;
inputs.shellThickness_nm = 0;
inputs.surfaceTrapDensity_cm2 = 0;
inputs.environmentDielectric = 2.25;
inputs.electronBarrier_eV = 0;
inputs.holeBarrier_eV = 0;
inputs.targetEmission_eV = 0;
inputs.materialID = 5;
end
