function [y,pNext] = qdPhysicsStep(u,pPrevious,timeStep_s)
%QDPHYSICSSTEP One positivity-preserving virtual quantum-dot update.
%#codegen
%   u is the 14-element vector documented by qdInputNames.
%   pPrevious is [p0; pX; pXX; pTrap]. The default 10 ps update matches the
%   generated Simulink model. A third input permits exact fractional final
%   steps; zero evaluates outputs without advancing state.

% 2022 CODATA exact/standard constants used by this model.
electronCharge = 1.602176634e-19;
boltzmannEV = 8.617333262e-5;
boltzmannSI = 1.380649e-23;
electronMass = 9.1093837015e-31;
if nargin < 3
    timeStep_s = 1.0e-11;
elseif ~isfinite(timeStep_s) || timeStep_s < 0
    timeStep_s = 0;
end

y = zeros(40,1);
flags = uint32(0);

% Validate and safely constrain the public interface.
radius_nm = u(1);
if ~isfinite(radius_nm) || radius_nm <= 0
    radius_nm = 3.0;
    flags = bitor(flags,uint32(1));
elseif radius_nm < 0.5
    radius_nm = 0.5;
    flags = bitor(flags,uint32(1));
elseif radius_nm > 50
    radius_nm = 50;
    flags = bitor(flags,uint32(1));
end

temperature_K = u(2);
if ~isfinite(temperature_K) || temperature_K < 0
    temperature_K = 300;
    flags = bitor(flags,uint32(2));
elseif temperature_K > 1000
    temperature_K = 1000;
    flags = bitor(flags,uint32(2));
end

field_kVcm = u(3);
if ~isfinite(field_kVcm)
    field_kVcm = 0;
    flags = bitor(flags,uint32(4));
elseif abs(field_kVcm) > 1.0e4
    field_kVcm = sign(field_kVcm)*1.0e4;
    flags = bitor(flags,uint32(4));
end

strain_pct = u(4);
if ~isfinite(strain_pct)
    strain_pct = 0;
    flags = bitor(flags,uint32(8));
elseif abs(strain_pct) > 20
    strain_pct = sign(strain_pct)*20;
    flags = bitor(flags,uint32(8));
end

pump_Wcm2 = u(5);
if ~isfinite(pump_Wcm2) || pump_Wcm2 < 0
    pump_Wcm2 = 0;
    flags = bitor(flags,uint32(8192));
end

pumpEnergy_eV = u(6);
if ~isfinite(pumpEnergy_eV) || pumpEnergy_eV <= 0
    pumpEnergy_eV = 3.5424;
    flags = bitor(flags,uint32(8192));
end

shell_nm = u(7);
if ~isfinite(shell_nm) || shell_nm < 0
    shell_nm = 0;
    flags = bitor(flags,uint32(16384));
elseif shell_nm > 100
    shell_nm = 100;
    flags = bitor(flags,uint32(16384));
end

trapDensity_cm2 = u(8);
if ~isfinite(trapDensity_cm2) || trapDensity_cm2 < 0
    trapDensity_cm2 = 0;
    flags = bitor(flags,uint32(32768));
elseif trapDensity_cm2 > 1.0e16
    trapDensity_cm2 = 1.0e16;
    flags = bitor(flags,uint32(32768));
end

epsOut = u(9);
if ~isfinite(epsOut) || epsOut < 1
    epsOut = 1;
    flags = bitor(flags,uint32(65536));
elseif epsOut > 100
    epsOut = 100;
    flags = bitor(flags,uint32(65536));
end

electronBarrier_eV = u(10);
holeBarrier_eV = u(11);
targetEnergy_eV = u(12);
if ~isfinite(targetEnergy_eV) || targetEnergy_eV <= 0
    targetEnergy_eV = 0;
end

rawMaterialID = u(13);
materialID = round(rawMaterialID);
if ~isfinite(rawMaterialID) || abs(rawMaterialID-materialID) > 1.0e-12 || ...
        materialID < 1 || materialID > 5
    materialID = 1;
    flags = bitor(flags,uint32(256));
end

stokesShiftOverride_eV = u(14);
if ~isfinite(stokesShiftOverride_eV) || stokesShiftOverride_eV < 0
    stokesShiftOverride_eV = 0;
    flags = bitor(flags,uint32(1048576));
