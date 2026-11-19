function qdInput = setQDInput(varargin)
%SETQDINPUT Change named model inputs without losing the other values.
%   setQDInput('radius_nm',2.8,'temperature_K',350)
%   setQDInput('incidentPhotonCount',100,'inputWavelength_nm',450,...
%              'beamArea_um2',1,'pumpDuration_ns',1)

qdInput = qdEnsureWorkspace();
if mod(numel(varargin),2) ~= 0
    error('VirtualQD:NameValue','Inputs must be name/value pairs.');
end
validNames = qdPublicInputNames();
for k = 1:2:numel(varargin)
    requestedName = char(string(varargin{k}));
    match = find(strcmpi(requestedName,validNames),1);
    if isempty(match)
        error('VirtualQD:UnknownInput', ...
            'Unknown input "%s". Use qdPublicInputNames.',requestedName);
    end
    value = varargin{k+1};
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
        error('VirtualQD:InputType','%s must be a finite real numeric scalar.',validNames{match});
    end
    qdInput.(validNames{match}) = value;
end
qdResolvePumpInputs(qdInput);
assignin('base','qdInput',qdInput);
end
