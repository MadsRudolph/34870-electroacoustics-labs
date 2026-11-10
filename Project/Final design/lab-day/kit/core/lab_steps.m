function [st, ids, label] = lab_steps(what)
% LAB_STEPS  Which steps a request means: 'P' (the whole run P1-P3), 'P1', or {'S1','S3'}.
%   st = the lab_plan rows in order, ids = their ids, label = file name of the run
%   ('P' for a whole group, else the ids joined with '+'). Errors on anything that
%   cannot be one run of the course routine.

P = lab_plan();
if iscell(what)
    ids = cellfun(@char, what, 'UniformOutput', false);
elseif any(strcmp({P.grp}, char(what))) && ~any(strcmp({P.id}, char(what)))
    ids = {P(strcmp({P.grp}, char(what))).id};
else
    ids = {char(what)};
end
[ok, idx] = ismember(ids, {P.id});
assert(all(ok), 'Unknown step(s): %s. Type: lab list', strjoin(ids(~ok), ', '));
assert(numel(unique(ids)) == numel(ids), 'A step can only be measured once per run.');
st = P(idx);
assert(numel(unique({st.station})) == 1, 'Chamber and Zi/Nfield steps cannot share a run.');
assert(numel(unique([st.angle])) == 1, 'All steps of a run must have the same angle.');
if strcmp(st(1).station, 'zinf'), assert(numel(st) == 1, 'Zi/Nfield: one step per run.'); end
assert(numel(st) <= 3, 'At most 3 steps in one run (the course routine).');
if numel(st) > 1 && all(strcmp({st.grp}, st(1).grp)) && sum(strcmp({P.grp}, st(1).grp)) == numel(st)
    label = st(1).grp;
else
    label = strjoin(ids, '+');
end
end