elseif stokesShiftOverride_eV > 1.0
    stokesShiftOverride_eV = 1.0;
    flags = bitor(flags,uint32(1048576));
end

material = qdMaterialVector(materialID);
if ~isfinite(electronBarrier_eV) || electronBarrier_eV <= 0
    electronBarrier_eV = material(9);
elseif electronBarrier_eV > 20
    electronBarrier_eV = 20;
    flags = bitor(flags,uint32(2048));
end
if ~isfinite(holeBarrier_eV) || holeBarrier_eV <= 0
    holeBarrier_eV = material(10);
elseif holeBarrier_eV > 20
    holeBarrier_eV = 20;
    flags = bitor(flags,uint32(2048));
end

[stat,staticFlags] = localStaticModel(radius_nm,temperature_K,field_kVcm, ...
    strain_pct,shell_nm,epsOut,electronBarrier_eV,holeBarrier_eV,materialID, ...
    stokesShiftOverride_eV);
flags = bitor(flags,staticFlags);

% Continuous pump response normalized to the measured 350 nm cross section.
% A square-root continuum is joined continuously to an Urbach-like tail.
urbachEnergy_eV = 0.030;
edgeOffset_eV = 0.5*urbachEnergy_eV;
pumpExcess_eV = pumpEnergy_eV-stat(8);
referenceExcess_eV = 3.5424-stat(8);
if pumpExcess_eV >= 0
    rawPumpFactor = sqrt(pumpExcess_eV+edgeOffset_eV);
else
    rawPumpFactor = sqrt(edgeOffset_eV)* ...
        exp(max(-80,pumpExcess_eV/urbachEnergy_eV));
    if pump_Wcm2 > 0
        flags = bitor(flags,uint32(512));
    end
end
if referenceExcess_eV >= 0
    rawReferenceFactor = sqrt(referenceExcess_eV+edgeOffset_eV);
else
    rawReferenceFactor = sqrt(edgeOffset_eV)* ...
        exp(max(-80,referenceExcess_eV/urbachEnergy_eV));
end
spectralFactor = min(3.0,max(0,rawPumpFactor/max(rawReferenceFactor,realmin)));
absorptionCrossSection_m2 = stat(12)*spectralFactor;
photonEnergy_J = pumpEnergy_eV*electronCharge;
rawGenerationRate = absorptionCrossSection_m2*(pump_Wcm2*1.0e4)/photonEnergy_J;
if ~isfinite(rawGenerationRate) || rawGenerationRate > 1.0e14
    flags = bitor(flags,uint32(131072));
end
generationRate = min(max(rawGenerationRate,0),1.0e14);

% Input-dependent recombination and surface rates. For CsPbBr3, a measured
% ambient PL-energy-to-rate relation replaces the generic monotonic law
% inside its source envelope; explicit traps remain an additive scenario.
overlap = stat(11);
useCsPbBr3RateCalibration = materialID == 4 && ...
    bitand(staticFlags,uint32(2097152)) == 0 && ...
    temperature_K >= 293 && temperature_K <= 303 && ...
    stat(9) >= 2.445466802 && stat(9) <= 2.654928626;
if useCsPbBr3RateCalibration
    [radiativeRate,calibratedNonradiativeRate] = ...
        qdCsPbBr3RateModel(stat(9));
    if trapDensity_cm2 > 0
        flags = bitor(flags,uint32(16777216));
    end
elseif materialID == 5 && radius_nm >= 1.5 && radius_nm <= 4.0 && ...
        temperature_K >= 250 && temperature_K <= 350 && ...
        abs(field_kVcm) <= 1.0e-12 && abs(strain_pct) <= 1.0e-12 && ...
        shell_nm <= 0.05 && abs(epsOut-2.25) <= 0.50 && ...
        abs(electronBarrier_eV-material(9)) <= 1.0e-9 && ...
        abs(holeBarrier_eV-material(10)) <= 1.0e-9
    % Room-temperature CdSe bright-exciton relation from de Mello
    % Donega/Koole (2009). This is a calibration, not an independent test.
    radiativeRate = max(1.0e3,(-0.1151+0.0753*stat(9))*1.0e9);
