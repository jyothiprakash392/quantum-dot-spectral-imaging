function reference = qdCdSeEmpiricalReferences(diameter_nm)
%QCDSEEMPIRICALREFERENCES Published bare-core CdSe sizing relationships.
%   REFERENCE = QDCDSEEMPIRICALREFERENCES(DIAMETER_NM) evaluates three
%   independent room-temperature, first-exciton absorption calibrations for
%   organically capped CdSe cores. DIAMETER_NM is particle diameter, not
%   radius. These empirical relationships are comparison references; they
%   are not a microscopic CdSe/ZnS core-shell model.
%
%   Sources:
%   Yu et al., Chem. Mater. 15, 2854 (2003), DOI 10.1021/cm034081k
%   Jasieniak et al., J. Phys. Chem. C 113, 19468 (2009),
%       DOI 10.1021/jp906827m
%   de Mello Donega and Koole, J. Phys. Chem. C 113, 6511 (2009),
%       DOI 10.1021/jp811329r

validateattributes(diameter_nm,{'numeric'},{'real','finite','positive'});
diameter_nm = diameter_nm(:);
if any(diameter_nm < 2 | diameter_nm > 8)
    error('VirtualQD:EmpiricalReferenceDomain', ...
        ['The shared comparison domain is diameter 2-8 nm. Values outside ' ...
        'that interval would extrapolate at least one published relation.']);
end
hc_eVnm = 1239.841984332;
nPoints = numel(diameter_nm);

yuWavelength_nm = zeros(nPoints,1);
jasieniakWavelength_nm = zeros(nPoints,1);
for k = 1:nPoints
    diameter = diameter_nm(k);
    yuWavelength_nm(k) = fzero( ...
        @(lambda)localYuDiameter(lambda)-diameter,[400 750]);
    jasieniakWavelength_nm(k) = fzero( ...
        @(lambda)localJasieniakDiameter(lambda)-diameter,[400 750]);
end

yuEnergy_eV = hc_eVnm./yuWavelength_nm;
jasieniakEnergy_eV = hc_eVnm./jasieniakWavelength_nm;
donegaEnergy_eV = localDonegaEnergy(diameter_nm);
donegaWavelength_nm = hc_eVnm./donegaEnergy_eV;

allEnergy = [yuEnergy_eV,jasieniakEnergy_eV,donegaEnergy_eV];
referenceMeanEnergy_eV = mean(allEnergy,2);
referenceMinEnergy_eV = min(allEnergy,[],2);
referenceMaxEnergy_eV = max(allEnergy,[],2);
interCurveSpread_eV = referenceMaxEnergy_eV-referenceMinEnergy_eV;

% de Mello Donega and Koole report about 2% diameter uncertainty for CdSe
% diameters from 2-12 nm. Convert that input uncertainty locally to energy.
donegaEnergyAtLowDiameter_eV = localDonegaEnergy(0.98*diameter_nm);
donegaEnergyAtHighDiameter_eV = localDonegaEnergy(1.02*diameter_nm);
donegaDiameterUncertaintyHalfWidth_eV = 0.5*abs( ...
    donegaEnergyAtLowDiameter_eV-donegaEnergyAtHighDiameter_eV);

reference = table( ...
    diameter_nm,diameter_nm/2, ...
    yuWavelength_nm,yuEnergy_eV, ...
    jasieniakWavelength_nm,jasieniakEnergy_eV, ...
    donegaWavelength_nm,donegaEnergy_eV, ...
    referenceMeanEnergy_eV,referenceMinEnergy_eV,referenceMaxEnergy_eV, ...
    interCurveSpread_eV,donegaDiameterUncertaintyHalfWidth_eV, ...
    'VariableNames',{ ...
    'Diameter_nm','Radius_nm','YuWavelength_nm','YuEnergy_eV', ...
    'JasieniakWavelength_nm','JasieniakEnergy_eV', ...
    'DonegaWavelength_nm','DonegaEnergy_eV','ReferenceMeanEnergy_eV', ...
    'ReferenceMinEnergy_eV','ReferenceMaxEnergy_eV','InterCurveSpread_eV', ...
    'DonegaDiameterUncertaintyHalfWidth_eV'});
end

function diameter_nm = localYuDiameter(lambda_nm)
diameter_nm = 1.6122e-9*lambda_nm.^4-2.6575e-6*lambda_nm.^3+ ...
    1.6242e-3*lambda_nm.^2-0.4277*lambda_nm+41.57;
end

function diameter_nm = localJasieniakDiameter(lambda_nm)
diameter_nm = 59.60816-0.54736*lambda_nm+1.8873e-3*lambda_nm.^2- ...
    2.85743e-6*lambda_nm.^3+1.62974e-9*lambda_nm.^4;
end

function energy_eV = localDonegaEnergy(diameter_nm)
energy_eV = 1.858+1./(0.220*diameter_nm.^2+0.008*diameter_nm+0.373);
end
