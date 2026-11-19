function [effectiveInput,pump] = qdResolvePumpInputs(qdInput)
%QDRESOLVEPUMPINPUTS Convert photon count and lambda1 to legacy pump inputs.
%   incidentPhotonCount > 0 activates a uniform square-pulse interface.
%   A count requires beam area and duration to define photon flux.

defaults = qdDefaultInputs();
optionalNames = {'stokesShiftOverride_eV','incidentPhotonCount','inputWavelength_nm', ...
    'beamArea_um2','pumpDuration_ns'};
for k = 1:numel(optionalNames)
    name = optionalNames{k};
    if ~isfield(qdInput,name)
        qdInput.(name) = defaults.(name);
    end
end

requiredNames = qdInputNames();
for k = 1:numel(requiredNames)
    name = requiredNames{k};
    if ~isfield(qdInput,name)
        error('VirtualQD:MissingInput','Missing input field: %s',name);
    end
    localValidateScalar(qdInput.(name),name);
end
for k = 1:numel(optionalNames)
    localValidateScalar(qdInput.(optionalNames{k}),optionalNames{k});
end

if qdInput.incidentPhotonCount < 0
    error('VirtualQD:PhotonCount','incidentPhotonCount must be nonnegative.');
end
if qdInput.radius_nm < 0.5 || qdInput.radius_nm > 50
    error('VirtualQD:Radius','radius_nm must be in [0.5, 50].');
end
if qdInput.temperature_K < 0 || qdInput.temperature_K > 1000
    error('VirtualQD:Temperature','temperature_K must be in [0, 1000].');
end
if abs(qdInput.electricField_kVcm) > 1.0e4
    error('VirtualQD:ElectricField', ...
        'electricField_kVcm magnitude must not exceed 10000.');
end
if abs(qdInput.hydrostaticStrain_pct) > 20
    error('VirtualQD:Strain', ...
        'hydrostaticStrain_pct magnitude must not exceed 20.');
end
if qdInput.pumpIntensity_Wcm2 < 0 || qdInput.pumpPhotonEnergy_eV <= 0
    error('VirtualQD:Pump','Legacy pump intensity must be nonnegative and energy positive.');
end
if qdInput.shellThickness_nm < 0 || qdInput.shellThickness_nm > 100 || ...
        qdInput.surfaceTrapDensity_cm2 < 0 || ...
        qdInput.surfaceTrapDensity_cm2 > 1.0e16
    error('VirtualQD:Surface', ...
        'Shell thickness must be in [0,100] nm and trap density in [0,1e16] cm^-2.');
end
if qdInput.environmentDielectric < 1 || qdInput.environmentDielectric > 100
    error('VirtualQD:Environment','environmentDielectric must be in [1,100].');
end
if qdInput.electronBarrier_eV < 0 || qdInput.electronBarrier_eV > 20 || ...
        qdInput.holeBarrier_eV < 0 || qdInput.holeBarrier_eV > 20
    error('VirtualQD:Barrier','Barrier overrides must be in [0, 20] eV.');
end
if qdInput.targetEmission_eV < 0
    error('VirtualQD:Target','targetEmission_eV must be nonnegative.');
end
if qdInput.materialID ~= round(qdInput.materialID) || ...
        qdInput.materialID < 1 || qdInput.materialID > 5
    error('VirtualQD:Material','materialID must be an integer from 1 through 5.');
end
if qdInput.stokesShiftOverride_eV < 0 || qdInput.stokesShiftOverride_eV > 1
    error('VirtualQD:StokesShift','stokesShiftOverride_eV must be in [0, 1] eV.');
end

effectiveInput = qdInput;
material = qdMaterialVector(qdInput.materialID);
if effectiveInput.electronBarrier_eV == 0
    effectiveInput.electronBarrier_eV = material(9);
end
if effectiveInput.holeBarrier_eV == 0
    effectiveInput.holeBarrier_eV = material(10);
end
pump = struct();
pump.incidentPhotonCount = qdInput.incidentPhotonCount;
pump.requestedWavelength_nm = qdInput.inputWavelength_nm;
pump.beamArea_um2 = qdInput.beamArea_um2;
pump.duration_ns = qdInput.pumpDuration_ns;
pump.mode = 'legacy-intensity';

hc_eVnm = 1239.841984332;
electronCharge_C = 1.602176634e-19;
if qdInput.incidentPhotonCount > 0
    if qdInput.inputWavelength_nm <= 0
        error('VirtualQD:PumpWavelength', ...
            'inputWavelength_nm must be positive in photon-count mode.');
    end
    if qdInput.beamArea_um2 <= 0
        error('VirtualQD:BeamArea', ...
            'beamArea_um2 must be positive in photon-count mode.');
    end
    if qdInput.pumpDuration_ns <= 0
        error('VirtualQD:PumpDuration', ...
            'pumpDuration_ns must be positive in photon-count mode.');
    end

    effectiveInput.pumpPhotonEnergy_eV = ...
        hc_eVnm/qdInput.inputWavelength_nm;
    pump.photonFlux_cm2_s = qdInput.incidentPhotonCount*1.0e17/ ...
        (qdInput.beamArea_um2*qdInput.pumpDuration_ns);
    effectiveInput.pumpIntensity_Wcm2 = pump.photonFlux_cm2_s* ...
        effectiveInput.pumpPhotonEnergy_eV*electronCharge_C;
    if ~isfinite(effectiveInput.pumpIntensity_Wcm2) || ...
            ~isfinite(pump.photonFlux_cm2_s)
        error('VirtualQD:PhotonDose', ...
            'Photon inputs produce a nonfinite flux or intensity.');
    end
    pump.mode = 'photon-count-square-pulse';
else
    pump.photonFlux_cm2_s = effectiveInput.pumpIntensity_Wcm2/ ...
        max(effectiveInput.pumpPhotonEnergy_eV*electronCharge_C,realmin);
end

pump.effectivePhotonEnergy_eV = effectiveInput.pumpPhotonEnergy_eV;
pump.effectiveIntensity_Wcm2 = effectiveInput.pumpIntensity_Wcm2;
pump.effectiveWavelength_nm = hc_eVnm/ ...
    max(effectiveInput.pumpPhotonEnergy_eV,realmin);
pump.fluence_photons_cm2 = pump.photonFlux_cm2_s* ...
    max(qdInput.pumpDuration_ns,0)*1.0e-9;
end

function localValidateScalar(value,name)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
    error('VirtualQD:InputType','%s must be a finite real numeric scalar.',name);
end
end