else
    radiativeRate = material(13)*overlap*(max(stat(9),0.05)/2.0)^3;
end
radiativeRate = min(max(radiativeRate,1.0e3),1.0e11);

if temperature_K > 0
    phononOccupation = 1/expm1(min(material(18)/(boltzmannEV*temperature_K),700));
    thermalEscapeRate = 1.0e12*exp(max(-700,-material(23)/(boltzmannEV*temperature_K)));
else
    phononOccupation = 0;
    thermalEscapeRate = 0;
end
if useCsPbBr3RateCalibration
    nonradiativeRate = calibratedNonradiativeRate;
else
    nonradiativeRate = material(14)*(1+0.25*phononOccupation);
end
usePbSCdSAugerCalibration = false;
if materialID == 3
    [pbSCdSAugerRate,~,pbSCdSGeometryInScope] = ...
        qdPbSCdSAugerModel(2.0*radius_nm,shell_nm);
    usePbSCdSAugerCalibration = pbSCdSGeometryInScope && ...
        temperature_K >= 293 && temperature_K <= 303 && ...
        abs(field_kVcm) <= 1.0e-12 && abs(strain_pct) <= 1.0e-12;
else
    pbSCdSAugerRate = 0;
end
if usePbSCdSAugerCalibration
    augerRate = pbSCdSAugerRate;
else
    augerRate = material(16)*(3.0/radius_nm)^3*exp(-shell_nm/8.0);
end
augerRate = min(max(augerRate,0),1.0e14);

radius_m = radius_nm*1.0e-9;
shell_m = shell_nm*1.0e-9;
trapDensity_m2 = trapDensity_cm2*1.0e4;
reducedMass = material(4)*material(5)/(material(4)+material(5))*electronMass;
thermalVelocity = sqrt(max(0,3*boltzmannSI*temperature_K/reducedMass));
barrierMass = min(material(11),material(12))*electronMass;
barrierEnergy = min(electronBarrier_eV,holeBarrier_eV)*electronCharge;
kappaBarrier = sqrt(max(0,2*barrierMass*barrierEnergy))/1.054571817e-34;
shellSuppression = exp(-min(700,2*kappaBarrier*shell_m));
surfaceVelocity = material(15)*thermalVelocity*trapDensity_m2;
trapCaptureRate = 3*surfaceVelocity/max(radius_m,1.0e-12)*max(shellSuppression,1.0e-8);
trapCaptureRate = min(max(trapCaptureRate,0),1.0e14);

% Four-state Markov master equation: [ground, exciton, biexciton, trap].
p = pPrevious(:);
if numel(p) ~= 4 || any(~isfinite(p))
    p = [1;0;0;0];
    flags = bitor(flags,uint32(1024));
else
    if any(p < -1.0e-10) || abs(sum(p)-1) > 1.0e-8
        flags = bitor(flags,uint32(1024));
    end
    p = max(p,0);
    pSum = sum(p);
    if pSum <= 0
        p = [1;0;0;0];
    else
        p = p/pSum;
    end
end

secondExcitonGeneration = 0.60*generationRate;
singleExcitonDecay = radiativeRate+nonradiativeRate;
biexcitonDecay = 2*radiativeRate+2*nonradiativeRate+augerRate;
trapDecayRate = material(24);

Q = zeros(4,4);
Q(2,1) = generationRate;
Q(1,1) = -generationRate;
Q(1,2) = singleExcitonDecay;
Q(3,2) = secondExcitonGeneration;
Q(4,2) = trapCaptureRate;
Q(2,2) = -(singleExcitonDecay+secondExcitonGeneration+trapCaptureRate);
Q(2,3) = biexcitonDecay;
Q(3,3) = -biexcitonDecay;
Q(2,4) = thermalEscapeRate;
Q(1,4) = trapDecayRate;
Q(4,4) = -(thermalEscapeRate+trapDecayRate);

