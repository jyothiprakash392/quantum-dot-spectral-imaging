function demo = runQDSelectorDemo()
%RUNQDSELECTORDEMO Visualize voltage-only channel selection.
%   DEMO = RUNQDSELECTORDEMO sweeps the selector voltage upward
%   and downward through the ADC/window decoder, exports the decoded channel
%   table, and plots emission selection, hysteresis, and one-hot gate logic.

paths = setupQDVoltageSelectedDualConverter();
config = qdDownconversionConfig();
pointCount = 1001;
upVoltage_V = linspace(config.selector.minimumVoltage_V, ...
    config.selector.maximumVoltage_V,pointCount).';
downVoltage_V = flipud(upVoltage_V);
up = localSweep(upVoltage_V,config,1);
down = localSweep(downVoltage_V,config,config.filmCount);

figureHandle = figure('Color','w','Position',[100 100 1450 920], ...
    'Visible','off');
layout = tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
mainTitle = title(layout, ...
    'Electronic QD Selector: Voltage to Optical Channel');
mainTitle.Color = 'k';

nexttile;
stairs(up.commandVoltage_V,up.emissionWavelength_nm,'LineWidth',2.2, ...
    'Color',[0.05 0.42 0.78]);
hold on;
stairs(down.commandVoltage_V,down.emissionWavelength_nm,'--', ...
    'LineWidth',1.8,'Color',[0.78 0.18 0.40]);
for threshold = config.selector.thresholdVoltage_V(:).'
    xline(threshold,':','Color',[0.35 0.35 0.35]);
end
ylabel('Selected emission (nm)');
legend('Increasing voltage','Decreasing voltage', ...
    'Location','northwest');
title(sprintf(['Six fixed QD channels; 12-bit ADC, %.0f mV ' ...
    'comparator hysteresis'],1e3*config.selector.hysteresis_V));
grid on;
localStyleAxes(gca);

nexttile;
imagesc(up.commandVoltage_V,1:config.filmCount,up.oneHotGates.');
axis xy;
colormap(gca,[0.94 0.96 0.98;0.08 0.58 0.74]);
clim([0 1]);
yticks(1:config.filmCount);
yticklabels(arrayfun(@(index,wavelength)sprintf( ...
    'Gate %d: %.0f nm',index,wavelength), ...
    (1:config.filmCount).',config.film.emissionCenter_nm(:), ...
    'UniformOutput',false));
ylabel('One-hot optical gate');
title('Exactly one solid-state channel is enabled at every command voltage');
localStyleAxes(gca);

nexttile;
plot(up.commandVoltage_V,1e3*(up.adcVoltage_V-up.commandVoltage_V), ...
    'LineWidth',1.4,'Color',[0.42 0.22 0.72]);
hold on;
yline(0,'k:');
xlabel('Electronic selector command (V)');
ylabel('ADC error (mV)');
title(sprintf('ADC quantization: %.3f mV per least-significant bit', ...
    1e3*config.selector.adc.leastSignificantBit_V));
grid on;
localStyleAxes(gca);

figureFile = fullfile(paths.figures, ...
    'selector-transfer-characteristic.png');
exportgraphics(figureHandle,figureFile,'Resolution',180);
close(figureHandle);

upTable = localTable(up,"increasing",config.filmCount);
downTable = localTable(down,"decreasing",config.filmCount);
sweepTable = [upTable;downTable];
csvFile = fullfile(paths.tables,'selector-transfer-characteristic.csv');
writetable(sweepTable,csvFile);

demo = struct();
demo.config = config;
demo.increasing = up;
demo.decreasing = down;
demo.table = sweepTable;
demo.figureFile = figureFile;
demo.csvFile = csvFile;
end

function sweep = localSweep(commandVoltage_V,config,initialIndex)
sampleCount = numel(commandVoltage_V);
sweep = struct();
sweep.commandVoltage_V = commandVoltage_V(:);
sweep.adcVoltage_V = zeros(sampleCount,1);
sweep.adcCode = zeros(sampleCount,1);
sweep.selectedChannelIndex = zeros(sampleCount,1);
sweep.selectedChannelVoltage_V = zeros(sampleCount,1);
sweep.emissionWavelength_nm = zeros(sampleCount,1);
sweep.thresholdMargin_V = zeros(sampleCount,1);
sweep.oneHotGates = zeros(sampleCount,config.filmCount);
previousIndex = initialIndex;
for sampleIndex = 1:sampleCount
    decoder = qdDecodeSelectorVoltage(commandVoltage_V(sampleIndex), ...
        config,'PreviousChannelIndex',previousIndex);
    sweep.adcVoltage_V(sampleIndex) = decoder.adcVoltage_V;
    sweep.adcCode(sampleIndex) = decoder.adcCode;
    sweep.selectedChannelIndex(sampleIndex) = ...
        decoder.selectedChannelIndex;
    sweep.selectedChannelVoltage_V(sampleIndex) = ...
        decoder.selectedChannelVoltage_V;
    sweep.emissionWavelength_nm(sampleIndex) = ...
        decoder.nominalEmissionWavelength_nm;
    sweep.thresholdMargin_V(sampleIndex) = decoder.thresholdMargin_V;
    sweep.oneHotGates(sampleIndex,:) = decoder.oneHotGates.';
    previousIndex = decoder.selectedChannelIndex;
end
end

function outputTable = localTable(sweep,direction,filmCount)
directionColumn = repmat(direction,numel(sweep.commandVoltage_V),1);
outputTable = table(directionColumn,sweep.commandVoltage_V, ...
    sweep.adcVoltage_V,sweep.adcCode,sweep.selectedChannelIndex, ...
    sweep.selectedChannelVoltage_V,sweep.emissionWavelength_nm, ...
    sweep.thresholdMargin_V, ...
    'VariableNames',{'Direction','CommandVoltage_V','ADCVoltage_V', ...
    'ADCCode','Channel','ChannelVoltage_V','Emission_nm', ...
    'ThresholdMargin_V'});
for gateIndex = 1:filmCount
    outputTable.(sprintf('Gate%d',gateIndex)) = ...
        sweep.oneHotGates(:,gateIndex);
end
end

function localStyleAxes(axesHandle)
set(axesHandle,'Color','w','XColor','k','YColor','k', ...
    'GridColor',[0.72 0.72 0.72], ...
    'MinorGridColor',[0.82 0.82 0.82]);
axesHandle.Title.Color = 'k';
legendHandle = axesHandle.Legend;
if ~isempty(legendHandle)
    legendHandle.Color = 'w';
    legendHandle.TextColor = 'k';
    legendHandle.EdgeColor = [0.45 0.45 0.45];
end
end
