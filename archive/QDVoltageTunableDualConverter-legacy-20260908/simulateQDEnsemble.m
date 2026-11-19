function ensemble = simulateQDEnsemble(qdInput,varargin)
%SIMULATEQDENSEMBLE Deterministic size-ensemble and detector observation model.
%   E = SIMULATEQDENSEMBLE(INPUTS) propagates a lognormal core-radius
%   distribution through SIMULATEQD using deterministic quadrature. It mixes
%   every member on a common energy grid, optionally applies Gaussian
%   instrument broadening, and maps emitted photons to detector counts.
%
%   The wrapper does not change the 14-input/40-output Simulink contract. It
%   assumes independent dots exposed to the same pump and ignores pump
%   depletion, inter-dot energy transfer, reabsorption, and multiple scattering.
%
%   Important name-value options:
%     RadiusCV                   arithmetic radius coefficient of variation
%     Radii_nm/NumberFractions   measured discrete number distribution
%     RadiusBounds_nm            conditioning bounds for lognormal quadrature
%     QuadratureOrder            3-41 point deterministic quadrature
%     Duration_ns                member simulation duration; static default 0
%     InstrumentFWHM_eV          Gaussian spectrometer response width
%     NumberOfDots               illuminated independent-dot count
%     CollectionEfficiency       0-1 photon collection fraction
%     OpticalTransmission        0-1 optical throughput
%     DetectorQuantumEfficiency  0-1 detector quantum efficiency
%     DarkCountRate_Hz           detector dark-count rate
%     ReadNoiseElectronsRMS      independent RMS read noise per pixel
%     DetectorPixelCount         number of integrated detector pixels
%     ExcessNoiseFactor          signal variance multiplier, at least 1
%     ExposureTime_ns            defaults to Duration_ns
%     ReturnMembers              retain complete member results

defaults = qdDefaultInputs();
if nargin < 1 || isempty(qdInput)
    qdInput = defaults;
elseif isnumeric(qdInput) && isscalar(qdInput) && isreal(qdInput) && ...
        isfinite(qdInput)
    defaults.radius_nm = qdInput;
    qdInput = defaults;
elseif isstruct(qdInput) && isscalar(qdInput)
    suppliedNames = fieldnames(qdInput);
    for k = 1:numel(suppliedNames)
        if ~isfield(defaults,suppliedNames{k})
            error('VirtualQD:UnknownInput', ...
                'Unknown structure field "%s".',suppliedNames{k});
        end
        defaults.(suppliedNames{k}) = qdInput.(suppliedNames{k});
    end
    qdInput = defaults;
else
    error('VirtualQD:EnsembleInput', ...
        'First input must be a scalar radius or qdInput structure.');
end

scalarFinite = @(x)isnumeric(x)&&isscalar(x)&&isreal(x)&&isfinite(x);
unitInterval = @(x)scalarFinite(x)&&x>=0&&x<=1;
parser = inputParser;
parser.FunctionName = 'simulateQDEnsemble';
addParameter(parser,'RadiusCV',0.05, ...
    @(x)scalarFinite(x)&&x>=0&&x<=1);
addParameter(parser,'Radii_nm',[], ...
    @(x)isempty(x)||(isnumeric(x)&&isvector(x)&&isreal(x)&& ...
    all(isfinite(x(:)))));
addParameter(parser,'NumberFractions',[], ...
    @(x)isempty(x)||(isnumeric(x)&&isvector(x)&&isreal(x)&& ...
    all(isfinite(x(:)))));
addParameter(parser,'RadiusBounds_nm',[0.5 50], ...
    @(x)isnumeric(x)&&isreal(x)&&numel(x)==2&&all(isfinite(x(:)))&& ...
    x(1)>0&&x(2)>x(1));
addParameter(parser,'QuadratureOrder',15, ...
    @(x)scalarFinite(x)&&x==fix(x)&&x>=3&&x<=41);
addParameter(parser,'Duration_ns',0, ...
    @(x)scalarFinite(x)&&x>=0);
addParameter(parser,'EnergyGridSize',2001, ...
    @(x)scalarFinite(x)&&x==fix(x)&&x>=501&&x<=10001);
addParameter(parser,'InstrumentFWHM_eV',0, ...
    @(x)scalarFinite(x)&&x>=0&&x<=1);
addParameter(parser,'NumberOfDots',1, ...
    @(x)scalarFinite(x)&&x>=0);
addParameter(parser,'CollectionEfficiency',1,unitInterval);
addParameter(parser,'OpticalTransmission',1,unitInterval);
addParameter(parser,'DetectorQuantumEfficiency',1,unitInterval);
addParameter(parser,'DarkCountRate_Hz',0, ...
    @(x)scalarFinite(x)&&x>=0);
