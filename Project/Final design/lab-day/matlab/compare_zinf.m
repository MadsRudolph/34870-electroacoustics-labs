function r = compare_zinf(m, varargin)
% COMPARE_ZINF  A Zi/Nfield measurement against what we expect.
%
%   r = compare_zinf(m)          m = output of measure_zinf, or a saved zinf_*.mat
%   r = compare_zinf('zinf_board.mat')
%
%   board       vs ../model/expected_zi.csv (Lab D driver impedances through the
%               design board): |Z| min and where, level ratio, worst deviation.
%               Which column: tag containing 'mid' -> Zmid, 'tw' -> Ztw, else Zboth.
%   woofer      vs Lab D labD_vent_L160 (same box, one vent 160 mm): fL, fb, fH.
%   nearfield   vs Lab D labD_nf_cone_L160 / labD_nf_vent_L160 (tag contains 'cone'
%               or 'vent'): level difference 10-200 Hz.
%   Lab D reference files are read from ../../../../Lab D/data.

p = inputParser;
p.addParameter('plot', true);
p.addParameter('ref', '');          % override the Lab D reference file name
p.parse(varargin{:});
o = p.Results;
if ischar(m) || isstring(m), m = load(m); end

here = fileparts(mfilename('fullpath'));
labD = fullfile(here, '..', '..', '..', '..', 'Lab D');
r = struct('tag', m.tag, 'kind', m.kind);
fn = m.fn(:);

switch m.kind
case 'board'
    csvf = fullfile(here, '..', 'model', 'expected_zi.csv');
    T = readmatrix(csvf, 'NumHeaderLines', 1);
    fid = fopen(csvf); hdr = strsplit(strtrim(fgetl(fid)), ','); fclose(fid);
    if contains(m.tag, 'mid'), col = 'Zmid'; elseif contains(m.tag, 'tw'), col = 'Ztw'; else, col = 'Zboth'; end
    Zmod = T(:, strcmp(hdr, [col '_re'])) + 1j*T(:, strcmp(hdr, [col '_im']));
    Zdcr = T(:, strcmp(hdr, [col '_dcr06_re'])) + 1j*T(:, strcmp(hdr, [col '_dcr06_im']));
    fm = T(:,1);
    k = fn >= fm(1) & fn <= fm(end);
    Zi = interp1(log(fm), abs(Zmod), log(fn(k)));
    d = 20*log10(abs(m.Z(k)) ./ Zi);
    [r.Zmin, i] = min(abs(m.Z(k))); fk = fn(k); r.f_Zmin = fk(i);
    [r.Zmin_model, j] = min(abs(Zmod)); r.f_Zmin_model = fm(j);
    r.median_dB = median(d); r.worst_dB = max(abs(d - r.median_dB));
    r.model = col;
    fprintf('%s vs model %s (%.0f Hz-%.1f kHz): median %+.2f dB, worst %.2f dB around that\n', ...
        m.tag, col, fm(1), fm(end)/1e3, r.median_dB, r.worst_dB);
    fprintf('  |Z| min %.2f ohm at %.0f Hz   (model %.2f ohm at %.0f Hz)\n', ...
        r.Zmin, r.f_Zmin, r.Zmin_model, r.f_Zmin_model);
    if r.Zmin < 3.5, warning('Below 3.5 ohm: check the wiring (a short, or both branches on one driver).'); end
    if abs(r.median_dB) > 1.5, warning('Level off by more than 1.5 dB: check R, k and the leads.'); end
    if o.plot
        figure('Name', m.tag);
        subplot(2,1,1); semilogx(fn, abs(m.Z), 'k', fm, abs(Zmod), 'r--', fm, abs(Zdcr), 'r:'); grid on
        ylabel('|Z| (\Omega)'); legend('measured', 'model (ideal coils)', 'model (0.6 \Omega/mH)');
        title(['Board input: ' m.tag], 'Interpreter', 'none'); xlim([20 24000]);
        subplot(2,1,2); semilogx(fn, angle(m.Z)*180/pi, 'k', fm, angle(Zmod)*180/pi, 'r--'); grid on
        ylabel('phase (deg)'); xlabel('frequency (Hz)'); xlim([20 24000]);
    end

case 'woofer'
    ref = o.ref; if isempty(ref), ref = 'labD_vent_L160.mat'; end
    addpath(fullfile(labD, 'matlab'));
    v = fb_from_Z(fn, m.Z);
    r.fL = v.fL; r.fb = v.fb; r.fH = v.fH;
    fprintf('%s: fL %.1f Hz, fb %.1f Hz, fH %.1f Hz, |Z| at %.1f Hz %.2f ohm\n', ...
        m.tag, v.fL, v.fb, v.fH, fn(1), abs(m.Z(1)));
    rf = fullfile(labD, 'data', ref);
    if exist(rf, 'file')
        R0 = load(rf); v0 = fb_from_Z(R0.fn, R0.Z);
        r.ref = ref; r.fb_ref = v0.fb;
        fprintf('  Lab D %s: fL %.1f, fb %.1f, fH %.1f Hz   (design model fB 24.6 Hz)\n', ref, v0.fL, v0.fb, v0.fH);
    end
    if o.plot
        figure('Name', m.tag);
        semilogx(fn, abs(m.Z), 'k'); hold on
        if exist(rf, 'file'), semilogx(R0.fn, abs(R0.Z), 'r--'); legend('now', ref, 'Interpreter', 'none'); end
        grid on; xlim([5 1000]); ylabel('|Z| (\Omega)'); xlabel('frequency (Hz)');
        title(['Woofer in the box: ' m.tag], 'Interpreter', 'none');
    end

case 'nearfield'
    if contains(m.tag, 'vent'), where = 'vent'; else, where = 'cone'; end
    ref = o.ref; if isempty(ref), ref = ['labD_nf_' where '_L160.mat']; end
    rf = fullfile(labD, 'data', ref);
    k = fn >= 10 & fn <= 200;
    [~, i] = max(abs(m.H(k))); fk = fn(k);
    fprintf('%s: |p/V| peak %.1f dB re 1 Pa/V at %.1f Hz (10-200 Hz)\n', ...
        m.tag, 20*log10(max(abs(m.H(k)))), fk(i));
    if exist(rf, 'file')
        R0 = load(rf);
        H0 = interp1(R0.fn, abs(R0.H), fn(k));
        d = 20*log10(abs(m.H(k)) ./ H0);
        r.ref = ref; r.median_dB = median(d); r.worst_dB = max(abs(d - median(d)));
        fprintf('  vs Lab D %s (10-200 Hz): median %+.2f dB, worst %.2f dB around that\n', ref, r.median_dB, r.worst_dB);
    end
    if o.plot
        figure('Name', m.tag);
        semilogx(fn, 20*log10(abs(m.H)), 'k'); hold on
        if exist(rf, 'file'), semilogx(R0.fn, 20*log10(abs(R0.H)), 'r--'); legend('now', ref, 'Interpreter', 'none'); end
        grid on; xlim([5 2000]); ylabel('|p/V| (dB re 1 Pa/V)'); xlabel('frequency (Hz)');
        title(['Near field: ' m.tag], 'Interpreter', 'none');
    end
end
end
