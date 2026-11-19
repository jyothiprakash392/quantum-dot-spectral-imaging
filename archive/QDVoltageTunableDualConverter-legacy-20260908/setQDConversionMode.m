function mode = setQDConversionMode(mode)
%SETQDCONVERSIONMODE Select the combined-model optical path.
%   SETQDCONVERSIONMODE(0) selects powered SWIR-to-visible up-conversion.
%   SETQDCONVERSIONMODE(1) selects passive UV-to-visible/NIR down-conversion.

if ischar(mode) || (isstring(mode)&&isscalar(mode))
    name = lower(strtrim(char(mode)));
    if any(strcmp(name,{'up','upconversion','swir'}))
        mode = 0;
    elseif any(strcmp(name,{'down','downconversion','uv'}))
        mode = 1;
    else
        error('VirtualQD:ConversionMode', ...
            'Mode text must be upconversion or downconversion.');
    end
end
if ~isnumeric(mode) || ~isscalar(mode) || ~isfinite(mode) || ...
        ~any(round(mode)==[0 1])
    error('VirtualQD:ConversionMode', ...
        'Conversion mode must be 0 (up) or 1 (down).');
end
mode = round(mode);
assignin('base','qdConversionMode',mode);
if bdIsLoaded('QDDualConversionSystem')
    set_param('QDDualConversionSystem/Conversion Mode', ...
        'Value',num2str(mode));
end
end
