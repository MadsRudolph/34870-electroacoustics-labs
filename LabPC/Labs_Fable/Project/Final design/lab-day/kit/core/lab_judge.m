function m = lab_judge(m)
% LAB_JUDGE  Add the verdicts to a run: m.R (from lab_check) and m.verdict (the worst one).
%   Never throws: a run that cannot be judged gets m.R = [] and m.err = why.
m.err = '';
try
    m.R = lab_check(m);
    m.verdict = lab_worst({m.R.verdict});
catch e
    m.R = struct('id', {}, 'verdict', {}, 'msg', {}, 'offset', {}, 'shape', {}, 'x', {});
    m.verdict = 'CHECK';
    m.err = e.message;
end
end
