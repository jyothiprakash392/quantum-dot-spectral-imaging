function report = runMultiMaterialCalibrationTests()
%RUNMULTIMATERIALCALIBRATIONTESTS Source regression and held-out tests IDs 2-4.

rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
tests = cell(0,1);
comparisonMaterial = cell(0,1);
comparisonObservable = cell(0,1);
comparisonSize_nm = zeros(0,1);
comparisonReference_eV = zeros(0,1);
comparisonPrediction_eV = zeros(0,1);

assert(numel(qdInputNames()) == 14);
assert(numel(qdOutputNames()) == 40);
for materialID = 2:4
    material = qdMaterialDatabase(materialID);
    assert(material.id == materialID);
    assert(~contains(material.status,'preliminary'));
end
tests{end+1} = 'Stable 14-input/40-output contract and calibrated material metadata';

% Almeida 2023 volume equation for approximately tetrahedral InP cores.
inPVolume_nm3 = [1;2;4;6;8;10];
inPEdge_nm = (6*sqrt(2)*inPVolume_nm3).^(1/3);
inPReference_eV = 1.33+1.219*inPVolume_nm3.^(-0.251);
inPPrediction_eV = zeros(size(inPReference_eV));
for k = 1:numel(inPEdge_nm)
    inputs = qdCalibratedMaterialInputs(2,inPEdge_nm(k));
    result = simulateQD(inputs,'Duration_ns',0);
    inPPrediction_eV(k) = result.absorptionEnergy_eV;
    localAssertClose(inPPrediction_eV(k),inPReference_eV(k),0,2e-12);
    assert(result.calibration.opticalInScope);
    assert(result.modelTier == 2);
    assert(bitand(uint32(result.validityFlags),uint32(256)) == 0);
end
assert(all(diff(inPPrediction_eV) < 0));
tests{end+1} = 'InP 2023 volume-law regression and monotonicity';
comparisonMaterial = [comparisonMaterial;repmat({'ID2 InP'},numel(inPEdge_nm),1)];
comparisonObservable = [comparisonObservable;repmat({'absorption'},numel(inPEdge_nm),1)];
comparisonSize_nm = [comparisonSize_nm;inPEdge_nm];
comparisonReference_eV = [comparisonReference_eV;inPReference_eV];
comparisonPrediction_eV = [comparisonPrediction_eV;inPPrediction_eV];

inPScope = qdCalibratedMaterialInputs(2,inPEdge_nm(3));
inPNoPL = simulateQD(inPScope,'Duration_ns',0);
assert(~inPNoPL.calibration.plInScope);
assert(bitand(uint32(inPNoPL.validityFlags),uint32(4194304)) ~= 0);
assert(bitand(uint32(inPNoPL.validityFlags),uint32(16777216)) ~= 0);
inPScope.stokesShiftOverride_eV = 0.075;
inPMeasuredPL = simulateQD(inPScope,'Duration_ns',0);
assert(inPMeasuredPL.calibration.plInScope);
assert(bitand(uint32(inPMeasuredPL.validityFlags),uint32(4194304)) == 0);
localAssertClose(inPMeasuredPL.plEnergy_eV, ...
    inPMeasuredPL.absorptionEnergy_eV-0.075,0,2e-12);
inPScope.shellThickness_nm = 0.5;
inPShell = simulateQD(inPScope,'Duration_ns',0);
assert(~inPShell.calibration.opticalInScope);
assert(bitand(uint32(inPShell.validityFlags),uint32(8388608)) ~= 0);
tests{end+1} = 'InP observable-specific PL and unsupported-ZnSe-shell flags';

% External InP/ZnSe sample. Its spherical/core-shell geometry is not
% equivalent to the tetrahedral core calibration, so this is deliberately
% scored as an out-of-scope limitation rather than used for fitting.
inPHoldoutInputs = qdDefaultInputs();
inPHoldoutInputs.materialID = 2;
inPHoldoutInputs.radius_nm = 2.9/2;
inPHoldoutInputs.temperature_K = 300;
inPHoldoutInputs.electricField_kVcm = 0;
inPHoldoutInputs.hydrostaticStrain_pct = 0;
inPHoldoutInputs.pumpIntensity_Wcm2 = 0;
inPHoldoutInputs.shellThickness_nm = (9.6-2.9)/2;
inPHoldoutInputs.surfaceTrapDensity_cm2 = 0;
inPHoldoutInputs.environmentDielectric = 2.25;
inPHoldoutInputs.electronBarrier_eV = 0;
inPHoldoutInputs.holeBarrier_eV = 0;
inPHoldoutInputs.targetEmission_eV = 0;
inPHoldout = simulateQD(inPHoldoutInputs,'Duration_ns',0);
inPHoldoutAbsError_eV = inPHoldout.absorptionEnergy_eV-2.18;
inPHoldoutPLError_eV = inPHoldout.plEnergy_eV-2.03;
localAssertClose(inPHoldoutAbsError_eV,-0.206795078157,0,5e-13);
localAssertClose(inPHoldoutPLError_eV,-0.096795078157,0,5e-13);
assert(bitand(uint32(inPHoldout.validityFlags),uint32(2097152)) ~= 0);
assert(bitand(uint32(inPHoldout.validityFlags),uint32(8388608)) ~= 0);
tests{end+1} = 'InP/ZnSe external geometry-mismatched limitation check and flags';
comparisonMaterial = [comparisonMaterial;{'ID2 InP/ZnSe out-of-scope'}; ...
    {'ID2 InP/ZnSe out-of-scope'}];
