function qdInput = qdEnsureWorkspace()
%QDENSUREWORKSPACE Initialize missing variables without overwriting user inputs.

defaults = qdDefaultInputs();
if evalin('base','exist(''qdInput'',''var'')')
    qdInput = evalin('base','qdInput');
    if ~isstruct(qdInput)
        qdInput = defaults;
    else
        names = fieldnames(defaults);
        for k = 1:numel(names)
            if ~isfield(qdInput,names{k})
                qdInput.(names{k}) = defaults.(names{k});
            end
        end
    end
else
    qdInput = defaults;
end

assignin('base','qdInput',qdInput);
assignin('base','QD_SAMPLE_TIME_S',1.0e-11);
assignin('base','QD_OUTPUT_NAMES',qdOutputNames());
assignin('base','QD_INPUT_NAMES',qdInputNames());
assignin('base','QD_PUBLIC_INPUT_NAMES',qdPublicInputNames());
assignin('base','QD_PHOTON_COUNT_NAMES',qdPhotonCountNames());
assignin('base','QD_MODEL_VERSION','1.5.1');
end
