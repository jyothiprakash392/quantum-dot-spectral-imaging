function prediction = predictQDHybrid(qdInput,varargin)
%PREDICTQDHYBRID Physics prediction with small-data ML protocol adaptation.
%   P = PREDICTQDHYBRID(INPUTS) uses an unknown-protocol ensemble for an
%   in-scope CsPbBr3 absorption prediction. Specify OpticalProtocol as
%   'brennan2017', 'mondal2019', or 'unknown'. Other material IDs fall back
%   to their validated physics/empirical model because there are not enough
%   independent labels for a defensible learner.
%
%   The Mondal correction was selected on four development sizes and scored
%   once on three untouched sizes. It is a synthesis-protocol adaptation,
%   not a universal CsPbBr3 correction. No cross-protocol PL residual model
%   is fitted, so lambda2 remains the source-calibrated PL prediction.

if nargin < 1 || isempty(qdInput)
    qdInput = qdDefaultInputs();
elseif isnumeric(qdInput) && isscalar(qdInput)
    defaults = qdDefaultInputs();
    defaults.radius_nm = qdInput;
    qdInput = defaults;
elseif ~isstruct(qdInput)
    error('VirtualQD:HybridInput', ...
        'First input must be a qdInput structure or scalar radius in nm.');
end

parser = inputParser;
parser.FunctionName = 'predictQDHybrid';
addParameter(parser,'OpticalProtocol','unknown', ...
    @(x)ischar(x)||(isstring(x)&&isscalar(x)));