% Exact constant-rate propagation and exact integrated event rewards. The
% reward rows correspond to absorption, total photon emission, and the trap
% emission subset. Returning interval-average rates makes a rate integrator
% recover the same counts while preserving the 40-output contract.
trapRadiativeQuantumYield = 0.05;
trapRadiativeRate = trapRadiativeQuantumYield*trapDecayRate;
R = [generationRate,secondExcitonGeneration,0,0; ...
     0,radiativeRate,2*radiativeRate,trapRadiativeRate; ...
     0,0,0,trapRadiativeRate];
if timeStep_s > 0
    augmentedGenerator = [Q,zeros(4,3);R,zeros(3,3)];
    augmentedNext = expm(timeStep_s*augmentedGenerator)*[p;zeros(3,1)];
    rawPNext = augmentedNext(1:4);
    integratedRewards = max(augmentedNext(5:7),0);
else
    rawPNext = p;
    integratedRewards = zeros(3,1);
end
probabilityResidual = abs(sum(rawPNext)-1)+sum(max(-rawPNext,0));
pNext = max(rawPNext,0);
pNext = pNext/max(sum(pNext),realmin);
% Warn only when a populated state changes too quickly for output-rate
% integration; a fast but completely unoccupied channel is not a problem.
activeRateScale = max((-diag(Q)).*max(p,pNext));
if activeRateScale*timeStep_s > 0.25
    flags = bitor(flags,uint32(262144));
end
if probabilityResidual > 1.0e-8
    flags = bitor(flags,uint32(1024));
end

instantaneousAbsorptionRate = generationRate*pNext(1)+ ...
    secondExcitonGeneration*pNext(2);
instantaneousTrappedPhotonRate = trapRadiativeRate*pNext(4);
instantaneousPLPhotonRate = radiativeRate*pNext(2)+ ...
    2*radiativeRate*pNext(3)+instantaneousTrappedPhotonRate;
if timeStep_s > 0
    absorptionEventRate = integratedRewards(1)/timeStep_s;
    plPhotonRate = integratedRewards(2)/timeStep_s;
    trappedPhotonRate = integratedRewards(3)/timeStep_s;
else
    absorptionEventRate = instantaneousAbsorptionRate;
    plPhotonRate = instantaneousPLPhotonRate;
    trappedPhotonRate = instantaneousTrappedPhotonRate;
end
totalExcitedLoss = singleExcitonDecay*pNext(2)+biexcitonDecay*pNext(3)+ ...
    trapDecayRate*pNext(4);
if totalExcitedLoss > 1.0e-30
    internalQY = min(1,max(0,plPhotonRate/totalExcitedLoss));
else
    internalQY = radiativeRate/max(radiativeRate+nonradiativeRate+trapCaptureRate,realmin);
end
effectiveLifetime_ns = 1.0e9/max(radiativeRate+nonradiativeRate+trapCaptureRate,realmin);

% One-step inverse-design recommendation using a bounded local sensitivity.
targetError_eV = 0;
suggestedRadius_nm = radius_nm;
if targetEnergy_eV > 0
    targetError_eV = stat(9)-targetEnergy_eV;
    deltaR = max(0.01,0.01*radius_nm);
    rMinus = max(0.5,radius_nm-deltaR);
    rPlus = min(50,radius_nm+deltaR);
    sMinus = localStaticModel(rMinus,temperature_K,field_kVcm,strain_pct, ...
        shell_nm,epsOut,electronBarrier_eV,holeBarrier_eV,materialID, ...
        stokesShiftOverride_eV);
    sPlus = localStaticModel(rPlus,temperature_K,field_kVcm,strain_pct, ...
        shell_nm,epsOut,electronBarrier_eV,holeBarrier_eV,materialID, ...
        stokesShiftOverride_eV);
    sensitivity = (sPlus(9)-sMinus(9))/max(rPlus-rMinus,1.0e-9);
    if abs(sensitivity) > 1.0e-8
        radiusStep = -0.70*targetError_eV/sensitivity;
        radiusStep = min(max(radiusStep,-0.25*radius_nm),0.25*radius_nm);
        suggestedRadius_nm = min(50,max(0.5,radius_nm+radiusStep));
    else
        flags = bitor(flags,uint32(4096));
    end
end

modelConfidence = stat(17);
if flags ~= 0
    modelConfidence = modelConfidence*0.92;
end

