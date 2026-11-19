function result = qdBrusReference(radius_nm,temperature_K,materialID)
%QDBRUSREFERENCE Exact infinite-barrier regression model.
%   This function intentionally omits dielectric polarization, finite
%   barriers and Stokes shift. It supplies traceable analytic test values.

if nargin < 1, radius_nm = 3; end
if nargin < 2, temperature_K = 300; end
if nargin < 3, materialID = 1; end
if radius_nm <= 0 || temperature_K < 0
    error('VirtualQD:InvalidReferenceInput','Radius must be positive and temperature nonnegative.');
end

hbar = 1.054571817e-34;
electronCharge = 1.602176634e-19;
electronMass = 9.1093837015e-31;
epsilon0 = 8.8541878128e-12;
hc_eVnm = 1239.841984332;

v = qdMaterialVector(materialID);
R = radius_nm*1e-9;
Eg = v(1)-v(2)*temperature_K^2/(temperature_K+v(3));
Ee = hbar^2*pi^2/(2*v(4)*electronMass*R^2)/electronCharge;
Eh = hbar^2*pi^2/(2*v(5)*electronMass*R^2)/electronCharge;
J = 1.786*electronCharge/(4*pi*epsilon0*v(6)*R);
EX = Eg+Ee+Eh-J;

result = struct( ...
    'radius_nm',radius_nm, ...
    'temperature_K',temperature_K, ...
    'bulkBandgap_eV',Eg, ...
    'electronConfinement_eV',Ee, ...
    'holeConfinement_eV',Eh, ...
    'coulombCorrection_eV',J, ...
    'transitionEnergy_eV',EX, ...
    'wavelength_nm',hc_eVnm/EX);
end