comparisonObservable = [comparisonObservable;{'absorption'};{'PL'}];
comparisonSize_nm = [comparisonSize_nm;2.9;2.9];
comparisonReference_eV = [comparisonReference_eV;2.18;2.03];
comparisonPrediction_eV = [comparisonPrediction_eV; ...
    inPHoldout.absorptionEnergy_eV;inPHoldout.plEnergy_eV];

% Moreels 2009 PbS nonparabolic first-exciton sizing relation.
pbSDiameter_nm = [3.9;5.7;6.0;13.3];
pbSReference_eV = 0.410+1./(0.0252*pbSDiameter_nm.^2+0.283*pbSDiameter_nm);
pbSPrediction_eV = zeros(size(pbSReference_eV));
for k = 1:numel(pbSDiameter_nm)
    inputs = qdCalibratedMaterialInputs(3,pbSDiameter_nm(k));
    result = simulateQD(inputs,'Duration_ns',0);
    pbSPrediction_eV(k) = result.absorptionEnergy_eV;
    localAssertClose(pbSPrediction_eV(k),pbSReference_eV(k),0,2e-12);
    recoveredDiameter_nm = (-0.283+sqrt(0.283^2+ ...
        4*0.0252/(result.absorptionEnergy_eV-0.410)))/(2*0.0252);
    localAssertClose(recoveredDiameter_nm,pbSDiameter_nm(k),0,2e-11);
end
assert(all(diff(pbSPrediction_eV) < 0));
tests{end+1} = 'PbS 2009 sizing-law regression, inverse round-trip, and monotonicity';
comparisonMaterial = [comparisonMaterial;repmat({'ID3 PbS/CdS'},numel(pbSDiameter_nm),1)];
comparisonObservable = [comparisonObservable;repmat({'absorption'},numel(pbSDiameter_nm),1)];
comparisonSize_nm = [comparisonSize_nm;pbSDiameter_nm];
comparisonReference_eV = [comparisonReference_eV;pbSReference_eV];
comparisonPrediction_eV = [comparisonPrediction_eV;pbSPrediction_eV];

pbSShellInputs = qdCalibratedMaterialInputs(3,5.5);
pbSShellInputs.shellThickness_nm = 0.58;
pbSShell = simulateQD(pbSShellInputs,'Duration_ns',0);
assert(pbSShell.calibration.opticalInScope);
pbSUnsupportedInputs = qdCalibratedMaterialInputs(3,6.0);
pbSUnsupportedInputs.shellThickness_nm = 1.0;
pbSUnsupported = simulateQD(pbSUnsupportedInputs,'Duration_ns',0);
assert(~pbSUnsupported.calibration.opticalInScope);
assert(bitand(uint32(pbSUnsupported.validityFlags),uint32(8388608)) ~= 0);
assert(~pbSShell.calibration.plInScope && ~pbSShell.calibration.kineticsInScope);
tests{end+1} = 'PbS/CdS cation-exchange transfer scope and PL/kinetic cautions';

% The external thick-shell single-emitter series tests omitted
% quasi-type-II physics, not a calibration target for the core absorption law.
pbSThickCore_nm = [4.8;3.7;2.6];
pbSThickShell_nm = [0.94;1.40;1.88];
pbSThickPLReference_eV = [0.91;1.04;1.27];
pbSThickOverlapReference = [0.97;0.89;0.72];
pbSThickPLPrediction_eV = zeros(3,1);
pbSThickOverlapPrediction = zeros(3,1);
for k = 1:3
    thickInputs = qdDefaultInputs();
    thickInputs.materialID = 3;
    thickInputs.radius_nm = pbSThickCore_nm(k)/2;
    thickInputs.temperature_K = 300;
    thickInputs.electricField_kVcm = 0;
    thickInputs.hydrostaticStrain_pct = 0;
    thickInputs.pumpIntensity_Wcm2 = 0;
    thickInputs.shellThickness_nm = pbSThickShell_nm(k);
    thickInputs.surfaceTrapDensity_cm2 = 0;
    thickInputs.environmentDielectric = 2.25;
    thickInputs.electronBarrier_eV = 0;
    thickInputs.holeBarrier_eV = 0;
    thickInputs.targetEmission_eV = 0;
    thickResult = simulateQD(thickInputs,'Duration_ns',0);
    pbSThickPLPrediction_eV(k) = thickResult.plEnergy_eV;
    pbSThickOverlapPrediction(k) = thickResult.electronHoleOverlap;
    assert(bitand(uint32(thickResult.validityFlags),uint32(4194304)) ~= 0);
end
pbSThickPLRMSE_eV = localRMSE( ...
    pbSThickPLPrediction_eV-pbSThickPLReference_eV);
pbSThickOverlapRMSE = localRMSE( ...
    pbSThickOverlapPrediction-pbSThickOverlapReference);
localAssertClose(pbSThickPLRMSE_eV,0.134996078,0,5e-10);
localAssertClose(pbSThickOverlapRMSE,0.174547032821,0,5e-13);
tests{end+1} = 'PbS/CdS external thick-shell PL/overlap limitation score';
comparisonMaterial = [comparisonMaterial; ...
    repmat({'ID3 PbS/CdS external thick-shell comparison'},3,1)];
comparisonObservable = [comparisonObservable;repmat({'PL'},3,1)];
comparisonSize_nm = [comparisonSize_nm;pbSThickCore_nm];
comparisonReference_eV = [comparisonReference_eV;pbSThickPLReference_eV];
comparisonPrediction_eV = [comparisonPrediction_eV;pbSThickPLPrediction_eV];

% Stylianou 2026 PbS/CdS cation-exchange series: fit biexciton
% Auger lifetime, holding out each complete synthesis series in turn.
pbSAugerReference = qdPbSCdSReferenceData();
pbSAugerX = [ones(13,1),pbSAugerReference.OuterDiameter_nm, ...
    pbSAugerReference.CdSShellThickness_nm, ...
    pbSAugerReference.OuterDiameter_nm.* ...
    pbSAugerReference.CdSShellThickness_nm];
