function [radiativeRate_Hz,nonradiativeRate_Hz,totalLifetime_ns,plqy] = ...
    qdCsPbBr3RateModel(plEnergy_eV)
%QDCSPBBR3RATEMODEL Physics-constrained CsPbBr3 kinetic learner.
%#codegen
%   Cubic ridge regressions predict the two measured observables--total PL
%   lifetime and PL quantum yield--from PL energy. Rates are then derived as
%   kr = QY/tau and knr = (1-QY)/tau, preserving nonnegativity, rate closure,
%   and 0 <= QY <= 1. The ridge penalty was selected using leave-one-energy-
%   group-out validation on 25 development rows from Abbas et al. (2025),
%   DOI 10.1038/s41467-025-60848-5. Nine predeclared energy-grouped rows
%   remain the frozen evaluation set reported by qdCalibrationStatus.

z = (plEnergy_eV-2.52)/0.1;
z2 = z*z;
z3 = z2*z;
totalLifetime_ns = 3.183780018375221+ ...
    0.25057345676543119*z+1.2345240813129643*z2- ...
    0.58043503257099538*z3;
plqy = 0.94968446323147371+0.056978284696460949*z+ ...
    0.048363733662658483*z2-0.074033041351858522*z3;

% Defensive extrapolation constraints. Neither clamp activates over the
% declared 2.445466802--2.654928626 eV calibration envelope.
totalLifetime_ns = max(0.05,totalLifetime_ns);
plqy = min(1,max(0,plqy));
radiativeRate_nsInv = plqy/totalLifetime_ns;
nonradiativeRate_nsInv = (1-plqy)/totalLifetime_ns;
radiativeRate_Hz = radiativeRate_nsInv*1.0e9;
nonradiativeRate_Hz = nonradiativeRate_nsInv*1.0e9;
end