% Stable, documented 40-element output contract.
y(1) = stat(1);
y(2) = stat(2);
y(3) = stat(3);
y(4) = stat(4);
y(5) = stat(5);
y(6) = stat(6);
y(7) = stat(7);
y(8) = stat(8);
y(9) = stat(9);
y(10) = stat(10);
y(11) = stat(11);
y(12) = absorptionCrossSection_m2;
y(13) = generationRate;
y(14) = radiativeRate;
y(15) = nonradiativeRate;
y(16) = augerRate;
y(17) = trapCaptureRate;
y(18) = stat(13);
y(19) = stat(14);
y(20:23) = pNext;
y(24) = pNext(2)+2*pNext(3)+pNext(4);
y(25) = plPhotonRate;
y(26) = internalQY;
y(27) = effectiveLifetime_ns;
y(28) = suggestedRadius_nm;
y(29) = targetError_eV;
y(30) = min(1,max(0,modelConfidence));
y(31) = double(flags);
y(32) = stat(15);
y(33) = stat(16);
y(34) = probabilityResidual;
y(35) = stat(18);
y(36) = phononOccupation;
y(37) = thermalEscapeRate;
y(38) = absorptionEventRate;
y(39) = trappedPhotonRate;
y(40) = 1; % finite-barrier analytic tier
if materialID >= 2 && materialID <= 4
    y(40) = 2; % empirical optical anchor plus mechanistic perturbation tier
end
end

function [s,flags] = localStaticModel(radius_nm,temperature_K,field_kVcm, ...
    strain_pct,shell_nm,epsOut,electronBarrier_eV,holeBarrier_eV,materialID, ...
    stokesShiftOverride_eV)
% Hybrid published-reference baseline plus input-dependent mechanistic delta.

[s,flags] = localMechanisticStatic(radius_nm,temperature_K,field_kVcm, ...
    strain_pct,shell_nm,epsOut,electronBarrier_eV,holeBarrier_eV,materialID, ...
    stokesShiftOverride_eV);
if materialID < 2 || materialID > 4
    return
end

material = qdMaterialVector(materialID);
referenceTemperature_K = 300;
if materialID == 4
    % The empirical reference already includes the measured near-ambient
    % CsPbBr3 temperature slope, so cancel only the non-temperature
    % mechanistic terms at the current temperature.
    referenceTemperature_K = temperature_K;
end
[mechanisticReference,~] = localMechanisticStatic(radius_nm, ...
    referenceTemperature_K,0,0,0,2.25,material(9),material(10), ...
    materialID,0);
[empiricalAbsorption_eV,~,empiricalStokes_eV,sourceSize_nm] = ...
    qdEmpiricalMaterialReference(materialID,radius_nm,temperature_K);
mechanisticDelta_eV = s(8)-mechanisticReference(8);
s(8) = max(0.01,empiricalAbsorption_eV+mechanisticDelta_eV);
if stokesShiftOverride_eV > 0
    s(18) = stokesShiftOverride_eV;
else
    s(18) = empiricalStokes_eV;
end
s(9) = max(0.01,s(8)-s(18));
s(10) = 1239.841984332/s(9);

zeroFieldStrain = abs(field_kVcm) <= 1.0e-12 && abs(strain_pct) <= 1.0e-12;
referenceBoundary = abs(epsOut-2.25) <= 1.0e-9 && ...
    abs(electronBarrier_eV-material(9)) <= 1.0e-9 && ...
    abs(holeBarrier_eV-material(10)) <= 1.0e-9;
ambient = temperature_K >= 293 && temperature_K <= 303;
opticalInScope = false;
plInScope = false;
shellGeometryInScope = false;
kineticsInScope = false;
if materialID == 2
    volume_nm3 = (4.0/3.0)*pi*radius_nm^3;
    shellGeometryInScope = shell_nm <= 0.05;
    opticalInScope = volume_nm3 >= 1.0-1.0e-9 && ...
        volume_nm3 <= 10.0+1.0e-9 && ...
        ambient && shellGeometryInScope && zeroFieldStrain && referenceBoundary;
    plInScope = opticalInScope && stokesShiftOverride_eV > 0;