addParameter(parser,'ReadNoiseElectronsRMS',0, ...
    @(x)scalarFinite(x)&&x>=0);
addParameter(parser,'DetectorPixelCount',1, ...
    @(x)scalarFinite(x)&&x==fix(x)&&x>=1);
addParameter(parser,'ExcessNoiseFactor',1, ...
    @(x)scalarFinite(x)&&x>=1);
addParameter(parser,'ExposureTime_ns',[], ...
    @(x)isempty(x)||(scalarFinite(x)&&x>=0));
addParameter(parser,'InitialProbabilities',[1;0;0;0], ...
    @(x)isnumeric(x)&&isreal(x)&&numel(x)==4&&all(isfinite(x(:))));
addParameter(parser,'ReturnMembers',false, ...
    @(x)(islogical(x)||isnumeric(x))&&isscalar(x)&&isfinite(x));
parse(parser,varargin{:});
options = parser.Results;

if qdInput.radius_nm <= 0
    error('VirtualQD:EnsembleRadius', ...
        'The arithmetic mean radius must be greater than zero.');
end
if isempty(options.ExposureTime_ns)
    exposureTime_ns = options.Duration_ns;
else
    exposureTime_ns = options.ExposureTime_ns;
end

radiusBounds_nm = sort(options.RadiusBounds_nm(:));
hasDiscreteRadii = ~isempty(options.Radii_nm) || ...
    ~isempty(options.NumberFractions);
if hasDiscreteRadii
    if isempty(options.Radii_nm) || isempty(options.NumberFractions) || ...
            numel(options.Radii_nm) ~= numel(options.NumberFractions)
        error('VirtualQD:EnsembleDistribution', ...
            ['Radii_nm and NumberFractions must both be supplied with ' ...
            'the same number of elements.']);
    end
    radii_nm = options.Radii_nm(:);
    numberWeights = options.NumberFractions(:);
    if any(radii_nm < radiusBounds_nm(1) | radii_nm > radiusBounds_nm(2))
        error('VirtualQD:EnsembleDistribution', ...
            'Every measured radius must lie inside RadiusBounds_nm.');
    end
    if any(numberWeights < 0) || sum(numberWeights) <= 0
        error('VirtualQD:EnsembleDistribution', ...
            'NumberFractions must be nonnegative with a positive sum.');
    end
    numberWeights = numberWeights/sum(numberWeights);
    % Zero-number-fraction bins are not ensemble members. Retaining them
    % would let absent particles change the common grid, validity flags, or
    % minimum confidence even though they contribute no physical weight.
    positiveWeight = numberWeights > 0;
    radii_nm = radii_nm(positiveWeight);
    numberWeights = numberWeights(positiveWeight);
    numberWeights = numberWeights/sum(numberWeights);
    distributionKind = 'discrete measured number fractions';
    logSigma = NaN;
    logMu = NaN;
    excludedTailProbability = 0;
% A zero-width ensemble is evaluated once and therefore reproduces the
% single-dot API exactly instead of accumulating quadrature roundoff.
elseif options.RadiusCV == 0
    radii_nm = qdInput.radius_nm;
    numberWeights = 1;
    if radii_nm < radiusBounds_nm(1) || radii_nm > radiusBounds_nm(2)
        error('VirtualQD:EnsembleRadius', ...
            'The mean radius must lie inside RadiusBounds_nm.');
    end
    distributionKind = 'monodisperse';
    logSigma = 0;
    logMu = log(qdInput.radius_nm);
    excludedTailProbability = 0;
