function R = lab_check(m)
% LAB_CHECK  Verdicts for one saved run: one row per step, plus the run-level checks
%   (channel balance, sum, polarity notches) when the run holds the steps they need.
%   R(i): id, verdict ('OK' | 'CHECK' | 'BAD'), msg, offset (dB), shape (dB rms), x (extra)

P = lab_plan();
R = struct('id', {}, 'verdict', {}, 'msg', {}, 'offset', {}, 'shape', {}, 'x', {});
fn = m.fn(:);
for k = 1:numel(m.ids)
    s = P(strcmp({P.id}, m.ids{k}));
    r = struct('id', s.id, 'verdict', 'OK', 'msg', '', 'offset', NaN, 'shape', NaN, 'x', []);
    switch s.station
    case 'chamber'
        [ymod, okm] = lab_model('chamber', s.model, s.angle, fn);
        y = 20*log10(abs(m.H(:,k)));
        b = fn >= s.band(1) & fn <= s.band(2) & okm;
        r.offset = median(y(b) - ymod(b));
        res = lab_smooth(fn, y - ymod - r.offset);
        r.shape = sqrt(mean(res(b).^2, 'omitnan'));
        r.verdict = grade(r.shape, 1.5, 3);
        r.msg = sprintf('shape %.1f dB rms vs expected (%g-%g Hz), level %+.1f dB', r.shape, s.band, r.offset);
        if startsWith(s.id, 'P') && ~strcmp(r.verdict, 'OK')
            r.msg = [r.msg ' -> placement differs from Lab E: check box position, mic distance/height, angle'];
        end
    case 'zinf'
        switch s.model
        case {'board', 'board_mid', 'board_tw'}
            [Zm, okm] = lab_model('zinf', s.model, 0, fn);
            b = fn >= s.band(1) & fn <= s.band(2) & okm;
            d = 20*log10(abs(m.Z(b))) - Zm(b);
            r.offset = median(d); r.shape = max(abs(d - median(d)));
            [zmin, i] = min(abs(m.Z(b))); fb = fn(b);
            r.x = [zmin fb(i)];
            r.verdict = grade(max(abs(r.offset), r.shape/3), 1, 2);
            if zmin < 3.5, r.verdict = 'BAD'; end
            r.msg = sprintf('level %+.1f dB vs model, worst %.1f dB around it; |Z| min %.2f ohm at %.0f Hz', ...
                r.offset, r.shape, zmin, fb(i));
        case 'woofer'
            S = m.setup;
            L = labpaths(); addpath(L.labDmatlab);
            v = fb_from_Z(fn, m.Z);
            [ref, okr] = lab_model('woofer', '', S.vent_mm, []);
            r.x = [v.fL v.fb v.fH];
            if okr
                r.offset = v.fb - ref.fb;
                r.verdict = grade(abs(r.offset), 1.5, 3);
                r.msg = sprintf('fb %.1f Hz (Lab D at %d mm: %.1f Hz), fL %.1f, fH %.1f Hz', v.fb, S.vent_mm, ref.fb, v.fL, v.fH);
            else
                r.verdict = 'CHECK';
                r.msg = sprintf('fb %.1f Hz, fL %.1f, fH %.1f Hz (no Lab D data at %d mm)', v.fb, v.fL, v.fH, S.vent_mm);
            end
        otherwise   % near field
            where = erase(s.model, 'nf_');
            [ref, okr] = lab_model('nf', where, m.setup.vent_mm, fn);
            b = fn >= s.band(1) & fn <= s.band(2);
            y = 20*log10(abs(m.H(b)));
            if okr
                d = y - ref(b); r.offset = median(d);
                frac = mean(abs(d - r.offset) < 1);
                r.shape = frac; r.verdict = grade(1 - frac, 0.2, 0.4);
                r.msg = sprintf('vs Lab D (%d mm): level %+.1f dB, within 1 dB over %.0f %% of %g-%g Hz', ...
                    m.setup.vent_mm, r.offset, 100*frac, s.band);
            else
                r.verdict = 'CHECK'; r.msg = sprintf('no Lab D near field at %d mm to compare with', m.setup.vent_mm);
            end
        end
    end
    R(end+1) = r; %#ok<AGROW>
end

% ---- run-level checks (same run = same phase reference)
ids = m.ids;
iw = find(ismember(ids, {'S1', 'A1'})); it = find(ismember(ids, {'S2', 'A2'})); ia = find(ismember(ids, {'S3', 'A3', 'F0'}));
if ~isempty(iw) && ~isempty(it)
    gap = R(iw).offset - R(it).offset;
    R(end+1) = struct('id', 'bal', 'verdict', grade(abs(gap), 1, 2), ...
        'msg', sprintf('woofer vs mid+tw %+.1f dB (want +-1): change Out 1 gain by %+.1f dB', gap, -gap), ...
        'offset', gap, 'shape', NaN, 'x', []);
end
if ~isempty(iw) && ~isempty(it) && ~isempty(ia)
    d = lab_smooth(fn, 20*log10(abs(m.H(:,iw) + m.H(:,it))) - 20*log10(abs(m.H(:,ia))));
    w = max(abs(d(fn >= 150 & fn <= 15000)));
    R(end+1) = struct('id', 'sum', 'verdict', grade(w, 0.5, 1.5), ...
        'msg', sprintf('|woofer + mid/tw| vs |all|: worst %.2f dB (something moved if large)', w), ...
        'offset', w, 'shape', NaN, 'x', []);
end
for pair = {{'F1', [200 600], 329}, {'F2', [2000 6000], 3928}}
    i = find(strcmp(ids, pair{1}{1}));
    if isempty(i) || isempty(ia), continue; end
    b = find(fn >= pair{1}{2}(1) & fn <= pair{1}{2}(2));
    d = 20*log10(abs(m.H(b,i))) - 20*log10(abs(m.H(b,ia)));
    [dm, j] = min(d);
    v = 'OK'; if dm > -10 || abs(fn(b(j))/pair{1}{3} - 1) > 0.15, v = 'CHECK'; end
    if dm > -6, v = 'BAD'; end
    R(end+1) = struct('id', [pair{1}{1} 'n'], 'verdict', v, ...
        'msg', sprintf('notch %.0f Hz, %.1f dB below "all" (model ~%d Hz; deep = in phase at the crossover)', fn(b(j)), dm, pair{1}{3}), ...
        'offset', dm, 'shape', NaN, 'x', fn(b(j))); %#ok<AGROW>
end
end

function v = grade(x, okmax, checkmax)
if x <= okmax, v = 'OK'; elseif x <= checkmax, v = 'CHECK'; else, v = 'BAD'; end
end
