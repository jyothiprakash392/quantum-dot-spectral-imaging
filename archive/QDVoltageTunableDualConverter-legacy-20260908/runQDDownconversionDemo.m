function demo = runQDDownconversionDemo()
%RUNQDDOWNCONVERSIONDEMO Sweep every electronic voltage channel and export.

rootFolder = fileparts(mfilename('fullpath'));
addpath(rootFolder);
[~,config] = initQDVoltageTunableDualConverter(true);
truth = evalin('base','qdUVIncidentSpectrum');
voltages = config.selector.channelVoltage_V(:);
filmCount = config.filmCount;
outputCount = numel(config.outputWavelength_nm);
outputSpectra = zeros(outputCount,filmCount);
reconstructions = zeros(numel(config.inputWavelength_nm),filmCount);
peak_nm = zeros(filmCount,1);
centroid_nm = zeros(filmCount,1);
photonYield = zeros(filmCount,1);
energyEfficiency = zeros(filmCount,1);
correlation = zeros(filmCount,1);
normalizedRMSE = zeros(filmCount,1);
conditionNumber = zeros(filmCount,1);
maximumElectrons = zeros(filmCount,1);
saturated = false(filmCount,1);
observations = cell(filmCount,1);

for filmIndex = 1:filmCount
    observation = simulateQDDownconversion(truth,voltages(filmIndex), ...
        config,'AddNoise',true,'Seed',config.randomSeed+filmIndex-1, ...
        'ReconstructSpectrum',true);
    observations{filmIndex} = observation;
    estimate = observation.reconstruction.incidentPhotonsPerBin;
    outputSpectra(:,filmIndex) = observation.conversion. ...
        outputSpectrumPhotonCountExpectedPerBin;
    reconstructions(:,filmIndex) = estimate;
    peak_nm(filmIndex) = observation.conversion.peakWavelength_nm;
    centroid_nm(filmIndex) = observation.conversion.centroidWavelength_nm;
    photonYield(filmIndex) = observation.conversion. ...
        photonYieldPerIncidentPhoton;
    energyEfficiency(filmIndex) = observation.conversion.opticalEnergyEfficiency;
    coefficients = corrcoef(truth,estimate);
    correlation(filmIndex) = coefficients(1,2);
    normalizedRMSE(filmIndex) = sqrt(mean((truth-estimate).^2))/mean(truth);
    conditionNumber(filmIndex) = observation.response.conditionNumber;
    maximumElectrons(filmIndex) = max(observation.computationalCCD. ...
        signalElectronsExpected);
    saturated(filmIndex) = any(observation.computationalCCD.saturated);
end

figureHandle = figure('Color','w','Position',[80 80 1550 940], ...
    'Visible','off');
layout = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
mainTitle = title(layout, ...
    'Voltage-Selected QD UV-to-Visible/NIR Downconverter');
mainTitle.Color = 'k';

[~,defaultIndex] = min(abs(voltages-config.selector.defaultVoltage_V));
nexttile;
plot(config.inputWavelength_nm,truth/1e3,'k-','LineWidth',2.2);
hold on;
plot(config.inputWavelength_nm,reconstructions(:,defaultIndex)/1e3, ...
    'Color',[0.05 0.45 0.78],'LineWidth',1.8);
xlabel('UV wavelength (nm)');
ylabel('Photons per bin (thousands)');
legend('Incoming truth','CCD reconstruction','Location','northwest');
title(sprintf('UV computation at %.1f V: corr. %.4f', ...
    voltages(defaultIndex),correlation(defaultIndex)));
grid on;
localStyleAxes(gca);

nexttile;
colors = turbo(filmCount);
hold on;
for filmIndex = 1:filmCount
    normalized = outputSpectra(:,filmIndex)/ ...
        max(outputSpectra(:,filmIndex),realmin);
    plot(config.outputWavelength_nm,normalized,'LineWidth',1.8, ...
        'Color',colors(filmIndex,:));
end
xlabel('Emitted wavelength (nm)');
ylabel('Normalized photons per bin');
legend(arrayfun(@(v,p)sprintf('%.1f V -> %.0f nm',v,p), ...
    voltages,peak_nm,'UniformOutput',false),'Location','eastoutside');
title('Electronically selected fixed-emission QD channels');
grid on;
localStyleAxes(gca);

nexttile;
response = observations{defaultIndex}.response;
plot(config.outputWavelength_nm,response.siQuantumEfficiency, ...
    'Color',[0.15 0.48 0.85],'LineWidth',2);
hold on;
plot(config.outputWavelength_nm,response.ingaasQuantumEfficiency, ...
    'Color',[0.74 0.22 0.55],'LineWidth',2);
plot(config.outputWavelength_nm,response.siRouteFraction,'--', ...
    'Color',[0.12 0.35 0.60],'LineWidth',1.5);
