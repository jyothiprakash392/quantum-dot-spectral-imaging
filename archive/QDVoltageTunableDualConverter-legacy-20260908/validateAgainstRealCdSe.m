function report = validateAgainstRealCdSe(numberOfSamples)
%VALIDATEAGAINSTREALCDSE Compare predictions with a published CdSe benchmark.
%   REPORT = VALIDATEAGAINSTREALCDSE(400) compares the finite-barrier engine
%   and infinite-barrier Brus approximation against three independent,
%   published bare-core CdSe sizing relationships (Yu 2003, Jasieniak 2009,
%   and de Mello Donega/Koole 2009). A seeded scenario ensemble reports
%   input-sensitivity bands separately from observed model-form residuals.

if nargin < 1
    numberOfSamples = 400;
end
validateattributes(numberOfSamples,{'numeric'},{'scalar','integer','>=',100});

rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
yuFrozen = readtable(fullfile(rootFolder,'CdSe_Yu2003_reference.csv'), ...
    'TextType','string');
reference = qdCdSeEmpiricalReferences(yuFrozen.diameter_nm);
writetable(reference,fullfile(rootFolder,'CdSe_REAL_REFERENCE_CURVES.csv'), ...
    'WriteMode','overwrite');
hc_eVnm = 1239.841984332;
nPoints = height(reference);

finiteEnergy_eV = zeros(nPoints,1);
finiteWavelength_nm = zeros(nPoints,1);
brusEnergy_eV = zeros(nPoints,1);
brusWavelength_nm = zeros(nPoints,1);
modelConfidence = zeros(nPoints,1);
validityFlags = zeros(nPoints,1);
electronResidual = zeros(nPoints,1);
holeResidual = zeros(nPoints,1);
plEnergy_eV = zeros(nPoints,1);
modelRadiativeLifetime_ns = zeros(nPoints,1);
donegaRadiativeLifetime_ns = zeros(nPoints,1);

% Real-world comparison profile: room-temperature, zero-field colloidal CdSe.
% The nominal barriers act as effective ligand/interface confinement values.
baseInput = qdDefaultInputs();
baseInput.temperature_K = 300;
baseInput.electricField_kVcm = 0;
baseInput.hydrostaticStrain_pct = 0;
baseInput.pumpIntensity_Wcm2 = 0;
baseInput.shellThickness_nm = 0;
baseInput.surfaceTrapDensity_cm2 = 0;
baseInput.environmentDielectric = 2.25;
baseInput.electronBarrier_eV = 0.90;
baseInput.holeBarrier_eV = 0.60;
baseInput.targetEmission_eV = 0;
baseInput.materialID = 1;

for k = 1:nPoints
    baseInput.radius_nm = reference.Radius_nm(k);
    [y,~] = qdPhysicsStep(qdPackInputs(baseInput),[1;0;0;0],0);
    finiteEnergy_eV(k) = y(8); % absorption, not PL
    finiteWavelength_nm(k) = hc_eVnm/y(8);
    plEnergy_eV(k) = y(9);
    modelRadiativeLifetime_ns(k) = 1e9/y(14);
    donegaRadiativeLifetime_ns(k) = 1/(-0.1151+0.0753*y(9));
    modelConfidence(k) = y(30);
    validityFlags(k) = y(31);
    electronResidual(k) = y(32);
    holeResidual(k) = y(33);
    brus = qdBrusReference(reference.Radius_nm(k),300,1);
    brusEnergy_eV(k) = brus.transitionEnergy_eV;
    brusWavelength_nm(k) = brus.wavelength_nm;
end

observedEnergy_eV = reference.YuEnergy_eV;
observedWavelength_nm = reference.YuWavelength_nm;
finiteMetricsEnergy = localMetrics(finiteEnergy_eV,observedEnergy_eV);
finiteMetricsWavelength = localMetrics(finiteWavelength_nm,observedWavelength_nm);
finiteMetricsJasieniak = localMetrics(finiteEnergy_eV,reference.JasieniakEnergy_eV);
finiteMetricsDonega = localMetrics(finiteEnergy_eV,reference.DonegaEnergy_eV);
finiteMetricsReferenceMean = localMetrics( ...
    finiteEnergy_eV,reference.ReferenceMeanEnergy_eV);