elseif materialID == 3
    diameter_nm = sourceSize_nm;
    bareCore = shell_nm <= 0.05;
    supportedCoreShell = diameter_nm >= 3.9 && diameter_nm <= 5.8 && ...
        shell_nm >= 0.5 && shell_nm <= 1.25;
    shellGeometryInScope = bareCore || supportedCoreShell;
    opticalInScope = diameter_nm >= 3.9-1.0e-9 && ...
        diameter_nm <= 13.3+1.0e-9 && ...
        ambient && shellGeometryInScope && zeroFieldStrain && referenceBoundary;
    plInScope = opticalInScope && stokesShiftOverride_eV > 0;
elseif materialID == 4
    shellGeometryInScope = shell_nm <= 0.05;
    temperatureInScope = temperature_K >= 250 && temperature_K <= 300;
    opticalInScope = sourceSize_nm >= 3.0-1.0e-9 && ...
        sourceSize_nm <= 12.8+1.0e-9 && ...
        temperatureInScope && shellGeometryInScope && zeroFieldStrain && ...
        referenceBoundary;
    % A measured Stokes shift cannot validate an absorption/PL baseline that
    % is itself outside the source size/temperature/geometry envelope.
    plInScope = opticalInScope;
    kineticsInScope = opticalInScope && ambient && ...
        s(9) >= 2.445466802 && s(9) <= 2.654928626;
end

if ~opticalInScope
    flags = bitor(flags,uint32(2097152));
    s(17) = s(17)*0.60;
end
if ~plInScope
    flags = bitor(flags,uint32(4194304));
    s(17) = s(17)*0.82;
end
if ~shellGeometryInScope
    flags = bitor(flags,uint32(8388608));
    s(17) = s(17)*0.75;
end
if (materialID == 2 || materialID == 3) || ...
        (materialID == 4 && ~kineticsInScope)
    flags = bitor(flags,uint32(16777216));
    s(17) = s(17)*0.85;
end
end

function [s,flags] = localMechanisticStatic(radius_nm,temperature_K,field_kVcm, ...
    strain_pct,shell_nm,epsOut,electronBarrier_eV,holeBarrier_eV,materialID, ...
    stokesShiftOverride_eV)
% Static electronic structure and optical terms. Numeric-only for codegen.

hbar = 1.054571817e-34;
electronCharge = 1.602176634e-19;
epsilon0 = 8.8541878128e-12;
hc_eVnm = 1239.841984332;
ke = 1/(4*pi*epsilon0);

flags = uint32(0);
material = qdMaterialVector(materialID);
strain = strain_pct/100;
radius_m = radius_nm*1.0e-9*(1+strain/3);
radius_m = max(radius_m,0.25e-9);
shell_m = max(shell_nm,0)*1.0e-9;

bulkGap = material(1)-material(2)*temperature_K^2/max(temperature_K+material(3),realmin);
bulkGap = max(bulkGap,0.01);
strainShift = material(8)*strain;

[electronEnergy,~,kappaE,residualE,boundE,zE] = localFiniteWell( ...
    radius_m,material(4),material(11),electronBarrier_eV);
[holeEnergy,~,kappaH,residualH,boundH,zH] = localFiniteWell( ...
    radius_m,material(5),material(12),holeBarrier_eV);
if ~boundE
    flags = bitor(flags,uint32(16));
end
if ~boundH
    flags = bitor(flags,uint32(32));
end

leakageOverlap = localRadialOverlapSquared(radius_m,zE,kappaE,boundE, ...
    zH,kappaH,boundH);
excitonBinding = 1.786*ke*electronCharge^2/(material(6)*radius_m)/electronCharge;
excitonBinding = excitonBinding*leakageOverlap;

polarizationShift = 0.25*ke*electronCharge^2/radius_m/electronCharge* ...
    (1/max(epsOut,1)-1/material(6))*(0.5+0.5*leakageOverlap);
polarizationShift = min(0.30,max(-0.30,polarizationShift));

field_Vm = field_kVcm*1.0e5;
% Local-field correction for a dielectric sphere in a uniform external field.
internalFieldFactor = 3*epsOut/(material(6)+2*epsOut);
fieldCore_Vm = internalFieldFactor*field_Vm;
polarizabilityVolume = 0.5*material(6)*radius_m^3;
polarizabilitySI = 4*pi*epsilon0*polarizabilityVolume;
starkShift = -0.5*polarizabilitySI*fieldCore_Vm^2/electronCharge;