else
    logSigma = sqrt(log1p(options.RadiusCV^2));
    logMu = log(qdInput.radius_nm)-0.5*logSigma^2;
    lowerCDF = localNormalCDF((log(radiusBounds_nm(1))-logMu)/logSigma);
    upperCDF = localNormalCDF((log(radiusBounds_nm(2))-logMu)/logSigma);
    retainedProbability = upperCDF-lowerCDF;
    if retainedProbability <= 1e-12
        error('VirtualQD:EnsembleDistribution', ...
            'RadiusBounds_nm retain too little of the lognormal distribution.');
    end
    excludedTailProbability = max(0,1-retainedProbability);
    [hermiteNodes,hermiteWeights] = localGaussHermite( ...
        options.QuadratureOrder);
    unboundedRadii_nm = exp(logMu+sqrt(2)*logSigma*hermiteNodes);
    % Use the unbounded Gauss-Hermite rule only when the excluded
    % probability is numerically negligible. Quadrature nodes lying inside
    % the bounds does not imply that the underlying distribution is inside.
    tailProbabilityTolerance = 1e-12;
    if excludedTailProbability <= tailProbabilityTolerance && ...
            all(unboundedRadii_nm >= radiusBounds_nm(1) & ...
            unboundedRadii_nm <= radiusBounds_nm(2))
        radii_nm = unboundedRadii_nm;
        numberWeights = hermiteWeights/sqrt(pi);
        numberWeights = numberWeights/sum(numberWeights);
        distributionKind = ['lognormal Gauss-Hermite rule; negligible ' ...
            'out-of-bounds tail probability reported'];
    else
        [nodes,legendreWeights] = localGaussLegendre( ...
            options.QuadratureOrder);
        uniformProbability = 0.5*(lowerCDF+upperCDF)+ ...
            0.5*retainedProbability*nodes;
        normalQuantile = -sqrt(2)*erfcinv(2*uniformProbability);
        radii_nm = exp(logMu+logSigma*normalQuantile);
        numberWeights = legendreWeights/2;
        numberWeights = numberWeights/sum(numberWeights);
        distributionKind = 'lognormal conditioned to RadiusBounds_nm';
    end
end
radii_nm = radii_nm(:);
numberWeights = numberWeights(:);
memberCount = numel(radii_nm);
if hasDiscreteRadii
    requestedMeanRadius_nm = sum(numberWeights.*radii_nm);
    requestedRadiusStd_nm = sqrt(sum(numberWeights.* ...
        (radii_nm-requestedMeanRadius_nm).^2));
    requestedRadiusCV = requestedRadiusStd_nm/requestedMeanRadius_nm;
else
    requestedMeanRadius_nm = qdInput.radius_nm;
    requestedRadiusCV = options.RadiusCV;
end

members = cell(memberCount,1);
for k = 1:memberCount
    memberInput = qdInput;
    memberInput.radius_nm = radii_nm(k);
    members{k} = simulateQD(memberInput, ...
        'Duration_ns',options.Duration_ns, ...
        'InitialProbabilities',options.InitialProbabilities, ...
        'ReturnTrace',false);
end

absorptionEnergy_eV = zeros(memberCount,1);
plEnergy_eV = zeros(memberCount,1);
lambda2_nm = zeros(memberCount,1);
plFWHM_eV = zeros(memberCount,1);
plPhotonRate_Hz = zeros(memberCount,1);
trapEmissionRate_Hz = zeros(memberCount,1);
bandEdgePhotonRate_Hz = zeros(memberCount,1);
generationYieldProxy_Hz = zeros(memberCount,1);
absorbedPerDot = zeros(memberCount,1);
emittedPerDot = zeros(memberCount,1);
trapEmissionPerDot = zeros(memberCount,1);
bandEdgeEmittedPerDot = zeros(memberCount,1);
effectiveLifetime_ns = zeros(memberCount,1);
internalQuantumYield = zeros(memberCount,1);
modelConfidence = zeros(memberCount,1);
memberFlags = zeros(memberCount,1,'uint32');
opticalInScope = false(memberCount,1);
plInScope = false(memberCount,1);
kineticsInScope = false(memberCount,1);
augerInScope = false(memberCount,1);
energyMinimum_eV = inf;
energyMaximum_eV = -inf;

for k = 1:memberCount
    member = members{k};
    absorptionEnergy_eV(k) = member.absorptionEnergy_eV;
    plEnergy_eV(k) = member.plEnergy_eV;
    lambda2_nm(k) = member.lambda2_nm;
    plFWHM_eV(k) = member.spectrum.plFWHM_eV;
    plPhotonRate_Hz(k) = member.plPhotonRate_Hz;
    trapEmissionRate_Hz(k) = member.trapEmissionPhotonRate_Hz;
    bandEdgePhotonRate_Hz(k) = max(0, ...
        plPhotonRate_Hz(k)-trapEmissionRate_Hz(k));
    generationYieldProxy_Hz(k) = member.generationRate_Hz* ...
        member.internalQuantumYield;
    absorbedPerDot(k) = member.absorbedPhotonCountExpectedPerDot;
    emittedPerDot(k) = member.emittedPhotonCountExpectedPerDot;
    trapEmissionPerDot(k) = member.trapEmissionPhotonCountExpectedPerDot;
    bandEdgeEmittedPerDot(k) = max(0, ...
        emittedPerDot(k)-trapEmissionPerDot(k));
    effectiveLifetime_ns(k) = member.effectiveLifetime_ns;
    internalQuantumYield(k) = member.internalQuantumYield;
    modelConfidence(k) = member.modelConfidence;
    memberFlags(k) = uint32(round(member.validityFlags));
    opticalInScope(k) = member.calibration.opticalInScope;
    plInScope(k) = member.calibration.plInScope;
    kineticsInScope(k) = member.calibration.kineticsInScope;
    augerInScope(k) = member.calibration.augerInScope;
    energyMinimum_eV = min(energyMinimum_eV, ...
        min(member.spectrum.energy_eV));
    energyMaximum_eV = max(energyMaximum_eV, ...
        max(member.spectrum.energy_eV));
