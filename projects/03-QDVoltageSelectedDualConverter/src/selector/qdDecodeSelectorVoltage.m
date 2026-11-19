function decoder = qdDecodeSelectorVoltage(selectorVoltage_V,config,varargin)
%QDDECODESELECTORVOLTAGE Decode one voltage into one electronic QD channel.
%   D = QDDECODESELECTORVOLTAGE(V,CONFIG) applies the configured ADC
%   quantization and voltage-window thresholds. D.ONEHOTGATES contains the
%   1-of-N solid-state optical-gate command and D.SELECTEDCHANNELVOLTAGE_V is
%   the exact calibrated setpoint passed to the film-bank model.
%
%   D = QDDECODESELECTORVOLTAGE(...,'PreviousChannelIndex',K) applies the
%   configured comparator hysteresis around a threshold when a previous
%   channel is known.

if nargin<2 || isempty(config)
    config = qdDownconversionConfig();
end
parser = inputParser;
parser.FunctionName = 'qdDecodeSelectorVoltage';
addParameter(parser,'PreviousChannelIndex',[], ...
    @(x)isempty(x)||(isnumeric(x)&&isscalar(x)&&isreal(x)&& ...
    isfinite(x)&&x==fix(x)&&x>=1&&x<=config.filmCount));
parse(parser,varargin{:});

if ~isnumeric(selectorVoltage_V) || ~isscalar(selectorVoltage_V) || ...
        ~isreal(selectorVoltage_V) || ~isfinite(selectorVoltage_V) || ...
        selectorVoltage_V<config.selector.minimumVoltage_V || ...
        selectorVoltage_V>config.selector.maximumVoltage_V
    error('QDConverter:SelectorVoltage', ...
        ['Selector voltage must be a finite scalar inside the calibrated ' ...
        'channel-voltage range.']);
end

channelVoltages_V = config.selector.channelVoltage_V(:);
thresholds_V = config.selector.thresholdVoltage_V(:);
adcMaximumCode = 2^config.selector.adc.resolution_bits-1;
adcCode = round(selectorVoltage_V/ ...
    config.selector.adc.referenceVoltage_V*adcMaximumCode);
adcCode = min(adcMaximumCode,max(0,adcCode));
adcVoltage_V = adcCode/adcMaximumCode* ...
    config.selector.adc.referenceVoltage_V;

selectedIndex = 1+sum(adcVoltage_V>thresholds_V);
previousIndex = parser.Results.PreviousChannelIndex;
if ~isempty(previousIndex) && selectedIndex~=previousIndex
    hysteresisHalfWidth_V = 0.5*config.selector.hysteresis_V;
    if selectedIndex>previousIndex
        crossingThreshold_V = thresholds_V(selectedIndex-1);
        if adcVoltage_V<crossingThreshold_V+hysteresisHalfWidth_V
            selectedIndex = previousIndex;
        end
    else
        crossingThreshold_V = thresholds_V(selectedIndex);
        if adcVoltage_V>crossingThreshold_V-hysteresisHalfWidth_V
            selectedIndex = previousIndex;
        end
    end
end

oneHotGates = zeros(config.filmCount,1);
oneHotGates(selectedIndex) = 1;
if isempty(thresholds_V)
    thresholdMargin_V = inf;
else
    thresholdMargin_V = min(abs(adcVoltage_V-thresholds_V));
end

decoder = struct();
decoder.commandVoltage_V = selectorVoltage_V;
decoder.adcCode = adcCode;
decoder.adcVoltage_V = adcVoltage_V;
decoder.selectedChannelIndex = selectedIndex;
decoder.selectedChannelVoltage_V = channelVoltages_V(selectedIndex);
decoder.nominalEmissionWavelength_nm = ...
    config.film.emissionCenter_nm(selectedIndex);
decoder.oneHotGates = oneHotGates;
decoder.thresholdMargin_V = thresholdMargin_V;
decoder.hysteresisApplied = ~isempty(previousIndex);
decoder.hardwareArchitecture = config.selector.hardwareArchitecture;
end
