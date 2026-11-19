function [augerRate_Hz,augerLifetime_ps,geometryInScope] = ...
    qdPbSCdSAugerModel(coreDiameter_nm,shellThickness_nm)
%QDPBSCDSAUGERMODEL Provisional PbS/CdS biexciton Auger calibration.
%#codegen
%   A bilinear lifetime model was fitted to 13 Table-2 rows spanning three
%   independent cation-exchange series from Stylianou et al., Nano Letters
%   (2026), DOI 10.1021/acs.nanolett.6c00158. Whole-series leave-one-out
%   RMSE is 8.9463 ps. The geometry gate is the convex hull of the measured
%   outer-diameter/shell-thickness points, not a rectangular extrapolation.

outerDiameter_nm = coreDiameter_nm+2.0*shellThickness_nm;
augerLifetime_ps = -36.9957696542972+ ...
    28.4309299423043*outerDiameter_nm+ ...
    813.382931876789*shellThickness_nm- ...
    84.7825604665947*outerDiameter_nm*shellThickness_nm;
augerLifetime_ps = max(1.0,augerLifetime_ps);
augerRate_Hz = 1.0e12/augerLifetime_ps;

% Counter-clockwise convex hull in (outer diameter nm, shell nm).
hullD = [6.16;6.18;7.63;7.69;7.64];
hullT = [0.42;0.00;0.00;0.50;0.84];
geometryInScope = coreDiameter_nm >= 5.32-1e-12 && ...
    coreDiameter_nm <= 7.63+1e-12 && ...
    shellThickness_nm >= -1e-12 && shellThickness_nm <= 0.84+1e-12 && ...
    outerDiameter_nm >= 6.16-1e-12 && outerDiameter_nm <= 7.69+1e-12;
if geometryInScope
    for k = 1:5
        next = k+1;
        if next == 6
            next = 1;
        end
        crossProduct = (hullD(next)-hullD(k))* ...
            (shellThickness_nm-hullT(k))- ...
            (hullT(next)-hullT(k))*(outerDiameter_nm-hullD(k));
        if crossProduct < -1e-10
            geometryInScope = false;
            break
        end
    end
end
end