end

instrumentPadding_eV = 4*options.InstrumentFWHM_eV;
energyMinimum_eV = max(0.01,energyMinimum_eV-instrumentPadding_eV);
energyMaximum_eV = energyMaximum_eV+instrumentPadding_eV;
energy_eV = linspace(energyMinimum_eV,energyMaximum_eV, ...
    options.EnergyGridSize).';

absorptionCrossSection_m2 = zeros(size(energy_eV));
absorptionLineIntrinsic_m2_per_eV = zeros(size(energy_eV));
plRateIntrinsic_Hz_perDot_per_eV = zeros(size(energy_eV));
plEpisodeIntrinsic_perDot_per_eV = zeros(size(energy_eV));

for k = 1:memberCount
    member = members{k};
    memberSpectrum = qdGenerateSpectra(member, ...
        member.effectiveInputs.temperature_K,energy_eV);
    absorptionCrossSection_m2 = absorptionCrossSection_m2+ ...
        numberWeights(k)*memberSpectrum.absorptionCrossSection_m2;
    absorptionLineIntrinsic_m2_per_eV = ...
        absorptionLineIntrinsic_m2_per_eV+numberWeights(k)* ...
        memberSpectrum.absorption_m2_per_eV;
    plShape = localGaussian(energy_eV,plEnergy_eV(k),plFWHM_eV(k));
    plRateIntrinsic_Hz_perDot_per_eV = ...
        plRateIntrinsic_Hz_perDot_per_eV+numberWeights(k)* ...
        bandEdgePhotonRate_Hz(k)*plShape;
    plEpisodeIntrinsic_perDot_per_eV = ...
        plEpisodeIntrinsic_perDot_per_eV+numberWeights(k)* ...
        bandEdgeEmittedPerDot(k)*plShape;
end

% Select a transparent PL weighting convention. Integrated emitted photons
% are preferred, then instantaneous photon rate, then generation*IQY. A
% no-pump optical calculation falls back to number weighting.
[emissionWeights,plWeightingMode] = localEmissionWeights( ...
    numberWeights,bandEdgeEmittedPerDot,bandEdgePhotonRate_Hz, ...
    generationYieldProxy_Hz);
plProbabilityIntrinsic_per_eV = zeros(size(energy_eV));
for k = 1:memberCount
    plProbabilityIntrinsic_per_eV = plProbabilityIntrinsic_per_eV+ ...
        emissionWeights(k)*localGaussian(energy_eV, ...
        plEnergy_eV(k),plFWHM_eV(k));
end
plProbabilityIntrinsic_per_eV = localNormalizeDensity( ...
    energy_eV,plProbabilityIntrinsic_per_eV);

absorptionLineObserved_m2_per_eV = localGaussianBroaden(energy_eV, ...
    absorptionLineIntrinsic_m2_per_eV,options.InstrumentFWHM_eV);
plProbabilityObserved_per_eV = localGaussianBroaden(energy_eV, ...
    plProbabilityIntrinsic_per_eV,options.InstrumentFWHM_eV);
plProbabilityObserved_per_eV = localNormalizeDensity( ...
    energy_eV,plProbabilityObserved_per_eV);
plRateObserved_Hz_perDot_per_eV = localGaussianBroaden(energy_eV, ...
    plRateIntrinsic_Hz_perDot_per_eV,options.InstrumentFWHM_eV);
plEpisodeObserved_perDot_per_eV = localGaussianBroaden(energy_eV, ...
    plEpisodeIntrinsic_perDot_per_eV,options.InstrumentFWHM_eV);

hc_eVnm = 1239.841984332;
wavelengthDescending_nm = hc_eVnm./energy_eV;
jacobian_eV_per_nm = hc_eVnm./wavelengthDescending_nm.^2;
wavelengthAscending_nm = flipud(wavelengthDescending_nm);
absorptionLineObserved_m2_per_nm = flipud( ...
    absorptionLineObserved_m2_per_eV.*jacobian_eV_per_nm);
plProbabilityObserved_per_nm = flipud( ...
    plProbabilityObserved_per_eV.*jacobian_eV_per_nm);
