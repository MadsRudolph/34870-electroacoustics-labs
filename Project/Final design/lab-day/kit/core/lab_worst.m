function v = lab_worst(c)
% LAB_WORST  The worst of a cell of verdicts: BAD beats CHECK beats OK. '' if none.
rank = {'OK', 'CHECK', 'BAD'};
v = '';
c = c(~cellfun(@isempty, c));
if isempty(c), return; end
[~, i] = ismember(c, rank);
v = rank{max([i(:); 1])};
end