brusMetricsEnergy = localMetrics(brusEnergy_eV,observedEnergy_eV);
brusMetricsWavelength = localMetrics(brusWavelength_nm,observedWavelength_nm);
diameterAtLeast4 = reference.Diameter_nm >= 4;
finiteMetricsEnergy_Dge4 = localMetrics( ...
    finiteEnergy_eV(diameterAtLeast4),observedEnergy_eV(diameterAtLeast4));
finiteMetricsWavelength_Dge4 = localMetrics( ...
    finiteWavelength_nm(diameterAtLeast4),observedWavelength_nm(diameterAtLeast4));

% Reproducible scenario uncertainty. These are explicit engineering
% assumptions, not experimental standard deviations reported by Yu et al.
rng(42,'twister');
sampleEnergy = zeros(numberOfSamples,nPoints);
for k = 1:nPoints
    for sample = 1:numberOfSamples
        sampledInput = baseInput;
        sampledInput.radius_nm = max(0.5,reference.Radius_nm(k)*(1+0.03*randn));
        sampledInput.temperature_K = min(1000,max(0,300+5*randn));
        sampledInput.electronBarrier_eV = min(1.50,max(0.30,0.90+0.12*randn));
        sampledInput.holeBarrier_eV = min(1.20,max(0.20,0.60+0.10*randn));
        sampledInput.environmentDielectric = min(4.0,max(1.2,2.25+0.25*randn));
        [sampleOutput,~] = qdPhysicsStep(qdPackInputs(sampledInput),[1;0;0;0],0);
        sampleEnergy(sample,k) = sampleOutput(8);
    end
end

predictionMedian_eV = zeros(nPoints,1);
predictionLow95_eV = zeros(nPoints,1);
predictionHigh95_eV = zeros(nPoints,1);
for k = 1:nPoints
    ordered = sort(sampleEnergy(:,k));
    predictionLow95_eV(k) = localOrderStatistic(ordered,0.025);
    predictionMedian_eV(k) = localOrderStatistic(ordered,0.50);
    predictionHigh95_eV(k) = localOrderStatistic(ordered,0.975);
end
benchmarkInsideScenario95 = observedEnergy_eV >= predictionLow95_eV & ...
    observedEnergy_eV <= predictionHigh95_eV;
scenarioCoverage = mean(benchmarkInsideScenario95);
meanScenarioHalfWidth_eV = mean((predictionHigh95_eV-predictionLow95_eV)/2);

finiteResidual_eV = finiteEnergy_eV-observedEnergy_eV;
finiteResidual_nm = finiteWavelength_nm-observedWavelength_nm;
finiteResidualJasieniak_eV = finiteEnergy_eV-reference.JasieniakEnergy_eV;
finiteResidualDonega_eV = finiteEnergy_eV-reference.DonegaEnergy_eV;
brusResidual_eV = brusEnergy_eV-observedEnergy_eV;
brusResidual_nm = brusWavelength_nm-observedWavelength_nm;
radiativeLifetimeError_ns = modelRadiativeLifetime_ns-donegaRadiativeLifetime_ns;
radiativeLifetimeError_percent = 100*radiativeLifetimeError_ns./ ...
    donegaRadiativeLifetime_ns;

