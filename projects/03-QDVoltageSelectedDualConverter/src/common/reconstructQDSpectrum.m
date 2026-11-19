function reconstruction = reconstructQDSpectrum(measuredElectrons,response,varargin)
%RECONSTRUCTQDSPECTRUM Nonnegative smooth spectral reconstruction.
%   R = RECONSTRUCTQDSPECTRUM(Y,RESPONSE) solves
%
%      min_{s >= 0} 0.5*||W(A*s-(Y-dark))||_2^2
%                     + 0.5*alpha^2*||diff(s)||_2^2
%
%   with projected FISTA. It requires no Optimization Toolbox.
%
%   RESPONSE may be a qdBuildSpectralResponse structure or a numeric M-by-N
%   detector response matrix.

parser = inputParser;
parser.FunctionName = 'reconstructQDSpectrum';
addParameter(parser,'DarkElectrons',[], ...
    @(x)isempty(x)||(isnumeric(x)&&isvector(x)&&isreal(x)&&all(isfinite(x(:)))));
addParameter(parser,'NoiseVariance',[], ...
    @(x)isempty(x)||(isnumeric(x)&&isvector(x)&&isreal(x)&& ...
    all(isfinite(x(:)))&&all(x(:)>0)));
addParameter(parser,'Regularization',0.020, ...
    @(x)isnumeric(x)&&isscalar(x)&&isreal(x)&&isfinite(x)&&x>=0);
addParameter(parser,'MaxIterations',3000, ...
    @(x)isnumeric(x)&&isscalar(x)&&isreal(x)&&isfinite(x)&& ...
    x==fix(x)&&x>=1);
addParameter(parser,'RelativeTolerance',1e-5, ...
    @(x)isnumeric(x)&&isscalar(x)&&isreal(x)&&isfinite(x)&&x>0);
addParameter(parser,'InitialSpectrum',[], ...
    @(x)isempty(x)||(isnumeric(x)&&isvector(x)&&isreal(x)&& ...
    all(isfinite(x(:)))&&all(x(:)>=0)));
parse(parser,varargin{:});
options = parser.Results;

if isstruct(response)
    matrix = response.systemMatrix_electronsPerIncidentPhoton;
    defaultDark = response.darkElectronsExpected;
    if isfield(response,'inputWavelength_nm')
        wavelength_nm = response.inputWavelength_nm(:);
    else
        wavelength_nm = (1:size(matrix,2)).';
    end
elseif isnumeric(response) && ismatrix(response) && isreal(response) && ...
        all(isfinite(response(:)))
    matrix = response;
    defaultDark = zeros(size(matrix,1),1);
    wavelength_nm = (1:size(matrix,2)).';
else
    error('QDConverter:ReconstructionResponse', ...
        'Response must be a response structure or finite numeric matrix.');
end
if any(matrix(:)<0)
    error('QDConverter:ReconstructionResponse', ...
        'Detector response matrix must be nonnegative.');
end

measurement = measuredElectrons(:);
measurementCount = size(matrix,1);
spectrumCount = size(matrix,2);
if numel(measurement)~=measurementCount || any(~isfinite(measurement))
    error('QDConverter:ReconstructionMeasurement', ...
        'Measurement must contain one finite value per response row.');
end
if isempty(options.DarkElectrons)
    dark = defaultDark(:);
else
    dark = options.DarkElectrons(:);
end
if numel(dark)~=measurementCount
    error('QDConverter:ReconstructionDark', ...
        'Dark vector must contain one value per response row.');
end

data = max(0,measurement-dark);
if isempty(options.NoiseVariance)
    rowWeight = ones(measurementCount,1);
else
    noiseVariance = options.NoiseVariance(:);
    if numel(noiseVariance)~=measurementCount
        error('QDConverter:ReconstructionNoise', ...
            'NoiseVariance must contain one value per response row.');
    end
    rowWeight = 1./sqrt(noiseVariance);
    % Retain a dimensionless, well-scaled weighting convention.
    rowWeight = rowWeight/median(rowWeight);
end
weightedMatrix = rowWeight.*matrix;
weightedData = rowWeight.*data;

