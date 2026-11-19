function [plCenter_nm,plFWHM_nm,inScope] = ...
    qdCdSeEmitterReference(radius_nm)
%QDCdSeEMITTERREFERENCE Focused CdSe/ZnS emitter design reference.
%   Values reproduce the validated finite-barrier baseline used to design
%   the original 12-pixel model. PCHIP interpolation supports alternate
%   pixel counts over the documented 1.8-4.0 nm core-radius interval. This
%   is a synthetic design reference, not measured device calibration.

validateattributes(radius_nm,{'numeric'}, ...
    {'real','finite','vector','positive'},mfilename,'radius_nm');
radius_nm = radius_nm(:);
radiusNodes_nm = (1.8:0.2:4.0).';
centerNodes_nm = [ ...
    563.34995438746432;580.89195295040520;595.94266966802002; ...
    608.89032754880441;620.06814177772765;629.75624933256233; ...
    638.18792201573103;645.55667688059759;652.02296816415480; ...
    657.72002014723103;662.75872738013118;667.23169356567485];
inScope = radius_nm>=radiusNodes_nm(1) & radius_nm<=radiusNodes_nm(end);
if ~all(inScope)
    error('QDConverter:EmitterReferenceRange', ...
        'CdSe emitter radius must remain within 1.8-4.0 nm.');
end

plCenter_nm = interp1(radiusNodes_nm,centerNodes_nm,radius_nm,'pchip');
hc_eVnm = 1239.8419843320026;
temperature_K = 300;
loPhononEnergy_eV = 0.026;
boltzmann_eV_K = 8.617333262e-5;
plFWHM_eV = max(0.025,0.045+1.2e-4*temperature_K+ ...
    0.020/expm1(loPhononEnergy_eV/(boltzmann_eV_K*temperature_K)));
plFWHM_nm = plFWHM_eV*plCenter_nm.^2/hc_eVnm;
end