plProbabilityObserved_per_nm = localNormalizeDensity( ...
    wavelengthAscending_nm,plProbabilityObserved_per_nm);
plRateObserved_Hz_perDot_per_nm = flipud( ...
    plRateObserved_Hz_perDot_per_eV.*jacobian_eV_per_nm);
plEpisodeObserved_perDot_per_nm = flipud( ...
    plEpisodeObserved_perDot_per_eV.*jacobian_eV_per_nm);

[~,plEnergyPeakIndex] = max(plProbabilityObserved_per_eV);
[~,plWavelengthPeakIndex] = max(plProbabilityObserved_per_nm);
[~,absorptionPeakIndex] = max(absorptionLineObserved_m2_per_eV);
plPeakEnergy_eV = energy_eV(plEnergyPeakIndex);
plPeakWavelength_nm = wavelengthAscending_nm(plWavelengthPeakIndex);
absorptionPeakEnergy_eV = energy_eV(absorptionPeakIndex);
plMeanEnergy_eV = trapz(energy_eV, ...
    energy_eV.*plProbabilityObserved_per_eV);
plMeanWavelength_nm = trapz(wavelengthAscending_nm, ...
    wavelengthAscending_nm.*plProbabilityObserved_per_nm);
plFWHMObserved_eV = localFWHM(energy_eV,plProbabilityObserved_per_eV);
plFWHMObserved_nm = localFWHM(wavelengthAscending_nm, ...
    plProbabilityObserved_per_nm);
absorptionFWHMObserved_eV = localFWHM(energy_eV, ...
    absorptionLineObserved_m2_per_eV);

aggregateFlags = uint32(0);
for k = 1:memberCount
    aggregateFlags = bitor(aggregateFlags,memberFlags(k));
end
numberWeightedOutputs = localAverageOutputs(members,numberWeights, ...
    aggregateFlags);

averageAbsorbedPerDot = sum(numberWeights.*absorbedPerDot);
averageEmittedPerDot = sum(numberWeights.*emittedPerDot);
averageTrapEmissionPerDot = sum(numberWeights.*trapEmissionPerDot);
totalAbsorbed = options.NumberOfDots*averageAbsorbedPerDot;
totalEmitted = options.NumberOfDots*averageEmittedPerDot;
totalTrapEmission = options.NumberOfDots*averageTrapEmissionPerDot;
detectionEfficiency = options.CollectionEfficiency* ...
    options.OpticalTransmission*options.DetectorQuantumEfficiency;
signalDetected = totalEmitted*detectionEfficiency;
darkDetected = options.DarkCountRate_Hz*exposureTime_ns*1e-9;
detectedTotal = signalDetected+darkDetected;
poissonShotNoiseStd = sqrt(max(0,detectedTotal));
detectorVariance = options.ExcessNoiseFactor*signalDetected+darkDetected+ ...
    options.DetectorPixelCount*options.ReadNoiseElectronsRMS^2;
detectorNoiseStd = sqrt(max(0,detectorVariance));
if detectorNoiseStd > 0
    signalToNoise = signalDetected/detectorNoiseStd;
else
    signalToNoise = 0;
end
deliveredIncidentPhotonCount = members{1}.deliveredIncidentPhotonCount;
if members{1}.incidentCountDefined && deliveredIncidentPhotonCount > 0
    pumpDepletionIndicator = totalAbsorbed/deliveredIncidentPhotonCount;
    opticallyThinLikelyValid = pumpDepletionIndicator <= 0.05;
    pumpDepletionAssessment = 'assessed from finite delivered photon count';
else
    pumpDepletionIndicator = NaN;
    opticallyThinLikelyValid = NaN;
    pumpDepletionAssessment = ...
        'not assessed: no finite incident-photon budget was supplied';
end

realizedMeanRadius_nm = sum(numberWeights.*radii_nm);
realizedRadiusStd_nm = sqrt(sum(numberWeights.* ...
    (radii_nm-realizedMeanRadius_nm).^2));
numberWeightedPLMean_eV = sum(numberWeights.*plEnergy_eV);
emissionWeightedPLStd_eV = sqrt(sum(emissionWeights.* ...
    (plEnergy_eV-sum(emissionWeights.*plEnergy_eV)).^2));

ensemble = struct();
ensemble.modelVersion = '1.5.1';
ensemble.inputs = qdInput;
ensemble.method = ['number-weighted physical radius ensemble with ' ...
    'deterministic quadrature or measured discrete fractions'];
