function u = qdPackInputs(qdInput)
%QDPACKINPUTS Convert the named input structure to the Simulink vector.
[effectiveInput,~] = qdResolvePumpInputs(qdInput);
names = qdInputNames();
u = zeros(numel(names),1);
for k = 1:numel(names)
    u(k) = effectiveInput.(names{k});
end
end
