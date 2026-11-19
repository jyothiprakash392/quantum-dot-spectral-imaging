function [absorptionEnergy_eV,plEnergy_eV,stokesShift_eV,sourceSize_nm] = ...
    qdEmpiricalMaterialReference(materialID,radius_nm,temperature_K)
%QDEMPIRICALMATERIALREFERENCE Published optical anchors for material IDs 2-4.
%#codegen
%   ID 2 sourceSize_nm is the edge of the source's approximately regular
%   tetrahedral InP core. radius_nm is the equal-volume-sphere radius. The
%   absorption relation is Almeida et al. (2023),
%   DOI 10.1021/acs.nanolett.3c02630. PL remains uncalibrated unless the
%   caller supplies a measured Stokes shift.
%
%   ID 3 sourceSize_nm is PbS core diameter. The first-exciton absorption
%   relation is Moreels et al. (2009), DOI 10.1021/nn900863a.
%
%   ID 4 sourceSize_nm is CsPbBr3 nanocube edge length. radius_nm is the
%   radius of an equal-volume sphere. Absorption, PL, and Stokes shift use
%   the primary SI checkpoints of Brennan et al. (2017),
%   DOI 10.1021/jacs.7b05683. See qdCalibrationStatus for error levels.

id = round(materialID);
sourceSize_nm = 2.0*radius_nm;
absorptionEnergy_eV = 0.01;
plEnergy_eV = 0.01;
stokesShift_eV = 0;

if id == 2
    volume_nm3 = (4.0/3.0)*pi*radius_nm^3;
    sourceSize_nm = (6.0*sqrt(2.0)*volume_nm3)^(1.0/3.0);
    absorptionEnergy_eV = 1.33+1.219/max(volume_nm3^0.251,realmin);
    stokesShift_eV = 0.040;
    plEnergy_eV = max(0.01,absorptionEnergy_eV-stokesShift_eV);

elseif id == 3
    diameter_nm = sourceSize_nm;
    denominator = 0.0252*diameter_nm^2+0.283*diameter_nm;
    absorptionEnergy_eV = 0.410+1.0/max(denominator,realmin);
    stokesShift_eV = 0.020;
    plEnergy_eV = max(0.01,absorptionEnergy_eV-stokesShift_eV);

elseif id == 4
    equalVolumeFactor = (3.0/(4.0*pi))^(1.0/3.0);
    sourceSize_nm = radius_nm/equalVolumeFactor;
    edge_nm = [3.0;4.1;4.5;5.5;6.2;6.8;7.9;9.2;11.7;12.8];
    absorption_eV = [2.853;2.711;2.670;2.599;2.554; ...
        2.530;2.476;2.462;2.455;2.415];
    emission_eV = [2.739;2.618;2.587;2.525;2.496; ...
        2.480;2.427;2.422;2.420;2.398];
    absorptionEnergy_eV = localLinearInterpolation( ...
        sourceSize_nm,edge_nm,absorption_eV);
    plEnergy_eV = localLinearInterpolation(sourceSize_nm,edge_nm,emission_eV);
    % Near-ambient band-gap slope reported for approximately 8 nm cubes.
    temperatureShift_eV = 2.24e-4*(temperature_K-300.0);
    absorptionEnergy_eV = absorptionEnergy_eV+temperatureShift_eV;
    plEnergy_eV = plEnergy_eV+temperatureShift_eV;
    stokesShift_eV = max(0,absorptionEnergy_eV-plEnergy_eV);
end
end

function value = localLinearInterpolation(x,nodes,values)
% Fixed-size, code-generation-safe interpolation with linear extrapolation.
index = 1;
if x >= nodes(end)
    index = numel(nodes)-1;
elseif x > nodes(1)
    for k = 1:numel(nodes)-1
        if x >= nodes(k) && x <= nodes(k+1)
            index = k;
            break
        end
    end
end
fraction = (x-nodes(index))/max(nodes(index+1)-nodes(index),realmin);
value = values(index)+fraction*(values(index+1)-values(index));
end
