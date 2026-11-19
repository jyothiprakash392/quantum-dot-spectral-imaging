function solution = optimizeQDTarget(targetEmission_eV,varargin)
%OPTIMIZEQDTARGET Closed-loop inverse design of core radius.
%   SOLUTION = OPTIMIZEQDTARGET(2.0,'Temperature_K',300)

if ~isnumeric(targetEmission_eV) || ~isscalar(targetEmission_eV) || targetEmission_eV <= 0
    error('VirtualQD:InvalidTarget','Target emission energy must be a positive scalar in eV.');
end

inputs = qdDefaultInputs();
parser = inputParser;
addParameter(parser,'Temperature_K',inputs.temperature_K,@isscalar);
addParameter(parser,'ElectricField_kVcm',inputs.electricField_kVcm,@isscalar);
addParameter(parser,'HydrostaticStrain_pct',inputs.hydrostaticStrain_pct,@isscalar);
addParameter(parser,'ShellThickness_nm',inputs.shellThickness_nm,@isscalar);
addParameter(parser,'EnvironmentDielectric',inputs.environmentDielectric,@isscalar);
addParameter(parser,'ElectronBarrier_eV',inputs.electronBarrier_eV,@isscalar);
addParameter(parser,'HoleBarrier_eV',inputs.holeBarrier_eV,@isscalar);
addParameter(parser,'MaterialID',inputs.materialID,@isscalar);
addParameter(parser,'RadiusBounds_nm',[1.5 10],@(x)isnumeric(x)&&numel(x)==2&&x(1)>0&&x(2)>x(1));
parse(parser,varargin{:});

inputs.temperature_K = parser.Results.Temperature_K;
inputs.electricField_kVcm = parser.Results.ElectricField_kVcm;
inputs.hydrostaticStrain_pct = parser.Results.HydrostaticStrain_pct;
inputs.shellThickness_nm = parser.Results.ShellThickness_nm;
inputs.environmentDielectric = parser.Results.EnvironmentDielectric;
inputs.electronBarrier_eV = parser.Results.ElectronBarrier_eV;
inputs.holeBarrier_eV = parser.Results.HoleBarrier_eV;
inputs.materialID = parser.Results.MaterialID;
inputs.targetEmission_eV = targetEmission_eV;
bounds = parser.Results.RadiusBounds_nm(:).';

energyAtLow = localEnergy(bounds(1),inputs);
energyAtHigh = localEnergy(bounds(2),inputs);
reachable = targetEmission_eV >= min(energyAtLow,energyAtHigh) && ...
    targetEmission_eV <= max(energyAtLow,energyAtHigh);

objective = @(radius) abs(localEnergy(radius,inputs)-targetEmission_eV);
options = optimset('TolX',1e-7,'Display','off','MaxIter',150);
[radius_nm,error_eV,exitflag,output] = fminbnd(objective,bounds(1),bounds(2),options);
inputs.radius_nm = radius_nm;
finalResult = simulateQD(inputs,'Duration_ns',50);

solution = struct( ...
    'targetEmission_eV',targetEmission_eV, ...
    'radius_nm',radius_nm, ...
    'predictedEmission_eV',finalResult.plEnergy_eV, ...
    'predictedWavelength_nm',finalResult.emissionWavelength_nm, ...
    'absoluteError_eV',error_eV, ...
    'reachableWithinBounds',reachable, ...
    'converged',exitflag>0 && error_eV<5e-3, ...
    'iterations',output.iterations, ...
    'radiusBounds_nm',bounds, ...
    'result',finalResult);
end

function energy = localEnergy(radius_nm,inputs)
inputs.radius_nm = radius_nm;
u = qdPackInputs(inputs);
[y,~] = qdPhysicsStep(u,[1;0;0;0]);
energy = y(9);
end
