function spectrum = qdGenerateSpectra(result,temperature_K,energyGrid_eV)
%QDGENERATESPECTRA Normalized absorption and PL spectra.
%   The optional third argument supplies a common strictly increasing energy
%   grid. Existing one- and two-argument behavior remains unchanged.

if nargin < 2
    temperature_K = 300;
end
if nargin < 3 || isempty(energyGrid_eV)
    Emin = max(0.05,result.plEnergy_eV-0.50);
    % Include the 350 nm cross-section calibration point in every range.
    Emax = max(result.absorptionEnergy_eV+1.10,3.75);
    energy_eV = linspace(Emin,Emax,1001).';
else
    validateattributes(energyGrid_eV,{'numeric'}, ...
        {'vector','real','finite','positive','increasing'}, ...
        mfilename,'energyGrid_eV',3);
    energy_eV = energyGrid_eV(:);
end

phonon_eV = result.material.LOPhononEnergy_eV;
fwhmPL = max(0.025,0.045+1.2e-4*temperature_K+ ...
    0.020/max(expm1(phonon_eV/(8.617333262e-5*max(temperature_K,1))),realmin));
fwhmAbs = max(0.035,1.25*fwhmPL);
gPL = localGaussian(energy_eV,result.plEnergy_eV,fwhmPL);
g1 = localGaussian(energy_eV,result.absorptionEnergy_eV,fwhmAbs);
g2 = localGaussian(energy_eV,result.absorptionEnergy_eV+ ...
    0.65*(result.electronConfinement_eV+result.holeConfinement_eV),1.5*fwhmAbs);
absShape = 0.78*g1+0.22*g2;
absShape = absShape/trapz(energy_eV,absShape);
baseCrossSection_m2 = result.material.absorptionCrossSectionAt350nm3nm_m2* ...
    (result.effectiveInputs.radius_nm/3.0)^3;

% Pump-independent point cross section using the same C1 band-edge/Urbach
% response as the dynamics core, normalized to the measured 350 nm value.
urbachEnergy_eV = 0.030;
edgeOffset_eV = 0.5*urbachEnergy_eV;
delta_eV = energy_eV-result.absorptionEnergy_eV;
rawFactor = sqrt(edgeOffset_eV)*exp(max(-80,min(80, ...
    delta_eV/urbachEnergy_eV)));
aboveEdge = delta_eV >= 0;
rawFactor(aboveEdge) = sqrt(delta_eV(aboveEdge)+edgeOffset_eV);
referenceDelta_eV = 3.5424-result.absorptionEnergy_eV;
if referenceDelta_eV >= 0
    referenceFactor = sqrt(referenceDelta_eV+edgeOffset_eV);
else
    referenceFactor = sqrt(edgeOffset_eV)* ...
        exp(max(-80,referenceDelta_eV/urbachEnergy_eV));
end
intrinsicCrossSection_m2 = baseCrossSection_m2*min(3,max(0, ...
    rawFactor/max(referenceFactor,realmin)));

spectrum = struct();
spectrum.energy_eV = energy_eV;
spectrum.wavelength_nm = 1239.841984332./energy_eV;
spectrum.absorptionCrossSection_m2 = intrinsicCrossSection_m2;
spectrum.absorption_m2_per_eV = baseCrossSection_m2*absShape;
spectrum.plPhotons_Hz_per_eV = result.plPhotonRate_Hz*gPL;
% Correct Jacobian for wavelength-domain densities. The ascending grid is
% separate so the legacy energy-aligned fields remain backward compatible.
hc_eVnm = 1239.841984332;
jacobian_eV_per_nm = hc_eVnm./spectrum.wavelength_nm.^2;
spectrum.wavelengthAscending_nm = flipud(spectrum.wavelength_nm);
spectrum.absorptionCrossSectionAscending_m2 = flipud(intrinsicCrossSection_m2);
spectrum.absorption_m2_per_nm = flipud( ...
    spectrum.absorption_m2_per_eV.*jacobian_eV_per_nm);
spectrum.plPhotons_Hz_per_nm = flipud( ...
    spectrum.plPhotons_Hz_per_eV.*jacobian_eV_per_nm);
spectrum.plFWHM_eV = fwhmPL;
spectrum.absorptionFWHM_eV = fwhmAbs;
spectrum.absorptionDensityInterpretation = [ ...
    'Normalized excitonic line-shape area scaled by the 350 nm cross section; ' ...
    'use absorptionCrossSection_m2 for pointwise pump calculations.'];
end

function g = localGaussian(x,center,fwhm)
coefficient = 2*sqrt(log(2))/(fwhm*sqrt(pi));
g = coefficient*exp(-4*log(2)*((x-center)/fwhm).^2);
g = g/max(trapz(x,g),realmin);
end