fieldEnergy_eV = abs(fieldCore_Vm)*radius_m;
weakFieldScale = max(0.1*min(electronBarrier_eV,holeBarrier_eV),0.02);
fieldMixing = min(30,fieldEnergy_eV/weakFieldScale);
overlap = leakageOverlap*exp(-0.05*fieldMixing^2);

absorptionEnergy = bulkGap+strainShift+electronEnergy+holeEnergy- ...
    excitonBinding+polarizationShift+starkShift;
absorptionEnergy = max(absorptionEnergy,0.01);
stokesShift = material(21);
if stokesShiftOverride_eV > 0
    stokesShift = stokesShiftOverride_eV;
end
plEnergy = max(0.01,absorptionEnergy-stokesShift);
emissionWavelength = hc_eVnm/plEnergy;

% material(17) is the measured/calibrated far-above-gap cross section at
% 350 nm and R=3 nm. Do not multiply it by the band-edge leakage proxy.
absorptionCrossSection = material(17)*(radius_nm/3.0)^3;
electronAttemptFrequency = electronEnergy*electronCharge/hbar;
holeAttemptFrequency = holeEnergy*electronCharge/hbar;
if shell_m <= 0
    tunnelingRate = electronAttemptFrequency+holeAttemptFrequency;
else
    tunnelingRate = electronAttemptFrequency* ...
        exp(-min(700,2*kappaE*shell_m))+holeAttemptFrequency* ...
        exp(-min(700,2*kappaH*shell_m));
end
chargingEnergy = electronCharge/(8*pi*epsilon0*max(epsOut,1)*radius_m);

confidence = material(22);
if radius_nm < max(1.5,2*material(20))
    flags = bitor(flags,uint32(64));
    confidence = confidence*0.45;
end
if radius_nm > 2*material(19)
    flags = bitor(flags,uint32(128));
    confidence = confidence*0.65;
end
if fieldEnergy_eV > weakFieldScale
    flags = bitor(flags,uint32(4));
    confidence = confidence*0.60;
end
if abs(strain_pct) > 3
    flags = bitor(flags,uint32(8));
    confidence = confidence*0.65;
end
if ~boundE || ~boundH
    confidence = confidence*0.25;
end
if materialID == 5 && (radius_nm < 1.5 || radius_nm > 4.0 || ...
        temperature_K < 250 || temperature_K > 350 || ...
        abs(field_kVcm) > 1.0e-12 || abs(strain_pct) > 1.0e-12 || ...
        shell_nm > 0.05 || abs(epsOut-2.25) > 0.50 || ...
        abs(electronBarrier_eV-material(9)) > 1.0e-9 || ...
        abs(holeBarrier_eV-material(10)) > 1.0e-9)
    flags = bitor(flags,uint32(524288));
    confidence = confidence*0.60;
end

% Layout used by the public output assembly.
s = zeros(18,1);
s(1) = bulkGap;
s(2) = electronEnergy;
s(3) = holeEnergy;
s(4) = excitonBinding;
s(5) = polarizationShift;
s(6) = starkShift;
s(7) = strainShift;
s(8) = absorptionEnergy;
s(9) = plEnergy;
s(10) = emissionWavelength;
s(11) = overlap;
s(12) = absorptionCrossSection;
s(13) = tunnelingRate;
s(14) = chargingEnergy;
s(15) = residualE;
s(16) = residualH;
s(17) = confidence;
s(18) = stokesShift;
end

function [energy_eV,pInside,kappa,residual,isBound,z] = localFiniteWell( ...
    radius_m,massInside_m0,massOutside_m0,barrier_eV)
% Lowest l=0 finite spherical well with BenDaniel-Duke matching.

hbar = 1.054571817e-34;
electronCharge = 1.602176634e-19;
electronMass = 9.1093837015e-31;

massInside = massInside_m0*electronMass;
massOutside = massOutside_m0*electronMass;
rho = radius_m*sqrt(2*massInside*barrier_eV*electronCharge)/hbar;
zLow = 1.0e-8;
zHigh = min(pi-1.0e-8,rho*(1-1.0e-10));
isBound = false;
residual = 1.0e6;