ensemble.distribution = struct( ...
    'kind',distributionKind, ...
    'requestedMeanRadius_nm',requestedMeanRadius_nm, ...
    'requestedRadiusCV',requestedRadiusCV, ...
    'radiusBounds_nm',radiusBounds_nm.', ...
    'excludedTailProbability',excludedTailProbability, ...
    'realizedMeanRadius_nm',realizedMeanRadius_nm, ...
    'realizedRadiusStd_nm',realizedRadiusStd_nm, ...
    'realizedRadiusCV',realizedRadiusStd_nm/realizedMeanRadius_nm, ...
    'logMu',logMu,'logSigma',logSigma, ...
    'quadratureOrderRequested',options.QuadratureOrder, ...
    'memberCount',memberCount);
ensemble.numberWeightedOutputs = numberWeightedOutputs;
ensemble.numberWeightedOutputsInterpretation = [ ...
    'Descriptive number-weighted scalar means. A mean rate and a mean ' ...
    'lifetime do not define one equivalent ensemble decay law.'];
ensemble.numberWeightedAbsorptionEnergy_eV = ...
    sum(numberWeights.*absorptionEnergy_eV);
ensemble.numberWeightedPLEnergy_eV = numberWeightedPLMean_eV;
ensemble.numberWeightedLambda2_nm = sum(numberWeights.*lambda2_nm);
ensemble.inhomogeneousPLEnergyStd_eV = emissionWeightedPLStd_eV;
ensemble.plWeightingMode = plWeightingMode;
ensemble.plPeakEnergy_eV = plPeakEnergy_eV;
ensemble.plPeakWavelength_nm = plPeakWavelength_nm;
ensemble.plMeanEnergy_eV = plMeanEnergy_eV;
ensemble.plMeanWavelength_nm = plMeanWavelength_nm;
ensemble.plFWHM_eV = plFWHMObserved_eV;
ensemble.plFWHM_nm = plFWHMObserved_nm;
ensemble.absorptionPeakEnergy_eV = absorptionPeakEnergy_eV;
ensemble.absorptionFWHM_eV = absorptionFWHMObserved_eV;

ensemble.spectrum = struct( ...
    'energy_eV',energy_eV, ...
    'wavelengthAscending_nm',wavelengthAscending_nm, ...
    'absorptionCrossSection_m2',absorptionCrossSection_m2, ...
    'absorptionLineIntrinsic_m2_per_eV', ...
        absorptionLineIntrinsic_m2_per_eV, ...
    'absorptionLineObserved_m2_per_eV', ...
        absorptionLineObserved_m2_per_eV, ...
    'absorptionLineObserved_m2_per_nm', ...
        absorptionLineObserved_m2_per_nm, ...
    'plProbabilityIntrinsic_per_eV',plProbabilityIntrinsic_per_eV, ...
    'plProbabilityObserved_per_eV',plProbabilityObserved_per_eV, ...
    'plProbabilityObserved_per_nm',plProbabilityObserved_per_nm, ...
    'bandEdgePLPhotonRateObserved_Hz_perDot_per_eV', ...
        plRateObserved_Hz_perDot_per_eV, ...
    'bandEdgePLPhotonRateObserved_Hz_perDot_per_nm', ...
        plRateObserved_Hz_perDot_per_nm, ...
    'bandEdgePLEpisodePhotonsObservedPerDot_per_eV', ...
        plEpisodeObserved_perDot_per_eV, ...
    'bandEdgePLEpisodePhotonsObservedPerDot_per_nm', ...
        plEpisodeObserved_perDot_per_nm, ...
    'unresolvedTrapEmissionPhotonRate_HzPerDot', ...
        sum(numberWeights.*trapEmissionRate_Hz), ...
    'unresolvedTrapEmissionPhotonCountExpectedPerDot', ...
        averageTrapEmissionPerDot, ...
    'instrumentFWHM_eV',options.InstrumentFWHM_eV);

ensemble.photonAccounting = struct( ...
    'numberOfDots',options.NumberOfDots, ...
    'deliveredIncidentPhotonCount',deliveredIncidentPhotonCount, ...
    'averageAbsorbedPhotonCountExpectedPerDot',averageAbsorbedPerDot, ...
    'averageEmittedPhotonCountExpectedPerDot',averageEmittedPerDot, ...
    'averageTrapEmissionPhotonCountExpectedPerDot', ...
        averageTrapEmissionPerDot, ...
    'totalAbsorbedPhotonCountExpected',totalAbsorbed, ...
    'totalEmittedPhotonCountExpected',totalEmitted, ...
    'totalTrapEmissionPhotonCountExpected',totalTrapEmission, ...
    'pumpDepletionIndicator',pumpDepletionIndicator, ...
    'pumpDepletionAssessment',pumpDepletionAssessment, ...
    'opticallyThinApproximationLikelyValid',opticallyThinLikelyValid);