plot(config.outputWavelength_nm,response.ingaasRouteFraction,'--', ...
    'Color',[0.55 0.14 0.42],'LineWidth',1.5);
xlabel('Wavelength (nm)');
ylabel('Quantum efficiency / route fraction');
legend('Silicon QE','InGaAs QE','To silicon','To InGaAs', ...
    'Location','southwest');
title('Dichroic hybrid detector coverage');
grid on;
localStyleAxes(gca);

nexttile;
yyaxis left;
bar(voltages,[photonYield energyEfficiency],0.82);
ylabel('Fraction of incident photons / energy');
ylim([0 max(photonYield)*1.3]);
yyaxis right;
plot(voltages,correlation,'ko-','LineWidth',1.8, ...
    'MarkerFaceColor',[0.95 0.65 0.10]);
ylabel('Noisy UV reconstruction correlation');
ylim([0.995 1.0001]);
xlabel('Electronic selector voltage (V)');
legend('Photon yield','Optical energy efficiency','Correlation', ...
    'Location','southwest');
title('Passive conversion and computational performance');
grid on;
localStyleAxes(gca);

figureFile = fullfile(rootFolder,'QDDownconversion_VoltageSweep.png');
exportgraphics(figureHandle,figureFile,'Resolution',180);
close(figureHandle);

summaryTable = table((1:filmCount).',voltages, ...
    string(config.film.material(:)),peak_nm,centroid_nm,photonYield, ...
    energyEfficiency,conditionNumber,normalizedRMSE,correlation, ...
    maximumElectrons,saturated, ...
    'VariableNames',{'Film','SelectorVoltage_V','Material', ...
    'OutputPeak_nm','OutputCentroid_nm','PhotonYield', ...
    'OpticalEnergyEfficiency','ResponseConditionNumber', ...
    'NormalizedRMSE','SpectralCorrelation','MaximumExpectedElectrons', ...
    'Saturated'});
writetable(summaryTable,fullfile(rootFolder, ...
    'QD_DOWNCONVERSION_VOLTAGE_SWEEP.csv'));

demo = struct();
demo.config = config;
demo.truth = truth;
demo.voltages_V = voltages;
demo.outputSpectra = outputSpectra;
demo.reconstructions = reconstructions;
demo.summary = summaryTable;
demo.observations = observations;
save(fullfile(rootFolder,'QDDownconversionDemo.mat'),'demo');

fileID = fopen(fullfile(rootFolder, ...
    'QD_DOWNCONVERSION_DEMO_RESULTS.txt'),'w');
if fileID<0
    error('VirtualQD:ArtifactWrite','Cannot write demo results.');
end
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'QD Voltage-Selected UV-to-Visible/NIR Downconverter Demo\n');
fprintf(fileID,'Calibration: %s\n',config.calibration.label);
fprintf(fileID,['Selector interpretation: voltage selects one fixed-emission ' ...
    'film through an electronic decoder; no rotor is used and the voltage ' ...
    'does not broadly tune one film.\n']);
fprintf(fileID,'UV input: %.0f to %.0f nm, %d bins\n', ...
    config.inputWavelength_nm(1),config.inputWavelength_nm(end), ...
    numel(config.inputWavelength_nm));
fprintf(fileID,'Computational channels: %d pixels x %d bias states = %d\n', ...
    config.spectrometer.pixelCount,config.spectrometer.biasCount, ...
    config.spectrometer.measurementCount);
for filmIndex = 1:filmCount
    fprintf(fileID,['%.1f V | film %d | peak %.0f nm | photon yield %.5f | ' ...
        'energy efficiency %.5f | rank %d | cond %.4f | corr %.6f | ' ...
        'NRMSE %.6f | saturation %d\n'], ...
        voltages(filmIndex),filmIndex,peak_nm(filmIndex), ...
        photonYield(filmIndex),energyEfficiency(filmIndex), ...
        observations{filmIndex}.response.numericalRank, ...
        conditionNumber(filmIndex),correlation(filmIndex), ...
        normalizedRMSE(filmIndex),saturated(filmIndex));
end
fprintf(fileID,['IMPORTANT: default film, filter, PLQY, detector, and noise ' ...
    'curves are synthetic and require measured calibration.\n']);
end

function localStyleAxes(axesHandle)
set(axesHandle,'Color','w','XColor','k','GridColor',[0.72 0.72 0.72], ...
    'MinorGridColor',[0.82 0.82 0.82]);
for axisIndex = 1:numel(axesHandle.YAxis)
    axesHandle.YAxis(axisIndex).Color = 'k';
end
axesHandle.Title.Color = 'k';
legendHandle = axesHandle.Legend;
if ~isempty(legendHandle)
    legendHandle.Color = 'w';
    legendHandle.TextColor = 'k';
    legendHandle.EdgeColor = [0.45 0.45 0.45];
end
end