comparison = table( ...
    reference.Diameter_nm,reference.Radius_nm, ...
    observedEnergy_eV,finiteEnergy_eV,finiteResidual_eV, ...
    reference.JasieniakEnergy_eV,finiteResidualJasieniak_eV, ...
    reference.DonegaEnergy_eV,finiteResidualDonega_eV, ...
    reference.ReferenceMeanEnergy_eV,reference.InterCurveSpread_eV, ...
    reference.DonegaDiameterUncertaintyHalfWidth_eV, ...
    observedWavelength_nm,finiteWavelength_nm,finiteResidual_nm, ...
    brusEnergy_eV,brusResidual_eV,brusWavelength_nm,brusResidual_nm, ...
    predictionLow95_eV,predictionMedian_eV,predictionHigh95_eV, ...
    benchmarkInsideScenario95,plEnergy_eV,modelRadiativeLifetime_ns, ...
    donegaRadiativeLifetime_ns,radiativeLifetimeError_ns, ...
    radiativeLifetimeError_percent,modelConfidence,validityFlags, ...
    'VariableNames',{ ...
    'Diameter_nm','Radius_nm','BenchmarkEnergy_eV','FiniteEnergy_eV', ...
    'FiniteError_eV','JasieniakEnergy_eV','FiniteErrorVsJasieniak_eV', ...
    'DonegaEnergy_eV','FiniteErrorVsDonega_eV','ReferenceMeanEnergy_eV', ...
    'InterCurveSpread_eV','DiameterUncertaintyHalfWidth_eV', ...
    'BenchmarkWavelength_nm','FiniteWavelength_nm', ...
    'FiniteError_nm','BrusEnergy_eV','BrusError_eV','BrusWavelength_nm', ...
    'BrusError_nm','ScenarioLow95_eV','ScenarioMedian_eV','ScenarioHigh95_eV', ...
    'BenchmarkInsideScenario95','PLEnergy_eV','ModelRadiativeLifetime_ns', ...
    'DonegaRadiativeLifetime_ns','RadiativeLifetimeError_ns', ...
    'RadiativeLifetimeError_percent','ModelConfidence','ValidityFlags'});

report = struct();
report.comparison = comparison;
report.finiteBarrier.energy = finiteMetricsEnergy;
report.finiteBarrier.wavelength = finiteMetricsWavelength;
report.finiteBarrier.vsJasieniak.energy = finiteMetricsJasieniak;
report.finiteBarrier.vsDonega.energy = finiteMetricsDonega;
report.finiteBarrier.vsReferenceMean.energy = finiteMetricsReferenceMean;
report.finiteBarrier.diameterAtLeast4nm.energy = finiteMetricsEnergy_Dge4;
report.finiteBarrier.diameterAtLeast4nm.wavelength = finiteMetricsWavelength_Dge4;
report.infiniteBrus.energy = brusMetricsEnergy;
report.infiniteBrus.wavelength = brusMetricsWavelength;
report.improvement.energyRMSEFactor = brusMetricsEnergy.RMSE/finiteMetricsEnergy.RMSE;
report.improvement.wavelengthRMSEFactor = brusMetricsWavelength.RMSE/finiteMetricsWavelength.RMSE;
report.scenarioUncertainty.numberOfSamples = numberOfSamples;
report.scenarioUncertainty.seed = 42;
report.scenarioUncertainty.assumptions = struct( ...
    'radiusRelativeSigma',0.03,'temperatureSigma_K',5, ...
    'electronBarrierSigma_eV',0.12,'holeBarrierSigma_eV',0.10, ...
    'environmentDielectricSigma',0.25);
report.scenarioUncertainty.coverage = scenarioCoverage;
report.scenarioUncertainty.meanHalfWidth_eV = meanScenarioHalfWidth_eV;
report.numerics.maxBoundaryResidual = max([electronResidual;holeResidual]);
report.referenceDisagreement.meanSpread_eV = mean(reference.InterCurveSpread_eV);
report.referenceDisagreement.maxSpread_eV = max(reference.InterCurveSpread_eV);
report.radiativeLifetime.RMSE_ns = sqrt(mean(radiativeLifetimeError_ns.^2));
report.radiativeLifetime.MAE_ns = mean(abs(radiativeLifetimeError_ns));
report.radiativeLifetime.meanRelativeError_percent = ...
    mean(radiativeLifetimeError_percent);
report.radiativeLifetime.meanAbsoluteRelativeError_percent = ...
    mean(abs(radiativeLifetimeError_percent));
report.radiativeLifetime.note = ['Comparison is the model intrinsic ' ...
    'radiative lifetime 1/krad versus the published bright-exciton relation ' ...
    'at the model PL energy; it is not the trap-limited effective lifetime.'];
report.sources = struct( ...
    'Yu2003','https://doi.org/10.1021/cm034081k', ...
    'Jasieniak2009','https://doi.org/10.1021/jp906827m', ...
    'DonegaKoole2009','https://doi.org/10.1021/jp811329r', ...
    'observable','first-exciton absorption peak', ...
    'note',['Reference checkpoints are evaluations of published empirical ' ...
    'relationships, not independent raw observations.']);