if totalAbsorbed > 0
    ensemble.photonAccounting.episodeQuantumYield = ...
        totalEmitted/totalAbsorbed;
else
    ensemble.photonAccounting.episodeQuantumYield = 0;
end

ensemble.detector = struct( ...
    'collectionEfficiency',options.CollectionEfficiency, ...
    'opticalTransmission',options.OpticalTransmission, ...
    'detectorQuantumEfficiency',options.DetectorQuantumEfficiency, ...
    'combinedSignalDetectionEfficiency',detectionEfficiency, ...
    'exposureTime_ns',exposureTime_ns, ...
    'darkCountRate_Hz',options.DarkCountRate_Hz, ...
    'readNoiseElectronsRMS',options.ReadNoiseElectronsRMS, ...
    'detectorPixelCount',options.DetectorPixelCount, ...
    'excessNoiseFactor',options.ExcessNoiseFactor, ...
    'signalPhotoelectronCountExpected',signalDetected, ...
    'darkCountExpected',darkDetected, ...
    'totalDetectorCountExpected',detectedTotal, ...
    'poissonShotNoiseStd',poissonShotNoiseStd, ...
    'totalNoiseVariance',detectorVariance, ...
    'totalNoiseStd',detectorNoiseStd, ...
    'signalToNoiseRatio',signalToNoise, ...
    'countModel',['Each registered photon is treated as one primary ' ...
        'photoelectron before gain. Poisson signal/dark expectations use ' ...
        'an optional excess-noise variance multiplier and independent ' ...
        'Gaussian read-noise variance; no random sample, detector gain, ' ...
        'dead time, or saturation is modeled.']);

ensemble.validity = struct( ...
    'aggregateFlags',double(aggregateFlags), ...
    'warnings',{qdDecodeFlags(double(aggregateFlags))}, ...
    'numberWeightedModelConfidence',sum(numberWeights.*modelConfidence), ...
    'minimumMemberModelConfidence',min(modelConfidence), ...
    'opticalCalibrationWeightFraction',sum( ...
        numberWeights.*double(opticalInScope)), ...
    'plCalibrationWeightFraction',sum( ...
        numberWeights.*double(plInScope)), ...
    'kineticCalibrationWeightFraction',sum( ...
        numberWeights.*double(kineticsInScope)), ...
    'augerCalibrationWeightFraction',sum( ...
        numberWeights.*double(augerInScope)), ...
    'allMembersOpticallyInScope',all(opticalInScope), ...
    'allMembersPLInScope',all(plInScope), ...
    'allMembersKineticallyInScope',all(kineticsInScope));

ensemble.assumptions = struct( ...
    'independentNoninteractingDots',true, ...
    'uniformPumpAcrossEnsemble',true, ...
    'pumpDepletionIgnored',true, ...
    'reabsorptionIgnored',true, ...
    'energyTransferIgnored',true, ...
    'radiusCorrelationsWithOtherInputsIgnored',true, ...
    'instrumentResponse','Gaussian in photon-energy domain', ...
    'interpretation',['Size dispersion, instrument response, and detector ' ...
        'throughput are explicit assumptions, not fitted confidence intervals.']);

ensemble.memberSummary = table(radii_nm,numberWeights,emissionWeights, ...
    absorptionEnergy_eV,plEnergy_eV,lambda2_nm,plFWHM_eV, ...
    internalQuantumYield,effectiveLifetime_ns,absorbedPerDot, ...
    bandEdgeEmittedPerDot,trapEmissionPerDot,emittedPerDot,modelConfidence, ...
    double(memberFlags),opticalInScope,plInScope,kineticsInScope, ...
    augerInScope, ...
    'VariableNames',{'Radius_nm','NumberWeight','EmissionWeight', ...
    'AbsorptionEnergy_eV','PLEnergy_eV','Lambda2_nm','IntrinsicPLFWHM_eV', ...
    'InternalQuantumYield','EffectiveLifetime_ns', ...
    'AbsorbedPhotonCountExpectedPerDot', ...
    'BandEdgePhotonCountExpectedPerDot', ...
    'TrapEmissionPhotonCountExpectedPerDot', ...
    'TotalEmittedPhotonCountExpectedPerDot','ModelConfidence','ValidityFlags', ...
    'OpticalInScope','PLInScope','KineticsInScope','AugerInScope'});
if logical(options.ReturnMembers)
    ensemble.members = members;
end
end