pbSAugerCoefficients = pbSAugerX\pbSAugerReference.AugerLifetime_ps;
expectedPbSAugerCoefficients = [-36.9957696542972;28.4309299423043; ...
    813.382931876789;-84.7825604665947];
localAssertClose(max(abs(pbSAugerCoefficients- ...
    expectedPbSAugerCoefficients)),0,0,5e-11);
pbSAugerPrediction_ps = zeros(13,1);
pbSAugerLOSO_ps = zeros(13,1);
pbSAugerGeneric_ps = 200*(pbSAugerReference.PbSCoreDiameter_nm/6).^3.* ...
    exp(pbSAugerReference.CdSShellThickness_nm/8);
for k = 1:13
    [augerRate_Hz,augerLifetime_ps,geometryInScope] = qdPbSCdSAugerModel( ...
        pbSAugerReference.PbSCoreDiameter_nm(k), ...
        pbSAugerReference.CdSShellThickness_nm(k));
    assert(geometryInScope);
    pbSAugerPrediction_ps(k) = augerLifetime_ps;
    localAssertClose(augerRate_Hz,1e12/augerLifetime_ps,0,1e-5);

    augerInputs = qdDefaultInputs();
    augerInputs.materialID = 3;
    augerInputs.radius_nm = pbSAugerReference.PbSCoreDiameter_nm(k)/2;
    augerInputs.temperature_K = 300;
    augerInputs.electricField_kVcm = 0;
    augerInputs.hydrostaticStrain_pct = 0;
    augerInputs.pumpIntensity_Wcm2 = 0;
    augerInputs.shellThickness_nm = ...
        pbSAugerReference.CdSShellThickness_nm(k);
    augerInputs.surfaceTrapDensity_cm2 = 0;
    augerInputs.environmentDielectric = 2.25;
    augerInputs.electronBarrier_eV = 0;
    augerInputs.holeBarrier_eV = 0;
    augerResult = simulateQD(augerInputs,'Duration_ns',0);
    localAssertClose(augerResult.augerRate_Hz,augerRate_Hz,0,2e-5);
    localAssertClose(augerResult.biexcitonAugerLifetime_ps, ...
        augerLifetime_ps,0,2e-12);
    assert(augerResult.calibration.augerInScope);
    assert(~augerResult.calibration.kineticsInScope);
end
for seriesID = 1:3
    isSeriesHoldout = pbSAugerReference.Series == seriesID;
    seriesCoefficients = pbSAugerX(~isSeriesHoldout,:)\ ...
        pbSAugerReference.AugerLifetime_ps(~isSeriesHoldout);
    pbSAugerLOSO_ps(isSeriesHoldout) = ...
        pbSAugerX(isSeriesHoldout,:)*seriesCoefficients;
end
pbSAugerFullFitRMSE_ps = localRMSE( ...
    pbSAugerPrediction_ps-pbSAugerReference.AugerLifetime_ps);
pbSAugerLOSORMSE_ps = localRMSE( ...
    pbSAugerLOSO_ps-pbSAugerReference.AugerLifetime_ps);
pbSAugerGenericRMSE_ps = localRMSE( ...
    pbSAugerGeneric_ps-pbSAugerReference.AugerLifetime_ps);
localAssertClose(pbSAugerFullFitRMSE_ps,6.86430152498389,0,2e-11);
localAssertClose(pbSAugerLOSORMSE_ps,8.94628287305148,0,2e-11);
localAssertClose(pbSAugerGenericRMSE_ps,100.687978271488,0,2e-10);
assert(pbSAugerLOSORMSE_ps < 0.10*pbSAugerGenericRMSE_ps);
[~,~,outsideAugerGeometry] = qdPbSCdSAugerModel(5.32,0.84);
assert(~outsideAugerGeometry);
tests{end+1} = ['PbS/CdS 13-row Auger learner, whole-series CV, convex ' ...
    'scope, and physics-engine propagation'];

% Brennan 2017 primary SI checkpoints: nanocube edge, absorption, and PL.
csEdge_nm = [3.0;4.1;4.5;5.5;6.2;6.8;7.9;9.2;11.7;12.8];
csAbsReference_eV = [2.853;2.711;2.670;2.599;2.554; ...
    2.530;2.476;2.462;2.455;2.415];
csPLReference_eV = [2.739;2.618;2.587;2.525;2.496; ...
    2.480;2.427;2.422;2.420;2.398];
csAbsPrediction_eV = zeros(size(csEdge_nm));
csPLPrediction_eV = zeros(size(csEdge_nm));
for k = 1:numel(csEdge_nm)
    inputs = qdCalibratedMaterialInputs(4,csEdge_nm(k));
    result = simulateQD(inputs,'Duration_ns',0);
    csAbsPrediction_eV(k) = result.absorptionEnergy_eV;
    csPLPrediction_eV(k) = result.plEnergy_eV;
    localAssertClose(csAbsPrediction_eV(k),csAbsReference_eV(k),0,3e-12);
    localAssertClose(csPLPrediction_eV(k),csPLReference_eV(k),0,3e-12);
    localAssertClose(result.lambda2_nm,1239.841984332/csPLReference_eV(k),0,2e-10);
    assert(result.calibration.opticalInScope && result.calibration.plInScope);
