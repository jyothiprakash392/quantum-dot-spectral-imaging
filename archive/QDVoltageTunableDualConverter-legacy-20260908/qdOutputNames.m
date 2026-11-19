function names = qdOutputNames()
%QDOUTPUTNAMES Ordered names for the 40-element Simulink output vector.
names = { ...
    'bulkBandgap_eV'; ...                 % 1
    'electronConfinement_eV'; ...         % 2
    'holeConfinement_eV'; ...             % 3
    'excitonBinding_eV'; ...              % 4
    'polarizationShift_eV'; ...           % 5
    'starkShift_eV'; ...                  % 6
    'strainShift_eV'; ...                 % 7
    'absorptionEnergy_eV'; ...            % 8
    'plEnergy_eV'; ...                    % 9
    'emissionWavelength_nm'; ...          % 10
    'electronHoleOverlap'; ...            % 11
    'absorptionCrossSection_m2'; ...       % 12
    'generationRate_Hz'; ...              % 13
    'radiativeRate_Hz'; ...               % 14
    'nonradiativeRate_Hz'; ...            % 15
    'augerRate_Hz'; ...                   % 16
    'trapCaptureRate_Hz'; ...             % 17
    'tunnelingRate_Hz'; ...               % 18
    'chargingEnergy_eV'; ...              % 19
    'groundProbability'; ...              % 20
    'excitonProbability'; ...             % 21
    'biexcitonProbability'; ...           % 22
    'trapProbability'; ...                % 23
    'meanExcitonNumber'; ...              % 24
    'plPhotonRate_Hz'; ...                % 25
    'internalQuantumYield'; ...            % 26 instantaneous decay-flux ratio
    'effectiveLifetime_ns'; ...            % 27 prompt free-exciton lifetime
    'suggestedRadius_nm'; ...              % 28
    'targetError_eV'; ...                  % 29
    'modelConfidence'; ...                 % 30
    'validityFlags'; ...                   % 31
    'electronRootResidual'; ...            % 32
    'holeRootResidual'; ...                % 33
    'probabilityResidual'; ...             % 34
    'stokesShift_eV'; ...                  % 35
    'phononOccupation'; ...                % 36
    'thermalEscapeRate_Hz'; ...            % 37
    'absorptionEventRate_Hz'; ...          % 38
    'trappedPhotonRate_Hz'; ...            % 39 trap-emission subset (legacy name)
    'modelTier'};                          % 40
end
