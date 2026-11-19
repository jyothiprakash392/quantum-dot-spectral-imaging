function result = qdUnpackOutputs(y)
%QDUNPACKOUTPUTS Convert the ordered Simulink vector to a named structure.
names = qdOutputNames();
if numel(y) ~= numel(names)
    error('VirtualQD:OutputSize','Expected %d outputs; received %d.',numel(names),numel(y));
end
result = struct();
for k = 1:numel(names)
    result.(names{k}) = y(k);
end
end
