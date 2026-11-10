function [y, ok] = lab_model(kind, name, arg, fn)
% LAB_MODEL  The expected curve for a step, on the measurement's frequencies.
%   chamber : y = model |p/V| in dB (column 'name' of ../model/expected_on|off30.csv, arg = angle)
%   zinf    : y = model |Z| in dB re 1 ohm (Zboth / Zmid / Ztw from expected_zi.csv)
%   woofer  : y = struct with Lab D fL, fb, fH and the curve (arg = vent length, mm)
%   nf      : y = Lab D near field in dB (name 'cone' or 'vent', arg = vent length, mm)
%   ok = where the model exists (inside its frequency range / file found).

persistent cache
if isempty(cache), cache = containers.Map(); end
here = fileparts(mfilename('fullpath'));
labD = fullfile(here, '..', '..', '..', '..', 'Lab D');
fn = fn(:);
switch kind
case 'chamber'
    if arg == 30, f = 'expected_off30.csv'; else, f = 'expected_on.csv'; end
    [T, hdr] = readcsv(cache, fullfile(here, '..', 'model', f));
    H = T(:, strcmp(hdr, [name '_re'])) + 1j*T(:, strcmp(hdr, [name '_im']));
    assert(~isempty(H), 'No model column %s in %s: rerun python3 model_curves.py', name, f);
    y = interp1(log(T(:,1)), 20*log10(abs(H)), log(fn), 'linear', NaN);
    ok = ~isnan(y);
case 'zinf'
    col = struct('board', 'Zboth', 'board_mid', 'Zmid', 'board_tw', 'Ztw');
    [T, hdr] = readcsv(cache, fullfile(here, '..', 'model', 'expected_zi.csv'));
    Z = T(:, strcmp(hdr, [col.(name) '_re'])) + 1j*T(:, strcmp(hdr, [col.(name) '_im']));
    y = interp1(log(T(:,1)), 20*log10(abs(Z)), log(fn), 'linear', NaN);
    ok = ~isnan(y);
case 'woofer'
    f = fullfile(labD, 'data', sprintf('labD_vent_L%d.mat', arg));
    ok = exist(f, 'file') == 2; y = [];
    if ok
        addpath(fullfile(labD, 'matlab'));
        R0 = load(f); v = fb_from_Z(R0.fn, R0.Z);
        y = struct('fL', v.fL, 'fb', v.fb, 'fH', v.fH, 'fn', R0.fn(:), 'Z', R0.Z(:));
    end
case 'nf'
    f = fullfile(labD, 'data', sprintf('labD_nf_%s_L%d.mat', name, arg));
    ok = exist(f, 'file') == 2; y = nan(size(fn));
    if ok
        R0 = load(f);
        y = interp1(R0.fn, 20*log10(abs(R0.H)), fn, 'linear', NaN);
    end
end
end

function [T, hdr] = readcsv(cache, f)
if ~isKey(cache, f)
    T = readmatrix(f, 'NumHeaderLines', 1);
    fid = fopen(f); hdr = strsplit(strtrim(fgetl(fid)), ','); fclose(fid);
    cache(f) = {T, hdr};
end
c = cache(f); T = c{1}; hdr = c{2};
end