end
assert(all(diff(csAbsPrediction_eV) < 0));
assert(all(diff(csPLPrediction_eV) < 0));
tests{end+1} = 'CsPbBr3 2017 absorption/PL/Stokes table regression and lambda2';
comparisonMaterial = [comparisonMaterial;repmat({'ID4 CsPbBr3'},2*numel(csEdge_nm),1)];
comparisonObservable = [comparisonObservable;repmat({'absorption'},numel(csEdge_nm),1); ...
    repmat({'PL'},numel(csEdge_nm),1)];
comparisonSize_nm = [comparisonSize_nm;csEdge_nm;csEdge_nm];
comparisonReference_eV = [comparisonReference_eV;csAbsReference_eV;csPLReference_eV];
comparisonPrediction_eV = [comparisonPrediction_eV;csAbsPrediction_eV;csPLPrediction_eV];

csTemperature = qdCalibratedMaterialInputs(4,8.0);
csAt300 = simulateQD(csTemperature,'Duration_ns',0);
csTemperature.temperature_K = 250;
csAt250 = simulateQD(csTemperature,'Duration_ns',0);
localAssertClose(csAt300.plEnergy_eV-csAt250.plEnergy_eV, ...
    2.24e-4*50,0,2e-12);
assert(csAt250.calibration.opticalInScope);
csTemperature.temperature_K = 270;
csAt270 = simulateQD(csTemperature,'Duration_ns',0);
assert(csAt270.calibration.opticalInScope);
assert(~csAt270.calibration.kineticsInScope);
assert(bitand(uint32(csAt270.validityFlags),uint32(16777216)) ~= 0);
csTemperature.temperature_K = 301;
csAt301 = simulateQD(csTemperature,'Duration_ns',0);
assert(~csAt301.calibration.opticalInScope);
assert(bitand(uint32(csAt301.validityFlags),uint32(2097152)) ~= 0);
csOutOfScope = qdDefaultInputs();
csOutOfScope.materialID = 4;
csOutOfScope.radius_nm = (3/(4*pi))^(1/3)*2.0;
csOutOfScope.temperature_K = 500;
csOutOfScope.shellThickness_nm = 1.0;
csOutOfScope.stokesShiftOverride_eV = 0.080;
csOutOfScope.pumpIntensity_Wcm2 = 0;
csOutOfScopeResult = simulateQD(csOutOfScope,'Duration_ns',0);
assert(~csOutOfScopeResult.calibration.opticalInScope);
assert(~csOutOfScopeResult.calibration.plInScope);
assert(bitand(uint32(csOutOfScopeResult.validityFlags),uint32(4194304)) ~= 0);
tests{end+1} = 'CsPbBr3 measured 250-300 K slope and temperature-envelope flag';

% External 2019 cross-source/protocol comparison (exclude 2.6 nm, outside
% the 2017 baseline scope). This was not a pre-registered held-out batch.
holdoutEdge_nm = [6.2;5.0;4.5;4.3;4.0;3.5;3.0];
holdoutAbs_eV = [2.54;2.57;2.60;2.62;2.67;2.71;2.75];
holdoutPrediction_eV = zeros(size(holdoutAbs_eV));
for k = 1:numel(holdoutEdge_nm)
    holdoutResult = simulateQD(qdCalibratedMaterialInputs(4, ...
        holdoutEdge_nm(k)),'Duration_ns',0);
    holdoutPrediction_eV(k) = holdoutResult.absorptionEnergy_eV;
end
holdoutResidual_eV = holdoutPrediction_eV-holdoutAbs_eV;
independentAbsorptionRMSE_eV = sqrt(mean(holdoutResidual_eV.^2));
independentAbsorptionBias_eV = mean(holdoutResidual_eV);
localAssertClose(independentAbsorptionRMSE_eV,0.0695873611113849,0,2e-13);
localAssertClose(independentAbsorptionBias_eV,0.0649090909090909,0,2e-13);
tests{end+1} = 'CsPbBr3 external cross-source absorption comparison error';
comparisonMaterial = [comparisonMaterial;repmat( ...
    {'ID4 CsPbBr3 external cross-source comparison'}, ...
    numel(holdoutEdge_nm),1)];
comparisonObservable = [comparisonObservable;repmat({'absorption'},numel(holdoutEdge_nm),1)];
comparisonSize_nm = [comparisonSize_nm;holdoutEdge_nm];
comparisonReference_eV = [comparisonReference_eV;holdoutAbs_eV];
comparisonPrediction_eV = [comparisonPrediction_eV;holdoutPrediction_eV];

% External synthesis-protocol PL anchors from Abbas 2025.
protocolEdge_nm = [4.62;5.01;7.45];
protocolPL_eV = [2.654928626;2.561677001;2.450299740];
protocolPrediction_eV = zeros(size(protocolPL_eV));
for k = 1:numel(protocolEdge_nm)
    protocolResult = simulateQD(qdCalibratedMaterialInputs(4, ...
        protocolEdge_nm(k)),'Duration_ns',0);
    protocolPrediction_eV(k) = protocolResult.plEnergy_eV;
end
crossProtocolPLRMSE_eV = sqrt(mean((protocolPrediction_eV-protocolPL_eV).^2));
localAssertClose(crossProtocolPLRMSE_eV,0.0436756975816512,0,2e-13);
tests{end+1} = 'CsPbBr3 external cross-protocol PL-anchor error';
comparisonMaterial = [comparisonMaterial; ...
    repmat({'ID4 CsPbBr3 external PL protocol comparison'}, ...
    numel(protocolEdge_nm),1)];
comparisonObservable = [comparisonObservable; ...
    repmat({'PL'},numel(protocolEdge_nm),1)];
comparisonSize_nm = [comparisonSize_nm;protocolEdge_nm];
comparisonReference_eV = [comparisonReference_eV;protocolPL_eV];
comparisonPrediction_eV = [comparisonPrediction_eV;protocolPrediction_eV];