if zHigh > zLow
    fLow = localBoundaryEquation(zLow,rho,massInside_m0,massOutside_m0);
    fHigh = localBoundaryEquation(zHigh,rho,massInside_m0,massOutside_m0);
    bracketLow = zLow;
    bracketHigh = zHigh;
    found = isfinite(fLow) && isfinite(fHigh) && fLow*fHigh <= 0;

    if ~found
        previousZ = zLow;
        previousF = fLow;
        for scanIndex = 1:512
            testZ = zLow+(zHigh-zLow)*scanIndex/512;
            testF = localBoundaryEquation(testZ,rho,massInside_m0,massOutside_m0);
            if isfinite(previousF) && isfinite(testF) && previousF*testF <= 0
                bracketLow = previousZ;
                bracketHigh = testZ;
                fLow = previousF;
                found = true;
                break
            end
            previousZ = testZ;
            previousF = testF;
        end
    end

    if found
        for iteration = 1:80
            zMiddle = 0.5*(bracketLow+bracketHigh);
            fMiddle = localBoundaryEquation(zMiddle,rho,massInside_m0,massOutside_m0);
            if fLow*fMiddle <= 0
                bracketHigh = zMiddle;
            else
                bracketLow = zMiddle;
                fLow = fMiddle;
            end
        end
        z = 0.5*(bracketLow+bracketHigh);
        residual = abs(localBoundaryEquation(z,rho,massInside_m0,massOutside_m0));
        isBound = true;
    else
        z = rho;
    end
else
    z = rho;
end

if isBound
    energy_eV = hbar^2*z^2/(2*massInside*radius_m^2)/electronCharge;
else
    % No normalized discrete state exists. Return the continuum threshold
    % and zero localization; the caller sets the explicit unbound flag.
    energy_eV = max(barrier_eV,0);
end
kappa = sqrt(max(0,2*massOutside*(barrier_eV-energy_eV)*electronCharge))/hbar;
if isBound
    k = z/radius_m;
    insideNorm = radius_m/2-sin(2*z)/(4*k);
    outsideNorm = sin(z)^2/max(2*kappa,realmin);
    pInside = insideNorm/max(insideNorm+outsideNorm,realmin);
    pInside = min(1,max(0,pInside));
else
    pInside = 0;
end
end

function overlapSquared = localRadialOverlapSquared(radius_m,zE,kappaE, ...
    boundE,zH,kappaH,boundH)
% Exact overlap of the two normalized l=0 two-region radial states.
if ~boundE || ~boundH
    overlapSquared = 0;
    return
end
kE = zE/radius_m;
kH = zH/radius_m;
normE = radius_m/2-sin(2*zE)/(4*kE)+ ...
    sin(zE)^2/max(2*kappaE,realmin);
normH = radius_m/2-sin(2*zH)/(4*kH)+ ...
    sin(zH)^2/max(2*kappaH,realmin);
deltaK = kE-kH;
sumK = kE+kH;
if abs(deltaK*radius_m) < 1.0e-7
    insideOverlap = radius_m/2-sin(2*zE)/(4*kE);
else
    insideOverlap = sin(deltaK*radius_m)/(2*deltaK)- ...
        sin(sumK*radius_m)/(2*sumK);
end
outsideOverlap = sin(zE)*sin(zH)/max(kappaE+kappaH,realmin);
amplitudeOverlap = (insideOverlap+outsideOverlap)/ ...
    sqrt(max(normE*normH,realmin));
overlapSquared = min(1,max(0,amplitudeOverlap^2));
end

function f = localBoundaryEquation(z,rho,massInside_m0,massOutside_m0)
% Dimensionless BenDaniel-Duke boundary residual for radial psi(r).
remaining = max(rho^2-z^2,0);
kappaR = sqrt(remaining*massOutside_m0/massInside_m0);
if abs(z) < 1.0e-4
    zCotMinusOne = -z^2/3-z^4/45-2*z^6/945;
else
    zCotMinusOne = z*cos(z)/sin(z)-1;
end
f = zCotMinusOne/massInside_m0-(-kappaR-1)/massOutside_m0;
end
