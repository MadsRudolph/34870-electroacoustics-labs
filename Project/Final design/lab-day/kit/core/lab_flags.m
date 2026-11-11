function [warn, level] = lab_flags(m)
% LAB_FLAGS  Problems visible in the raw signals of a run, in plain words.
%   warn  cellstr, level = 'OK' | 'CHECK' | 'BAD' (worst of them).
warn = {}; level = 'OK';
if ~isfield(m, 'peak'), return; end
if strcmp(m.station, 'chamber')
    if any(m.peak(:) > 0.95)
        warn{end+1} = 'A signal is near full scale (clipping): turn the amplifier or the MiniDSP input down and measure again.';
        level = 'BAD';
    end
    if size(m.peak, 1) >= 2 && any(m.peak(2,:) < 0.01)
        k = find(m.peak(2,:) < 0.01);
        warn{end+1} = sprintf(['Very small UMIK signal in state %s: a unit still OFF on the switchboard, the mic not ' ...
            'plugged in, or the amplifier off?'], strjoin(m.ids(k(k <= numel(m.ids))), ', '));
        level = worst(level, 'CHECK');
    end
else
    if isfield(m, 'clip') && any(m.clip > 0)
        warn{end+1} = 'Samples on the +-10 V rail of the NI card: data not usable. Turn the amplifier down and measure again.';
        level = 'BAD';
    end
    if isfield(m, 'k_amp') && m.k_amp == 2
        warn{end+1} = sprintf(['AI0 sits on a %.1f V DC offset (as in Lab D): V_amp = 2*AI0 was used. Check |Z| at ' ...
            'low frequency against the multimeter.'], m.dc_AI0);
        level = worst(level, 'CHECK');
    end
end
end

function v = worst(a, b)
o = {'OK', 'CHECK', 'BAD'};
v = o{max(find(strcmp(o, a)), find(strcmp(o, b)))};
end
