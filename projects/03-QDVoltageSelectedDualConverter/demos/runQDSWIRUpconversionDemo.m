function result = runQDSWIRUpconversionDemo()
%RUNQDSWIRUPCONVERSIONDEMO Run the end-to-end SWIR/CCD demonstration.

paths = setupQDVoltageSelectedDualConverter();
[config,response,truth] = initQDSWIRUpconversionSpectrometer(true);
result = simulateQDComputationalSpectrometer(truth,config, ...
    'AddNoise',true,'Seed',config.randomSeed);

wavelength_nm = config.inputWavelength_nm(:);
visibleWavelength_nm = config.visibleWavelength_nm(:);
estimate = result.reconstruction.incidentPhotonsPerBin;
visibleSpectrum = result.observation.conversion. ...
    visibleSpectrumPhotonCountExpectedPerBin;
systemMatrix = response.systemMatrix_electronsPerIncidentPhoton;
rowMaximum = max(systemMatrix,[],2);
normalizedMatrix = systemMatrix./max(rowMaximum,realmin);

figureHandle = figure('Color','w','Position',[100 100 1500 930], ...
    'Visible','off');
layout = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
mainTitle = title(layout, ...
    'QD IR-to-Visible Upconverter + CCD Computational Spectrometer');
mainTitle.Color = 'k';

nexttile;
plot(wavelength_nm,truth/1e6,'k-','LineWidth',2.2);
hold on;
plot(wavelength_nm,estimate/1e6,'Color',[0.06 0.45 0.74], ...
    'LineWidth',1.8);
xlabel('SWIR wavelength (nm)');
ylabel('Photons per bin (millions)');
legend('Incoming truth','CCD reconstruction','Location','northwest');
grid on;
title(sprintf('Reconstruction: correlation %.4f, angle %.2f deg', ...
    result.metrics.spectralCorrelation,result.metrics.spectralAngle_deg));
localStyleAxes(gca);

nexttile;
imagesc(wavelength_nm,1:config.measurementCount,normalizedMatrix);
axis xy;
xlabel('SWIR wavelength (nm)');
ylabel('Pixel/bias measurement');
title(sprintf('Calibrated operator rows (rank %d, cond. %.1f)', ...
    response.numericalRank,response.conditionNumber));
colorbarHandle = colorbar;
colorbarHandle.Color = 'k';
localStyleAxes(gca);

nexttile;
yyaxis left;
plot(visibleWavelength_nm,visibleSpectrum/max(visibleSpectrum), ...
    'Color',[0.45 0.15 0.70],'LineWidth',2);
ylabel('Normalized visible PL');
yyaxis right;
plot(visibleWavelength_nm,response.ccdQuantumEfficiency, ...
    'Color',[0.05 0.55 0.30],'LineWidth',2);
ylabel('CCD quantum efficiency');
xlabel('Visible wavelength (nm)');
grid on;
title('Visible conversion before CCD detection');
localStyleAxes(gca);

nexttile;
measurementIndex = (1:config.measurementCount).';
plot(measurementIndex,result.observation.ccd.signalElectronsExpected, ...
    'Color',[0.85 0.35 0.05],'LineWidth',1.8);
hold on;
scatter(measurementIndex,result.observation.ccd.measuredElectrons,18, ...
    [0.15 0.20 0.25],'filled');
xlabel('Pixel/bias measurement');
ylabel('CCD electrons per exposure');
legend('Expected','Shot + dark + read noise','Location','northwest');
grid on;
title('CCD readout delivered to computation');
localStyleAxes(gca);

demoFigure = fullfile(paths.figures,'swir-upconversion-reconstruction.png');
exportgraphics(figureHandle,demoFigure,'Resolution',180);
close(figureHandle);

demoTable = table(wavelength_nm,truth,estimate,estimate-truth, ...
    'VariableNames',{'Wavelength_nm','TruthPhotonsPerBin', ...
    'ReconstructedPhotonsPerBin','ErrorPhotonsPerBin'});
writetable(demoTable,fullfile(paths.tables, ...
    'swir-upconversion-reconstruction.csv'));

fileID = fopen(fullfile(paths.reports,'swir-upconversion-demo.txt'),'w');
if fileID<0
    error('QDConverter:ArtifactWrite','Cannot write demonstration result file.');
end
cleanup = onCleanup(@()fclose(fileID));
fprintf(fileID,'QD Upconversion CCD Computational Spectrometer Demo\n');
fprintf(fileID,'Calibration: %s\n',response.calibrationLabel);
fprintf(fileID,'Input band: %.1f to %.1f nm, %d bins\n', ...
    wavelength_nm(1),wavelength_nm(end),numel(wavelength_nm));
fprintf(fileID,'Measurements: %d pixels x %d biases = %d\n', ...
    config.pixelCount,config.biasCount,config.measurementCount);
fprintf(fileID,'Response rank: %d, condition number: %.8g\n', ...
    response.numericalRank,response.conditionNumber);
fprintf(fileID,'Normalized RMSE by mean: %.8g\n', ...
    result.metrics.normalizedRMSEByMean);
fprintf(fileID,'Spectral correlation: %.8g\n', ...
    result.metrics.spectralCorrelation);
fprintf(fileID,'Spectral angle: %.8g degrees\n', ...
    result.metrics.spectralAngle_deg);
fprintf(fileID,'Maximum expected CCD signal: %.8g electrons\n', ...
    max(result.observation.ccd.signalElectronsExpected));
fprintf(fileID,'CCD saturation: %d\n', ...
    result.observation.validity.anyCCDSaturation);
fprintf(fileID,['IMPORTANT: the delivered response family is synthetic. ' ...
    'Use qdApplyMeasuredSpectralCalibration for quantitative hardware prediction.\n']);
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