% Reproduce the deterministic 25-row physics-constrained ridge fit and the
% frozen 9-row energy-grouped evaluation set.
kineticReference = qdCsPbBr3ReferenceData();
uniqueEnergy = unique(kineticReference.PLPeak_eV);
holdoutEnergy = uniqueEnergy([3 7 11 15 19]);
isHoldout = ismember(kineticReference.PLPeak_eV,holdoutEnergy);
assert(isequal(find(isHoldout).',[1 4 11 12 13 19 27 32 34]));
developmentZ = (kineticReference.PLPeak_eV(~isHoldout)-2.52)/0.1;
developmentX = [ones(size(developmentZ)),developmentZ, ...
    developmentZ.^2,developmentZ.^3];
ridgePenalty = diag([0 1 1 1]);
fittedTauCoefficients = (developmentX.'*developmentX+0.1*ridgePenalty)\ ...
    (developmentX.'*kineticReference.TotalLifetime_ns(~isHoldout));
fittedQYCoefficients = (developmentX.'*developmentX+0.1*ridgePenalty)\ ...
    (developmentX.'*(kineticReference.PLQY_percent(~isHoldout)/100));
expectedTauCoefficients = [3.183780018375221;0.25057345676543119; ...
    1.2345240813129643;-0.58043503257099538];
expectedQYCoefficients = [0.94968446323147371;0.056978284696460949; ...
    0.048363733662658483;-0.074033041351858522];
localAssertClose(max(abs(fittedTauCoefficients-expectedTauCoefficients)), ...
    0,0,5e-13);
localAssertClose(max(abs(fittedQYCoefficients-expectedQYCoefficients)), ...
    0,0,5e-13);
nRows = numel(kineticReference.PLPeak_eV);
predKr = zeros(nRows,1);
predKnr = zeros(nRows,1);
predLifetime = zeros(nRows,1);
predPLQY = zeros(nRows,1);
for k = 1:nRows
    [kr_Hz,knr_Hz,tau_ns,qy] = ...
        qdCsPbBr3RateModel(kineticReference.PLPeak_eV(k));
    predKr(k) = kr_Hz/1e9;
    predKnr(k) = knr_Hz/1e9;
    predLifetime(k) = tau_ns;
    predPLQY(k) = 100*qy;
end
kineticMetrics = struct();
kineticMetrics.radiativeRateCalibrationRMSE_nsInv = localRMSE( ...
    predKr(~isHoldout)-kineticReference.RadiativeRate_nsInv(~isHoldout));
kineticMetrics.radiativeRateHoldoutRMSE_nsInv = localRMSE( ...
    predKr(isHoldout)-kineticReference.RadiativeRate_nsInv(isHoldout));
kineticMetrics.nonradiativeRateCalibrationRMSE_nsInv = localRMSE( ...
    predKnr(~isHoldout)-kineticReference.NonradiativeRate_nsInv(~isHoldout));
kineticMetrics.nonradiativeRateHoldoutRMSE_nsInv = localRMSE( ...
    predKnr(isHoldout)-kineticReference.NonradiativeRate_nsInv(isHoldout));
kineticMetrics.totalLifetimeHoldoutRMSE_ns = localRMSE( ...
    predLifetime(isHoldout)-kineticReference.TotalLifetime_ns(isHoldout));
kineticMetrics.radiativeLifetimeHoldoutRMSE_ns = localRMSE( ...
    1./predKr(isHoldout)-kineticReference.RadiativeLifetime_ns(isHoldout));
kineticMetrics.plqyHoldoutRMSE_percentagePoints = localRMSE( ...
    predPLQY(isHoldout)-kineticReference.PLQY_percent(isHoldout));
localAssertClose(kineticMetrics.radiativeRateHoldoutRMSE_nsInv, ...
    0.0145593421577936,0,5e-13);
localAssertClose(kineticMetrics.nonradiativeRateHoldoutRMSE_nsInv, ...
    0.0103094382867921,0,5e-13);
localAssertClose(kineticMetrics.totalLifetimeHoldoutRMSE_ns, ...
    0.0896422531098704,0,5e-12);
localAssertClose(kineticMetrics.radiativeLifetimeHoldoutRMSE_ns, ...
    0.180420528355052,0,5e-12);
localAssertClose(kineticMetrics.plqyHoldoutRMSE_percentagePoints, ...
    3.48660783201446,0,5e-11);
tests{end+1} = ['CsPbBr3 constrained-ML kinetic fit and frozen 9-row ' ...
    'evaluation RMSE reproduction'];

% The deployed learner must remain physical throughout its full declared
% PL-energy envelope, with no reliance on the defensive clamps.
kineticEnergySweep_eV = linspace(2.445466802,2.654928626,10001).';
sweepKr = zeros(size(kineticEnergySweep_eV));
sweepKnr = zeros(size(kineticEnergySweep_eV));
sweepTau = zeros(size(kineticEnergySweep_eV));
sweepQY = zeros(size(kineticEnergySweep_eV));
for k = 1:numel(kineticEnergySweep_eV)
    [sweepKr(k),sweepKnr(k),sweepTau(k),sweepQY(k)] = ...
        qdCsPbBr3RateModel(kineticEnergySweep_eV(k));
end
assert(all(isfinite([sweepKr;sweepKnr;sweepTau;sweepQY])));
assert(all(sweepKr >= 0) && all(sweepKnr >= 0));
assert(all(sweepTau > 0.05) && all(sweepQY > 0) && all(sweepQY < 1));
localAssertClose(max(abs((sweepKr+sweepKnr).*sweepTau/1e9-1)), ...
    0,0,4e-16);
localAssertClose(max(abs(sweepKr./(sweepKr+sweepKnr)-sweepQY)), ...
    0,0,4e-16);
tests{end+1} = 'Constrained-ML kinetic physicality and rate closure on 10,001 points';

csKinetic = qdCalibratedMaterialInputs(4,6.2);
csKineticResult = simulateQD(csKinetic,'Duration_ns',0);
[expectedKr_Hz,expectedKnr_Hz,expectedTau_ns,expectedQY] = ...
    qdCsPbBr3RateModel(csKineticResult.plEnergy_eV);
localAssertClose(csKineticResult.radiativeRate_Hz,expectedKr_Hz,0,1e-5);
localAssertClose(csKineticResult.nonradiativeRate_Hz,expectedKnr_Hz,0,1e-5);
localAssertClose(csKineticResult.effectiveLifetime_ns,expectedTau_ns,0,2e-12);
localAssertClose(csKineticResult.internalQuantumYield,expectedQY,0,2e-12);
assert(csKineticResult.calibration.kineticsInScope);
assert(csKineticResult.calibration.kineticsConditionalOnMeasuredPLEnergy);
assert(~csKineticResult.calibration.endToEndSizeToKineticsValidated);
assert(csKineticResult.calibration.kineticTrainingRows == 25);
assert(csKineticResult.calibration.kineticTrainingEnergyGroups == 16);
tests{end+1} = ['CsPbBr3 learned rates propagate with conditional-validation ' ...
    'metadata'];

% Optional protocol residual learning improves its own untouched Mondal
% sizes without silently changing the source-calibrated lambda2 observable.
mondalInput = qdCalibratedMaterialInputs(4,4.3);
mondalHybrid = predictQDHybrid(mondalInput,'OpticalProtocol','mondal2019', ...
    'NumberOfSamples',100);
localAssertClose(mondalHybrid.absorptionEnergy_eV,2.62378409090909,0,2e-13);
assert(mondalHybrid.mlOpticalAdaptationActive);
assert(mondalHybrid.mondalProtocolInScope);
localAssertClose(mondalHybrid.lambda2_nm, ...
    mondalHybrid.nominal.lambda2_nm,0,2e-13);
assert(~mondalHybrid.mlPLAdaptationActive);
autoHybrid = predictQDHybrid(mondalInput,'NumberOfSamples',100);
localAssertClose(autoHybrid.absorptionEnergy_eV, ...
    0.5*(autoHybrid.sourceProtocolAbsorptionEnergy_eV+ ...
    autoHybrid.mondalProtocolAbsorptionEnergy_eV),0,2e-13);
inPFallback = predictQDHybrid(qdCalibratedMaterialInputs(2,inPEdge_nm(3)), ...
    'NumberOfSamples',100);
assert(~inPFallback.mlOpticalAdaptationActive);
localAssertClose(inPFallback.absorptionEnergy_eV, ...
    inPFallback.nominal.absorptionEnergy_eV,0,2e-13);
tests{end+1} = ['Protocol-specific optical residual, unknown-protocol ensemble, ' ...
    'and ID2 fallback'];

% Source-data helper and frozen CSV must remain identical.
sourceTable = readtable(fullfile(rootFolder,'CsPbBr3_Abbas2025_reference.csv'));
assert(isequal(sourceTable.PLPeak_eV,kineticReference.PLPeak_eV));
assert(isequal(sourceTable.PLQY_percent,kineticReference.PLQY_percent));
assert(isequal(sourceTable.TotalLifetime_ns,kineticReference.TotalLifetime_ns));
assert(isequal(sourceTable.RadiativeLifetime_ns, ...
    kineticReference.RadiativeLifetime_ns));
tests{end+1} = 'Frozen CsPbBr3 primary source table integrity';

pbSSourceTable = readtable(fullfile(rootFolder, ...
    'PbSCdS_Stylianou2026_reference.csv'),'TextType','string');
assert(isequal(pbSSourceTable.Series,pbSAugerReference.Series));
assert(isequal(pbSSourceTable.PbSCoreDiameter_nm, ...
    pbSAugerReference.PbSCoreDiameter_nm));
assert(isequal(pbSSourceTable.CdSShellThickness_nm, ...
    pbSAugerReference.CdSShellThickness_nm));
assert(isequal(pbSSourceTable.AugerLifetime_ps, ...
    pbSAugerReference.AugerLifetime_ps));
tests{end+1} = 'Frozen PbS/CdS 2026 primary table integrity';

% Regression tests for corrected validation edge cases.
invalidMaterialInput = qdPackInputs(qdDefaultInputs());
invalidMaterialInput(13) = 2.5;
[invalidMaterialOutput,~] = qdPhysicsStep(invalidMaterialInput,[1;0;0;0],0);
assert(bitand(uint32(invalidMaterialOutput(31)),uint32(256)) ~= 0);
assert(invalidMaterialOutput(40) == 1);
assert(qdMaterialDatabase(NaN).id == 1);
zeroPumpInputs = qdDefaultInputs();
zeroPumpInputs.pumpIntensity_Wcm2 = 0;
zeroPumpInputs.pumpPhotonEnergy_eV = 0.1;
zeroPumpResult = simulateQD(zeroPumpInputs,'Duration_ns',0);
assert(bitand(uint32(zeroPumpResult.validityFlags),uint32(512)) == 0);
cdSeInputs = qdAccurateCdSeInputs(3);
cdSeInputs.electronBarrier_eV = qdMaterialVector(5);
cdSeInputs.electronBarrier_eV = cdSeInputs.electronBarrier_eV(9)+0.01;
cdSeBarrierResult = simulateQD(cdSeInputs,'Duration_ns',0);
assert(bitand(uint32(cdSeBarrierResult.validityFlags),uint32(524288)) ~= 0);
tests{end+1} = 'Fractional-ID, NaN metadata, zero-pump, and barrier-envelope fixes';

% Photon-count adapter remains finite and lambda2 remains the dot PL output.
for materialID = 2:4
    if materialID == 2
        photonInputs = qdCalibratedMaterialInputs(2,inPEdge_nm(3));
    elseif materialID == 3
        photonInputs = qdCalibratedMaterialInputs(3,6.0);
    else
        photonInputs = qdCalibratedMaterialInputs(4,6.2);
    end
    photonInputs.incidentPhotonCount = 10;
    photonInputs.inputWavelength_nm = 405;
    photonInputs.beamArea_um2 = 10;
    photonInputs.pumpDuration_ns = 1;
    photonResult = simulateQD(photonInputs,'Duration_ns',2);
    assert(isfinite(photonResult.absorbedPhotonCountExpectedPerDot));
    assert(isfinite(photonResult.emittedPhotonCountExpectedPerDot));
    assert(photonResult.absorbedPhotonCountExpectedPerDot >= 0);
    assert(photonResult.emittedPhotonCountExpectedPerDot >= 0);
    assert(photonResult.lambda2_nm == photonResult.emissionWavelength_nm);
end
tests{end+1} = 'Photon-count/lambda1 adapter across calibrated IDs 2-4';

id4Prediction = predictQDWithError(qdCalibratedMaterialInputs(4,6.2),100);
assert(id4Prediction.benchmark.available);
assert(id4Prediction.benchmark.externalCrossSourceValidation);
assert(~id4Prediction.benchmark.externalPerCaseResidualAvailable);
assert(~id4Prediction.nominal.calibration.externalKineticsValidation);
assert(id4Prediction.nominal.calibration.kineticsHoldoutValidation);
assert(contains(id4Prediction.agreementGrade,'not a per-case score'));
localAssertClose(id4Prediction.benchmark.energyRMSE_eV, ...
    independentAbsorptionRMSE_eV,0,2e-13);
assert(contains(id4Prediction.approximateCombinedIntervalInterpretation, ...
    'not a 95% CI'));
outOfScopePrediction = predictQDWithError(csOutOfScope,100);
assert(~outOfScopePrediction.benchmark.available);
assert(~contains(outOfScopePrediction.radiativeLifetimeBenchmark.reason,'CdSe'));
assert(~contains(outOfScopePrediction.approximateCombinedIntervalInterpretation, ...
    'CdSe'));
tests{end+1} = 'Prediction API separates external error and interval interpretation';

% Full Simulink path: compile once, then compare static/rate outputs for all IDs.
modelFile = fullfile(rootFolder,'VirtualQuantumDotAgent.slx');
load_system(modelFile);
initVirtualQuantumDotAgent();
set_param('VirtualQuantumDotAgent','SimulationCommand','update');
for materialID = 2:4
    if materialID == 2
        simInputs = qdCalibratedMaterialInputs(2,inPEdge_nm(3));
    elseif materialID == 3
        simInputs = qdCalibratedMaterialInputs(3,6.0);
    else
        simInputs = qdCalibratedMaterialInputs(4,6.2);
    end
    assignin('base','qdInput',simInputs);
    simOut = sim('VirtualQuantumDotAgent','StopTime','1e-11', ...
        'ReturnWorkspaceOutputs','on');
    logged = simOut.get('qdOutput');
    simulinkY = logged.signals.values(end,:).';
    [directY,~] = qdPhysicsStep(qdPackInputs(simInputs),[1;0;0;0],0);
    compareIndices = [8:19 35:37 40];
    localAssertClose(max(abs(simulinkY(compareIndices)- ...
        directY(compareIndices))),0,0,2e-10);
end
initVirtualQuantumDotAgent();
tests{end+1} = 'Simulink compile/run and direct-engine agreement for IDs 2-4';

comparison = table(comparisonMaterial,comparisonObservable,comparisonSize_nm, ...
    comparisonReference_eV,comparisonPrediction_eV, ...
    comparisonPrediction_eV-comparisonReference_eV, ...
    'VariableNames',{'Material','Observable','SourceSize_nm', ...
    'Reference_eV','Prediction_eV','Residual_eV'});
writetable(comparison,fullfile(rootFolder, ...
    'MULTIMATERIAL_CALIBRATION_COMPARISON.csv'));
augerComparison = table(pbSAugerReference.Series, ...
    pbSAugerReference.PbSCoreDiameter_nm, ...
    pbSAugerReference.CdSShellThickness_nm, ...
    pbSAugerReference.OuterDiameter_nm,pbSAugerReference.AugerLifetime_ps, ...
    pbSAugerGeneric_ps,pbSAugerPrediction_ps,pbSAugerLOSO_ps, ...
    pbSAugerLOSO_ps-pbSAugerReference.AugerLifetime_ps, ...
    'VariableNames',{'Series','PbSCoreDiameter_nm','CdSShellThickness_nm', ...
    'OuterDiameter_nm','ObservedAugerLifetime_ps','GenericPrediction_ps', ...
    'DeployedFullFitPrediction_ps','WholeSeriesOutOfFoldPrediction_ps', ...
    'WholeSeriesOutOfFoldResidual_ps'});
writetable(augerComparison,fullfile(rootFolder, ...
    'QD_HYBRID_AUGER_PREDICTIONS.csv'));

report = struct();
report.passed = numel(tests);
report.failed = 0;
report.tests = tests;
report.timestamp = char(datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd HH:mm:ss Z'));
report.matlabVersion = version;
report.id2 = struct('source','10.1021/acs.nanolett.3c02630', ...
    'observable','first absorption transition', ...
    'referenceRegressionMaxAbsError_eV',max(abs(inPPrediction_eV-inPReference_eV)), ...
    'externalInScopeEnergyRMSE_eV',NaN, ...
    'outOfScopeInPZnSeAbsorptionSingleError_eV',inPHoldoutAbsError_eV, ...
    'outOfScopeInPZnSePLSingleError_eV',inPHoldoutPLError_eV, ...
    'plValidated',false, ...
    'kineticsValidated',false);
report.id3 = struct('source','10.1021/nn900863a', ...
    'observable','first-exciton absorption transition', ...
    'referenceRegressionMaxAbsError_eV',max(abs(pbSPrediction_eV-pbSReference_eV)), ...
    'externalInScopeEnergyRMSE_eV',NaN, ...
    'thickShellPLHoldoutRMSE_eV',pbSThickPLRMSE_eV, ...
    'thickShellOverlapHoldoutRMSE',pbSThickOverlapRMSE, ...
    'augerSource','10.1021/acs.nanolett.6c00158', ...
    'augerFullFitRMSE_ps',pbSAugerFullFitRMSE_ps, ...
    'augerWholeSeriesCVRMSE_ps',pbSAugerLOSORMSE_ps, ...
    'genericAugerBaselineRMSE_ps',pbSAugerGenericRMSE_ps, ...
    'augerComparison',augerComparison, ...
    'plValidated',false, ...
    'kineticsValidated',false);
report.id4 = struct('opticalSource','10.1021/jacs.7b05683', ...
    'externalOpticalComparisonSource','10.1039/C9SC01339C', ...
    'kineticsSource','10.1038/s41467-025-60848-5', ...
    'externalCrossSourceAbsorptionRMSE_eV',independentAbsorptionRMSE_eV, ...
    'externalCrossSourceAbsorptionBias_eV',independentAbsorptionBias_eV, ...
    'crossProtocolPLAnchorRMSE_eV',crossProtocolPLRMSE_eV, ...
    'kineticMetrics',kineticMetrics);
report.comparison = comparison;
save(fullfile(rootFolder,'MultiMaterialCalibrationValidation.mat'),'report');

fileID = fopen(fullfile(rootFolder,'MULTIMATERIAL_CALIBRATION_RESULTS.txt'),'w');
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'Virtual Quantum Dot Agent - Material IDs 2-4 Calibration\n');
fprintf(fileID,'Timestamp: %s\nMATLAB: %s\nPassed: %d\nFailed: %d\n\n', ...
    report.timestamp,report.matlabVersion,report.passed,report.failed);
for k = 1:numel(tests)
    fprintf(fileID,'PASS  %s\n',tests{k});
end
fprintf(fileID,'\nID2 InP source-equation max error: %.3g eV\n', ...
    report.id2.referenceRegressionMaxAbsError_eV);
fprintf(fileID,'ID2 out-of-scope InP/ZnSe absorption single error: %.9f eV\n', ...
    inPHoldoutAbsError_eV);
fprintf(fileID,'ID2 out-of-scope InP/ZnSe PL single error: %.9f eV\n', ...
    inPHoldoutPLError_eV);
fprintf(fileID,'ID3 PbS source-equation max error: %.3g eV\n', ...
    report.id3.referenceRegressionMaxAbsError_eV);
fprintf(fileID,'ID3 thick-shell PL holdout RMSE: %.9f eV\n', ...
    pbSThickPLRMSE_eV);
fprintf(fileID,'ID3 thick-shell overlap holdout RMSE: %.9f\n', ...
    pbSThickOverlapRMSE);
fprintf(fileID,'ID3 Auger whole-series CV RMSE: %.9f ps\n', ...
    pbSAugerLOSORMSE_ps);
fprintf(fileID,'ID3 generic Auger baseline RMSE: %.9f ps\n', ...
    pbSAugerGenericRMSE_ps);
fprintf(fileID,'ID4 external cross-source absorption RMSE: %.9f eV\n', ...
    independentAbsorptionRMSE_eV);
fprintf(fileID,'ID4 external cross-source absorption bias: %.9f eV\n', ...
    independentAbsorptionBias_eV);
fprintf(fileID,'ID4 cross-protocol PL-anchor RMSE: %.9f eV\n', ...
    crossProtocolPLRMSE_eV);
fprintf(fileID,'ID4 frozen-evaluation radiative-rate RMSE: %.9f ns^-1\n', ...
    kineticMetrics.radiativeRateHoldoutRMSE_nsInv);
fprintf(fileID,'ID4 frozen-evaluation nonradiative-rate RMSE: %.9f ns^-1\n', ...
    kineticMetrics.nonradiativeRateHoldoutRMSE_nsInv);
fprintf(fileID,'ID4 frozen-evaluation total-lifetime RMSE: %.9f ns\n', ...
    kineticMetrics.totalLifetimeHoldoutRMSE_ns);
fprintf(fileID,'ID4 frozen-evaluation radiative-lifetime RMSE: %.9f ns\n', ...
    kineticMetrics.radiativeLifetimeHoldoutRMSE_ns);
fprintf(fileID,'ID4 frozen-evaluation PLQY RMSE: %.9f percentage points\n', ...
    kineticMetrics.plqyHoldoutRMSE_percentagePoints);
end

function value = localRMSE(residual)
value = sqrt(mean(residual.^2));
end

function localAssertClose(actual,expected,relativeTolerance,absoluteTolerance)
allowed = max(absoluteTolerance,relativeTolerance*max(abs(actual),abs(expected)));
assert(abs(actual-expected) <= allowed, ...
    'Expected %.17g, received %.17g (allowed error %.3g).', ...
    expected,actual,allowed);
end