report.timestamp = char(datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd HH:mm:ss Z'));

writeMode = 'overwrite';
writetable(comparison,fullfile(rootFolder,'REAL_WORLD_COMPARISON.csv'), ...
    'WriteMode',writeMode);
save(fullfile(rootFolder,'RealWorldValidation.mat'),'report','sampleEnergy');
localWriteReport(rootFolder,report);
localPlotReport(rootFolder,reference,comparison,report);
end

function metrics = localMetrics(predicted,observed)
residual = predicted-observed;
metrics = struct();
metrics.N = numel(residual);
metrics.Bias = mean(residual);
metrics.MAE = mean(abs(residual));
metrics.RMSE = sqrt(mean(residual.^2));
metrics.MaxAbsError = max(abs(residual));
metrics.MAPE_percent = 100*mean(abs(residual./observed));
denominator = sum((observed-mean(observed)).^2);
metrics.R2 = 1-sum(residual.^2)/max(denominator,realmin);
metrics.FractionWithin50meV = mean(abs(residual) <= 0.050);
end

function value = localOrderStatistic(ordered,p)
index = 1+(numel(ordered)-1)*p;
low = floor(index);
high = ceil(index);
if low == high
    value = ordered(low);
else
    fraction = index-low;
    value = ordered(low)*(1-fraction)+ordered(high)*fraction;
end
end

function localWriteReport(rootFolder,report)
fileID = fopen(fullfile(rootFolder,'REAL_WORLD_VALIDATION_RESULTS.txt'),'w');
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'Virtual Quantum Dot Agent - Real-World CdSe Comparison\n');
fprintf(fileID,'Timestamp: %s\n',report.timestamp);
fprintf(fileID,'Observable compared: %s\n',report.sources.observable);
fprintf(fileID,'Yu 2003 DOI: %s\n',report.sources.Yu2003);
fprintf(fileID,'Jasieniak 2009 DOI: %s\n',report.sources.Jasieniak2009);
fprintf(fileID,'Donega/Koole 2009 DOI: %s\n\n',report.sources.DonegaKoole2009);
fprintf(fileID,'FINITE-BARRIER MODEL, DIAMETER 3-8 nm\n');
fprintf(fileID,'Against Yu 2003:\n');
fprintf(fileID,'Energy bias       : %+0.6f eV\n',report.finiteBarrier.energy.Bias);
fprintf(fileID,'Energy MAE        : %0.6f eV\n',report.finiteBarrier.energy.MAE);
fprintf(fileID,'Energy RMSE       : %0.6f eV\n',report.finiteBarrier.energy.RMSE);
fprintf(fileID,'Energy max error  : %0.6f eV\n',report.finiteBarrier.energy.MaxAbsError);
fprintf(fileID,'Energy MAPE       : %0.3f %%\n',report.finiteBarrier.energy.MAPE_percent);
fprintf(fileID,'Wavelength RMSE   : %0.3f nm\n',report.finiteBarrier.wavelength.RMSE);
fprintf(fileID,'Within 50 meV     : %0.1f %%\n\n', ...
    100*report.finiteBarrier.energy.FractionWithin50meV);
fprintf(fileID,'Against Jasieniak 2009 energy RMSE : %0.6f eV\n', ...
    report.finiteBarrier.vsJasieniak.energy.RMSE);
fprintf(fileID,'Against Donega/Koole energy RMSE   : %0.6f eV\n', ...
    report.finiteBarrier.vsDonega.energy.RMSE);
fprintf(fileID,'Against three-curve mean RMSE      : %0.6f eV\n', ...
    report.finiteBarrier.vsReferenceMean.energy.RMSE);
fprintf(fileID,'Mean inter-curve spread            : %0.6f eV\n', ...
    report.referenceDisagreement.meanSpread_eV);
fprintf(fileID,'Maximum inter-curve spread         : %0.6f eV\n\n', ...
    report.referenceDisagreement.maxSpread_eV);
fprintf(fileID,'FINITE-BARRIER MODEL, DIAMETER >= 4 nm (YU)\n');
fprintf(fileID,'Energy MAE        : %0.6f eV\n', ...
    report.finiteBarrier.diameterAtLeast4nm.energy.MAE);
fprintf(fileID,'Energy RMSE       : %0.6f eV\n', ...
    report.finiteBarrier.diameterAtLeast4nm.energy.RMSE);
