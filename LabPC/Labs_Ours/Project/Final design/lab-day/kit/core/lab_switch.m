function s = lab_switch(sw, prev)
% LAB_SWITCH  The switchboard in words. sw = [woofer mid tweeter], 1 = ON, 0 = OFF.
%   lab_switch([1 0 0])          -> 'Switchboard: woofer ON, mid OFF, tweeter OFF'
%   lab_switch([0 1 1], [1 0 0]) -> 'switch woofer OFF, mid ON, tweeter ON'  (only what changes)
%                                   'switchboard unchanged (...)' when nothing changes
names = {'woofer', 'mid', 'tweeter'}; onoff = {'OFF', 'ON'};
if isempty(sw), s = ''; return; end
if nargin < 2 || isempty(prev)
    s = ['Switchboard: ' strjoin(arrayfun(@(i) [names{i} ' ' onoff{sw(i) + 1}], 1:3, 'UniformOutput', false), ', ')];
    return
end
k = find(sw ~= prev);
if isempty(k)
    s = sprintf('switchboard unchanged (%s)', strjoin(arrayfun(@(i) [names{i} ' ' onoff{sw(i) + 1}], 1:3, 'UniformOutput', false), ', '));
else
    s = ['switch ' strjoin(arrayfun(@(i) [names{i} ' ' onoff{sw(i) + 1}], k, 'UniformOutput', false), ', ')];
end
end
