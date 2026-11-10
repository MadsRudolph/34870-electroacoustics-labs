function [st, ids, label] = lab_steps(what)
% LAB_STEPS  Turn what the user asked for into plan rows.
%   what: a step id ('P1'), a run group ('S' = S1, S2, S3) or a cell of 1-3 ids.
%   st = rows of lab_plan, ids = their ids, label = the file name stem of the run.
%   Errors (with a plain message) when the steps cannot share one run.

P = lab_plan();
if iscell(what), ids = cellfun(@char, what(:)', 'UniformOutput', false);
elseif any(strcmp({P.grp}, char(what))) && ~any(strcmp({P.id}, char(what)))
    ids = {P(strcmp({P.grp}, char(what))).id};
else, ids = {char(what)};
end
assert(~isempty(ids), 'No step chosen.');
[ok, idx] = ismember(ids, {P.id});
assert(all(ok), 'Unknown step(s): %s. Type: lab list', strjoin(ids(~ok), ', '));
assert(numel(unique(ids)) == numel(ids), 'The same step twice in one run.');
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