function [nodes,weights] = localGaussLegendre(order)
% Golub-Welsch rule for integral f(x) dx on [-1,1].
indices = (1:order-1).';
offDiagonal = indices./sqrt(4*indices.^2-1);
jacobi = diag(offDiagonal,1)+diag(offDiagonal,-1);
[vectors,values] = eig(jacobi);
[nodes,sortIndices] = sort(diag(values));
vectors = vectors(:,sortIndices);
weights = 2*(vectors(1,:).^2).';
nodes = nodes(:);
end

function [nodes,weights] = localGaussHermite(order)
% Golub-Welsch rule for integral exp(-x^2) f(x) dx.
offDiagonal = sqrt((1:order-1)/2);
jacobi = diag(offDiagonal,1)+diag(offDiagonal,-1);
[vectors,values] = eig(jacobi);
[nodes,sortIndices] = sort(diag(values));
vectors = vectors(:,sortIndices);
weights = sqrt(pi)*(vectors(1,:).^2).';
nodes = nodes(:);
end

function probability = localNormalCDF(value)
probability = 0.5*erfc(-value/sqrt(2));
end

function [weights,mode] = localEmissionWeights(numberWeights,episode,rate,proxy)
candidates = {episode,rate,proxy,ones(size(numberWeights))};
modes = {'integrated emitted photons','instantaneous PL photon rate', ...
    'generation rate times internal quantum yield','number fraction'};
for k = 1:numel(candidates)
    candidate = max(0,candidates{k}(:));
    weighted = numberWeights.*candidate;
    if sum(weighted) > 0
        weights = weighted/sum(weighted);
        mode = modes{k};
        return
    end
end
weights = numberWeights/sum(numberWeights);
mode = 'number fraction';
end

function outputs = localAverageOutputs(members,weights,aggregateFlags)
names = qdOutputNames();
outputs = struct();
for fieldIndex = 1:numel(names)
    fieldName = names{fieldIndex};
    values = zeros(numel(members),1);
    for memberIndex = 1:numel(members)
        values(memberIndex) = members{memberIndex}.(fieldName);
    end
    if strcmp(fieldName,'validityFlags')
        outputs.(fieldName) = double(aggregateFlags);
    elseif strcmp(fieldName,'modelTier')
        if all(values == values(1))
            outputs.(fieldName) = values(1);
        else
            outputs.(fieldName) = NaN;
        end
    else
        outputs.(fieldName) = sum(weights.*values);
    end
end
end

function density = localGaussian(x,center,fwhm)
coefficient = 2*sqrt(log(2))/(max(fwhm,realmin)*sqrt(pi));
density = coefficient*exp(-4*log(2)*((x-center)/max(fwhm,realmin)).^2);
density = localNormalizeDensity(x,density);
end

function density = localNormalizeDensity(x,density)
area = trapz(x,density);
if area > 0
    density = density/area;
end
end

function broadened = localGaussianBroaden(x,density,fwhm)
if fwhm <= 0 || ~any(density)
    broadened = density;
    return
end
spacing = x(2)-x(1);
sigma = fwhm/(2*sqrt(2*log(2)));
halfWidth = min(numel(x)-1,max(1,ceil(6*sigma/spacing)));
kernelX = (-halfWidth:halfWidth).'*spacing;
kernel = exp(-0.5*(kernelX/sigma).^2);
kernel = kernel/sum(kernel);
broadened = conv(density,kernel,'same');
targetArea = trapz(x,density);
observedArea = trapz(x,broadened);
if targetArea > 0 && observedArea > 0
    broadened = broadened*(targetArea/observedArea);
end
end

function width = localFWHM(x,density)
[peak,peakIndex] = max(density);
if peak <= 0
    width = NaN;
    return
end
halfMaximum = peak/2;
leftIndex = find(density(1:peakIndex) <= halfMaximum,1,'last');
rightRelative = find(density(peakIndex:end) <= halfMaximum,1,'first');
if isempty(leftIndex) || isempty(rightRelative)
    width = NaN;
    return
end
rightIndex = peakIndex+rightRelative-1;
if leftIndex >= peakIndex || rightIndex <= peakIndex
    width = NaN;
    return
end
leftCrossing = localLinearCrossing(x(leftIndex:leftIndex+1), ...
    density(leftIndex:leftIndex+1),halfMaximum);
rightCrossing = localLinearCrossing(x(rightIndex-1:rightIndex), ...
    density(rightIndex-1:rightIndex),halfMaximum);
width = rightCrossing-leftCrossing;
end

function crossing = localLinearCrossing(x,y,target)
if y(2) == y(1)
    crossing = mean(x);
else
    crossing = x(1)+(target-y(1))*(x(2)-x(1))/(y(2)-y(1));
end
end
