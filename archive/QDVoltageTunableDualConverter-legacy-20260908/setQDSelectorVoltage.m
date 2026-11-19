function response = setQDSelectorVoltage(selectorVoltage_V)
%SETQDSELECTORVOLTAGE Set the electronic QD-channel selector voltage.
%   RESPONSE = SETQDSELECTORVOLTAGE(V) validates V, updates the command used
%   by both generated Simulink models, and returns the selected fixed-film
%   response. The voltage is decoded electronically; no mechanical motion
%   is modeled or required.

if evalin('base',"exist('qdDownConfig','var')==1 && isstruct(qdDownConfig)")
    config = evalin('base','qdDownConfig');
else
    config = qdDownconversionConfig();
end
decoder = qdDecodeSelectorVoltage(selectorVoltage_V,config);
response = qdBuildDownconversionResponse(config,selectorVoltage_V);
response.electronicDecoder = decoder;
assignin('base','qdDownConfig',config);
assignin('base','qdSelectorVoltage_V',selectorVoltage_V);
assignin('base','qdDownResponseAtSelector',response);
assignin('base','qdSelectorDecoderAtCommand',decoder);

% Preserve the original workspace names as read-only compatibility aliases
% for user scripts created before the electronic-selector revision.
assignin('base','qdRotorVoltage_V',selectorVoltage_V);
assignin('base','qdDownResponseAtRotor',response);

modelNames = {'QDVoltageTunableDownconverter','QDDualConversionSystem'};
for modelIndex = 1:numel(modelNames)
    modelName = modelNames{modelIndex};
    if bdIsLoaded(modelName)
        blockPath = [modelName '/Electronic Selector Voltage'];
        if getSimulinkBlockHandle(blockPath)>0
            set_param(blockPath,'Value',num2str(selectorVoltage_V,15));
        end
    end
end
end
