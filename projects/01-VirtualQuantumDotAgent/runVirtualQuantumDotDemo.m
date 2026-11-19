function result = runVirtualQuantumDotDemo()
%RUNVIRTUALQUANTUMDOTDEMO Build, simulate, plot, and save a default run.

rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
qdInput = initVirtualQuantumDotAgent();
% Use a stronger CW pump only for the visualization so population dynamics
% are visible; the model itself keeps the low-intensity default.
qdInput.pumpIntensity_Wcm2 = 100;
modelName = 'VirtualQuantumDotAgent';
modelFile = fullfile(rootFolder,[modelName '.slx']);
if ~isfile(modelFile)
    buildVirtualQuantumDotAgent(false);
else
    load_system(modelFile);
end
assignin('base','qdInput',qdInput);

simOut = sim(modelName,'StopTime','20e-9','ReturnWorkspaceOutputs','on');
logged = simOut.get('qdOutput');
time_ns = logged.time*1e9;
values = logged.signals.values;
if ~ismatrix(values)
    values = squeeze(values);
end
result = qdUnpackOutputs(values(end,:).');
result.inputs = qdInput;
[result.effectiveInputs,~] = qdResolvePumpInputs(qdInput);
result.material = qdMaterialDatabase(qdInput.materialID);
result.warnings = qdDecodeFlags(result.validityFlags);
result.spectrum = qdGenerateSpectra(result,qdInput.temperature_K);

figureHandle = figure('Color','w','Name','Virtual Quantum Dot Agent Demo', ...
    'Position',[100 100 1150 760]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
nexttile;
plot(time_ns,values(:,21),'LineWidth',1.8); hold on;
plot(time_ns,values(:,22),'LineWidth',1.8);
plot(time_ns,values(:,23),'LineWidth',1.8);
xlabel('Time (ns)'); ylabel('Probability');
populationMaximum = max(values(:,21:23),[],'all');
ylim([0 max(1e-5,1.15*populationMaximum)]); grid on;
legend('Exciton','Biexciton','Trap','Location','best');
title('Population dynamics');

nexttile;
plot(time_ns,values(:,25),'LineWidth',1.8);
xlabel('Time (ns)'); ylabel('Photons s^{-1} dot^{-1}'); grid on;
title('Photoluminescence photon rate');

nexttile;
plot(result.spectrum.wavelengthAscending_nm,result.spectrum.absorption_m2_per_nm, ...
    'LineWidth',1.6);
grid on;
xlabel('Wavelength (nm)'); ylabel('\sigma_{abs} (m^2 nm^{-1})');
title('Absorption spectrum');

nexttile;
plot(result.spectrum.wavelengthAscending_nm,result.spectrum.plPhotons_Hz_per_nm, ...
    'LineWidth',1.8);
grid on;
xlabel('Wavelength (nm)'); ylabel('PL (photons s^{-1} nm^{-1})');
title(sprintf('PL center %.1f nm | QY %.3f', ...
    result.emissionWavelength_nm,result.internalQuantumYield));

sgtitle(sprintf('%s, R = %.2f nm, T = %.0f K, confidence = %.2f', ...
    result.material.name,qdInput.radius_nm,qdInput.temperature_K,result.modelConfidence));
previewFile = fullfile(rootFolder,'VirtualQuantumDotAgent_Demo.png');
exportgraphics(figureHandle,previewFile,'Resolution',170);
save(fullfile(rootFolder,'VirtualQuantumDotAgent_Demo.mat'),'result','time_ns','values');
end