% Scale the detector matrix, data, and smoothness operator together. This
% makes alpha dimensionless and stable when an absolute calibration changes
% the electrons-per-photon magnitude.
matrixScale = norm(weightedMatrix,'fro')/sqrt(max(1,numel(weightedMatrix)));
if matrixScale<=realmin
    reconstruction = localZeroResult(wavelength_nm,measurement,dark,matrix, ...
        options.Regularization);
    return
end
weightedMatrix = weightedMatrix/matrixScale;
weightedData = weightedData/matrixScale;

if spectrumCount>1
    differenceOperator = spdiags([-ones(spectrumCount,1), ...
        ones(spectrumCount,1)],[0 1],spectrumCount-1,spectrumCount);
    wavelengthStep = median(diff(wavelength_nm));
    if isfinite(wavelengthStep) && wavelengthStep>0
        differenceOperator = wavelengthStep*differenceOperator/ ...
            (wavelength_nm(end)-wavelength_nm(1));
    end
else
    differenceOperator = sparse(0,1);
end
alpha = options.Regularization;
hessian = weightedMatrix.'*weightedMatrix+ ...
    alpha^2*(differenceOperator.'*differenceOperator);
linearTerm = weightedMatrix.'*weightedData;

% The spectral norm is exact and inexpensive for the delivered 48-bin
% model. A small floor handles a degenerate measured response gracefully.
lipschitz = max(norm(hessian,2),eps);
if isempty(options.InitialSpectrum)
    diagonalScale = max(diag(hessian),eps);
    current = max(0,linearTerm./diagonalScale);
else
    current = options.InitialSpectrum(:);
    if numel(current)~=spectrumCount
        error('QDConverter:ReconstructionInitial', ...
            'InitialSpectrum must contain one value per spectral bin.');
    end
end
accelerated = current;
momentum = 1;
converged = false;

for iteration = 1:options.MaxIterations
    gradient = hessian*accelerated-linearTerm;
    next = max(0,accelerated-gradient/lipschitz);
    nextMomentum = 0.5*(1+sqrt(1+4*momentum^2));
    nextAccelerated = next+((momentum-1)/nextMomentum)*(next-current);
    relativeChange = norm(next-current)/max(1,norm(current));
    current = next;
    accelerated = nextAccelerated;
    momentum = nextMomentum;
    if relativeChange<=options.RelativeTolerance
        converged = true;
        break
    end
end

predictedSignal = matrix*current;
predictedMeasurement = predictedSignal+dark;
residual = measurement-predictedMeasurement;
smoothness = differenceOperator*current;
weightedResidual = rowWeight.*(matrix*current-data);
objective = 0.5*sum((weightedResidual/matrixScale).^2)+ ...
    0.5*alpha^2*sum(smoothness.^2);

reconstruction = struct();
reconstruction.wavelength_nm = wavelength_nm;
reconstruction.incidentPhotonsPerBin = current;
reconstruction.predictedSignalElectrons = predictedSignal;
reconstruction.predictedMeasurementElectrons = predictedMeasurement;
reconstruction.residualElectrons = residual;
reconstruction.weightedResidualNorm = norm(weightedResidual);
reconstruction.regularization = alpha;
reconstruction.objective = objective;
reconstruction.iterations = iteration;
reconstruction.converged = converged;
reconstruction.nonnegative = all(current>=0);
reconstruction.activeBinCount = nnz(current>0);
reconstruction.matrixScale = matrixScale;
reconstruction.responseNumericalRank = rank(matrix);
end

function result = localZeroResult(wavelength,measurement,dark,matrix,alpha)
result = struct();
result.wavelength_nm = wavelength;
result.incidentPhotonsPerBin = zeros(size(matrix,2),1);
result.predictedSignalElectrons = zeros(size(matrix,1),1);
result.predictedMeasurementElectrons = dark;
result.residualElectrons = measurement-dark;
result.weightedResidualNorm = norm(measurement-dark);
result.regularization = alpha;
result.objective = 0.5*sum((measurement-dark).^2);
result.iterations = 0;
result.converged = true;
result.nonnegative = true;
result.activeBinCount = 0;
result.matrixScale = 0;
result.responseNumericalRank = 0;
end
