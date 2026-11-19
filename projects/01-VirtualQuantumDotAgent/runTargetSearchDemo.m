function solution = runTargetSearchDemo(targetEmission_eV)
%RUNTARGETSEARCHDEMO Demonstrate the closed-loop radius-design agent.
if nargin < 1
    targetEmission_eV = 2.0;
end
solution = optimizeQDTarget(targetEmission_eV,'RadiusBounds_nm',[1.5 10]);
fprintf('\nVirtual quantum-dot inverse design\n');
fprintf('Target emission : %.6f eV\n',solution.targetEmission_eV);
fprintf('Core radius     : %.6f nm\n',solution.radius_nm);
fprintf('Prediction      : %.6f eV (%.3f nm)\n', ...
    solution.predictedEmission_eV,solution.predictedWavelength_nm);
fprintf('Absolute error  : %.6g eV\n',solution.absoluteError_eV);
fprintf('Reachable       : %d\n',solution.reachableWithinBounds);
fprintf('Converged       : %d\n\n',solution.converged);
end