fprintf(fileID,'Wavelength RMSE   : %0.3f nm\n\n', ...
    report.finiteBarrier.diameterAtLeast4nm.wavelength.RMSE);
fprintf(fileID,'INFINITE-BARRIER BRUS APPROXIMATION (YU)\n');
fprintf(fileID,'Energy MAE        : %0.6f eV\n',report.infiniteBrus.energy.MAE);
fprintf(fileID,'Energy RMSE       : %0.6f eV\n',report.infiniteBrus.energy.RMSE);
fprintf(fileID,'Wavelength RMSE   : %0.3f nm\n\n',report.infiniteBrus.wavelength.RMSE);
fprintf(fileID,'FINITE-BARRIER RMSE IMPROVEMENT: %0.2fx in energy, %0.2fx in wavelength\n\n', ...
    report.improvement.energyRMSEFactor,report.improvement.wavelengthRMSEFactor);
fprintf(fileID,'ASSUMPTION-DRIVEN SCENARIO BAND (%d samples, seed %d)\n', ...
    report.scenarioUncertainty.numberOfSamples,report.scenarioUncertainty.seed);
fprintf(fileID,'95%% band Yu-curve coverage : %0.1f %%\n', ...
    100*report.scenarioUncertainty.coverage);
fprintf(fileID,'Mean 95%% half-width        : %0.6f eV\n', ...
    report.scenarioUncertainty.meanHalfWidth_eV);
fprintf(fileID,'Radius 1-sigma assumption  : %0.1f %%\n', ...
    100*report.scenarioUncertainty.assumptions.radiusRelativeSigma);
fprintf(fileID,'Temperature sigma          : %0.1f K\n', ...
    report.scenarioUncertainty.assumptions.temperatureSigma_K);
fprintf(fileID,'Electron barrier sigma     : %0.3f eV\n', ...
    report.scenarioUncertainty.assumptions.electronBarrierSigma_eV);
fprintf(fileID,'Hole barrier sigma         : %0.3f eV\n', ...
    report.scenarioUncertainty.assumptions.holeBarrierSigma_eV);
fprintf(fileID,'Environment epsilon sigma  : %0.3f\n\n', ...
    report.scenarioUncertainty.assumptions.environmentDielectricSigma);
fprintf(fileID,'INTRINSIC RADIATIVE LIFETIME CHECK\n');
fprintf(fileID,'RMSE versus Donega/Koole relation : %0.3f ns\n', ...
    report.radiativeLifetime.RMSE_ns);
fprintf(fileID,'Mean relative error               : %+0.2f %%\n', ...
    report.radiativeLifetime.meanRelativeError_percent);
fprintf(fileID,'Mean absolute relative error      : %0.2f %%\n\n', ...
    report.radiativeLifetime.meanAbsoluteRelativeError_percent);
fprintf(fileID,'INTERPRETATION\n');
fprintf(fileID,['The finite-barrier model is quantitatively useful from about 4-8 nm ' ...
    'diameter under this scenario. The largest error occurs at 3 nm, where ' ...
    'atomistic, non-parabolic and surface effects are strongest.\n']);
fprintf(fileID,['The scenario band measures sensitivity to stated input assumptions; ' ...
    'it is not a statistically calibrated experimental confidence interval.\n']);
fprintf(fileID,['All three curves are empirical relationships, not independent raw ' ...
    'observations. Their spread measures calibration-choice disagreement.\n']);
fprintf(fileID,['The lifetime check uses 1/radiativeRate_Hz, not the trap-limited ' ...
    'effective lifetime.\n']);
end

