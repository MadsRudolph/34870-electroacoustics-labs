function T = lab_timeline(st, Nav)
% LAB_TIMELINE  How long a run takes and what happens when (for the progress display).
%   T.total  seconds;  T.seg(i): t0, t1, kind ('measure' | 'beeps'), k (which step)
%   Chamber: each state plays Nav+1 periods of 1 s, with ~30 s of beeps between states.
%   Zi/Nfield: 8 s periods (fres 0.125 Hz); ceil(Nav/16) x (min(Nav,16)+1) periods.

if nargin < 2 || isempty(Nav), Nav = 64; end
seg = struct('t0', {}, 't1', {}, 'kind', {}, 'k', {});
t = 0;
if strcmp(st(1).station, 'chamber')
    for k = 1:numel(st)
        if k > 1, seg(end+1) = struct('t0', t, 't1', t + 30, 'kind', 'beeps', 'k', k); t = t + 30; end %#ok<AGROW>
        seg(end+1) = struct('t0', t, 't1', t + Nav + 1, 'kind', 'measure', 'k', k); t = t + Nav + 1; %#ok<AGROW>
    end
else
    if startsWith(st(1).model, 'nf'), Nav = 4; else, Nav = 1; end
    d = ceil(Nav/16) * (min(Nav, 16) + 1) * 8;
    seg(1) = struct('t0', 0, 't1', d, 'kind', 'measure', 'k', 1); t = d;
end
T = struct('total', t, 'seg', seg, 'Nav', Nav);
end