addParameter(parser,'NumberOfSamples',400, ...
    @(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=100&&x==round(x));
parse(parser,varargin{:});

protocol = lower(strtrim(char(string(parser.Results.OpticalProtocol))));
if any(strcmp(protocol,{'auto','consensus'}))
    protocol = 'unknown';
elseif any(strcmp(protocol,{'source','brennan'}))
    protocol = 'brennan2017';
elseif strcmp(protocol,'mondal')
    protocol = 'mondal2019';
end
allowed = {'unknown','brennan2017','mondal2019'};
if ~any(strcmp(protocol,allowed))
    error('VirtualQD:OpticalProtocol', ...
        'OpticalProtocol must be unknown, brennan2017, or mondal2019.');
end

base = predictQDWithError(qdInput,parser.Results.NumberOfSamples);
nominal = base.nominal;
materialID = round(base.inputs.materialID);
sourceEnergy_eV = nominal.absorptionEnergy_eV;
hc_eVnm = 1239.841984332;

% Development-only-selected constant residual for the Mondal-2019 series.
mondalResidual_eV = -0.0667159090909091;
mondalHoldoutRMSE_eV = 0.0370127080356124;
sourceCrossBatchRMSE_eV = 0.0695873611113849;
edge_nm = nominal.calibration.sourceSize_nm;
mondalInScope = materialID == 4 && nominal.calibration.opticalInScope && ...
    edge_nm >= 3.0-1e-9 && edge_nm <= 6.2+1e-9 && ...
    nominal.effectiveInputs.temperature_K >= 293 && ...
    nominal.effectiveInputs.temperature_K <= 300;

mondalEnergy_eV = sourceEnergy_eV+mondalResidual_eV;
active = false;
if materialID ~= 4
    selectedEnergy_eV = sourceEnergy_eV;
    selectedModel = 'physics/empirical fallback';
    evidence = ['No independent in-scope residual dataset is large enough ' ...
        'for a defensible ML correction for this material ID.'];
    modelErrorScale_eV = NaN;
    modelLow_eV = NaN;
    modelHigh_eV = NaN;
elseif strcmp(protocol,'brennan2017')
    selectedEnergy_eV = sourceEnergy_eV;
    selectedModel = 'Brennan-2017 source-calibrated physics hybrid';
    evidence = ['Direct source-table calibration; the separate Mondal-2019 ' ...
        'batch has 0.0696 eV cross-batch RMSE.'];
    modelErrorScale_eV = sourceCrossBatchRMSE_eV;
    modelLow_eV = sourceEnergy_eV-sourceCrossBatchRMSE_eV;
    modelHigh_eV = sourceEnergy_eV+sourceCrossBatchRMSE_eV;
elseif strcmp(protocol,'mondal2019') && mondalInScope
    selectedEnergy_eV = mondalEnergy_eV;
    selectedModel = 'Mondal-2019 protocol residual learner';
    evidence = ['Constant residual selected by development-only LOOCV; ' ...
        'three untouched sizes have 0.0370 eV RMSE.'];
    modelErrorScale_eV = mondalHoldoutRMSE_eV;
    modelLow_eV = mondalEnergy_eV-mondalHoldoutRMSE_eV;
    modelHigh_eV = mondalEnergy_eV+mondalHoldoutRMSE_eV;
    active = true;
elseif strcmp(protocol,'mondal2019')
    selectedEnergy_eV = sourceEnergy_eV;
    selectedModel = 'physics/empirical fallback';
    evidence = ['Mondal-2019 residual learner is outside its 3.0--6.2 nm, ' ...
        '293--300 K, bare-cube scope and was not extrapolated.'];
    modelErrorScale_eV = NaN;
    modelLow_eV = NaN;
    modelHigh_eV = NaN;
else
    % With unknown synthesis protocol, the midpoint minimizes the maximum
    % squared disagreement between the two supported protocol estimates.
    if mondalInScope
        selectedEnergy_eV = 0.5*(sourceEnergy_eV+mondalEnergy_eV);
        selectedModel = 'two-protocol robust midpoint';
        evidence = ['Protocol is unknown. The midpoint is a robust ensemble ' ...
            'of Brennan-2017 and Mondal-2019 estimates, not a calibrated CI.'];
        modelErrorScale_eV = max(sourceCrossBatchRMSE_eV, ...
            mondalHoldoutRMSE_eV);
        modelLow_eV = min(sourceEnergy_eV-sourceCrossBatchRMSE_eV, ...
            mondalEnergy_eV-mondalHoldoutRMSE_eV);
        modelHigh_eV = max(sourceEnergy_eV+sourceCrossBatchRMSE_eV, ...
            mondalEnergy_eV+mondalHoldoutRMSE_eV);
        active = true;
    else
        selectedEnergy_eV = sourceEnergy_eV;
        selectedModel = 'physics/empirical fallback';
        evidence = ['No second in-scope protocol estimate is available at ' ...
            'these inputs.'];
        modelErrorScale_eV = NaN;
        modelLow_eV = NaN;
        modelHigh_eV = NaN;
    end
end

prediction = struct();
prediction.inputs = base.inputs;
prediction.nominal = nominal;
prediction.requestedOpticalProtocol = protocol;
prediction.selectedModel = selectedModel;
prediction.mlOpticalAdaptationActive = active;
prediction.absorptionEnergy_eV = selectedEnergy_eV;
prediction.absorptionWavelength_nm = hc_eVnm/selectedEnergy_eV;
prediction.sourceProtocolAbsorptionEnergy_eV = sourceEnergy_eV;
prediction.mondalProtocolAbsorptionEnergy_eV = mondalEnergy_eV;
prediction.mondalProtocolInScope = mondalInScope;
prediction.learnedMondalResidual_eV = mondalResidual_eV;
prediction.modelErrorScale_eV = modelErrorScale_eV;
prediction.modelFormEnvelopeLow_eV = modelLow_eV;
prediction.modelFormEnvelopeHigh_eV = modelHigh_eV;
appliedCorrection_eV = selectedEnergy_eV-sourceEnergy_eV;
prediction.appliedAbsorptionCorrection_eV = appliedCorrection_eV;
prediction.inputScenarioLow_eV = base.scenarioLow95_eV+appliedCorrection_eV;
prediction.inputScenarioHigh_eV = base.scenarioHigh95_eV+appliedCorrection_eV;
if isfinite(modelLow_eV)
    prediction.engineeringEnvelopeLow_eV = min(modelLow_eV, ...
        prediction.inputScenarioLow_eV);
    prediction.engineeringEnvelopeHigh_eV = max(modelHigh_eV, ...
        prediction.inputScenarioHigh_eV);
else
    prediction.engineeringEnvelopeLow_eV = prediction.inputScenarioLow_eV;
    prediction.engineeringEnvelopeHigh_eV = prediction.inputScenarioHigh_eV;
end
prediction.engineeringEnvelopeLow_nm = ...
    hc_eVnm/prediction.engineeringEnvelopeHigh_eV;
prediction.engineeringEnvelopeHigh_nm = ...
    hc_eVnm/prediction.engineeringEnvelopeLow_eV;
prediction.evidence = evidence;
prediction.intervalInterpretation = ['Union of the seeded input-sensitivity ' ...
    'scenario and available protocol/model-form error scale. It is an ' ...
    'engineering envelope, not a formal confidence interval or universal bound.'];

% PL/lambda2 remains a separate observable. Moving it by an absorption-only
% residual would fabricate a Stokes relation that was never measured.
prediction.plEnergy_eV = nominal.plEnergy_eV;
prediction.lambda2_nm = nominal.lambda2_nm;
prediction.emissionWavelength_nm = nominal.emissionWavelength_nm;
prediction.mlPLAdaptationActive = false;
prediction.plAdaptationReason = ['No sufficiently large paired same-protocol ' ...
    'PL dataset; lambda2 remains the source-calibrated physics prediction.'];

prediction.kinetics = struct( ...
    'model','physics-constrained cubic ridge learner', ...
    'active',materialID == 4 && nominal.calibration.kineticsInScope, ...
    'conditionalOnPLEnergy',materialID == 4, ...
    'endToEndSizeToKineticsValidated',false, ...
    'radiativeRate_Hz',nominal.radiativeRate_Hz, ...
    'nonradiativeRate_Hz',nominal.nonradiativeRate_Hz, ...
    'totalLifetime_ns',nominal.effectiveLifetime_ns, ...
    'plqy',nominal.internalQuantumYield, ...
    'errorMetrics',nominal.calibration.errorMetrics, ...
    'interpretation',['Kinetic errors are conditional on PL energy. Size-to-' ...
        'PL uncertainty is not included in those held-out rate metrics.']);
prediction.basePredictionWithError = base;
end