function localPlotReport(rootFolder,reference,comparison,report)
figureHandle = figure('Color','w','Name','Real-World CdSe Validation', ...
    'Position',[80 80 1200 780]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

nexttile;
fill([reference.Diameter_nm;flipud(reference.Diameter_nm)], ...
    [comparison.ScenarioLow95_eV;flipud(comparison.ScenarioHigh95_eV)], ...
    [0.75 0.86 1.0],'EdgeColor','none','FaceAlpha',0.45); hold on;
plot(reference.Diameter_nm,comparison.BenchmarkEnergy_eV,'ko-', ...
    'LineWidth',1.3,'MarkerFaceColor','k');
plot(reference.Diameter_nm,comparison.JasieniakEnergy_eV,'kd--', ...
    'LineWidth',1.2,'MarkerFaceColor',[0.4 0.4 0.4]);
plot(reference.Diameter_nm,comparison.DonegaEnergy_eV,'kv:', ...
    'LineWidth',1.2,'MarkerFaceColor',[0.7 0.7 0.7]);
plot(reference.Diameter_nm,comparison.FiniteEnergy_eV,'b^-', ...
    'LineWidth',1.8,'MarkerFaceColor','b');
plot(reference.Diameter_nm,comparison.BrusEnergy_eV,'rs--', ...
    'LineWidth',1.5,'MarkerFaceColor','r');
xlabel('CdSe diameter (nm)'); ylabel('First-exciton energy (eV)'); grid on;
legend('assumption-driven 95% band','Yu 2003','Jasieniak 2009', ...
    'Donega/Koole 2009','finite-barrier engine','infinite-barrier Brus', ...
    'Location','northeast');
title('Prediction versus real-world sizing curves');

nexttile;
plot(reference.Diameter_nm,1000*comparison.FiniteError_eV,'b^-', ...
    'LineWidth',1.8,'MarkerFaceColor','b'); hold on;
plot(reference.Diameter_nm,1000*comparison.FiniteErrorVsJasieniak_eV, ...
    'md--','LineWidth',1.4,'MarkerFaceColor','m');
plot(reference.Diameter_nm,1000*comparison.FiniteErrorVsDonega_eV, ...
    'gv:','LineWidth',1.4,'MarkerFaceColor','g');
yline(0,'k-'); yline(50,'k:'); yline(-50,'k:');
xlabel('CdSe diameter (nm)'); ylabel('Prediction error (meV)'); grid on;
legend('versus Yu','versus Jasieniak','versus Donega/Koole', ...
    'Location','northeast');
title('Finite-barrier signed residual');

nexttile;
bar(categorical({'Yu','Jasieniak','Donega/Koole','3-curve mean','Brus vs Yu'}), ...
    1000*[report.finiteBarrier.energy.RMSE, ...
    report.finiteBarrier.vsJasieniak.energy.RMSE, ...
    report.finiteBarrier.vsDonega.energy.RMSE, ...
    report.finiteBarrier.vsReferenceMean.energy.RMSE, ...
    report.infiniteBrus.energy.RMSE]);
ylabel('RMSE (meV)'); grid on;
title(sprintf('Finite model improves energy RMSE %.1fx', ...
    report.improvement.energyRMSEFactor));

nexttile;
plot(reference.Diameter_nm,comparison.ModelRadiativeLifetime_ns,'b^-', ...
    'LineWidth',1.8,'MarkerFaceColor','b'); hold on;
plot(reference.Diameter_nm,comparison.DonegaRadiativeLifetime_ns,'ko--', ...
    'LineWidth',1.5,'MarkerFaceColor','k');
xlabel('CdSe diameter (nm)'); ylabel('Intrinsic radiative lifetime (ns)'); grid on;
title(sprintf('Radiative-lifetime mean error %+.1f%%', ...
    report.radiativeLifetime.meanRelativeError_percent));
legend('finite-barrier engine','Donega/Koole relation','Location','northwest');

superTitle = sgtitle(sprintf(['Virtual Quantum Dot Agent: published CdSe comparison ' ...
    '(scenario band: %.0f%% Yu coverage, %.0f meV half-width)'], ...
    100*report.scenarioUncertainty.coverage, ...
    1000*report.scenarioUncertainty.meanHalfWidth_eV));
superTitle.Color = 'k';
allAxes = findall(figureHandle,'Type','axes');
set(allAxes,'Color','w','XColor','k','YColor','k', ...
    'GridColor',[0.72 0.72 0.72],'GridAlpha',0.55);
allText = findall(figureHandle,'Type','text');
set(allText,'Color','k');
allLegends = findall(figureHandle,'Type','legend');
set(allLegends,'Color','w','TextColor','k','EdgeColor',[0.35 0.35 0.35]);
exportgraphics(figureHandle,fullfile(rootFolder,'RealWorldCdSeValidation.png'), ...
    'Resolution',180);
end
