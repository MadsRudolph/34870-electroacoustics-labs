function test_lab()
% TEST_LAB  The whole kit without hardware: must print PASS.
%   Stand-ins for the two course routines "measure" the expected curves themselves
%   (level -6 dB, random latency), so every verdict must come out OK; then a wrong
%   channel balance and a wrong placement must be caught, and the dashboard (all
%   tabs) must be drawn and saved.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'core')); L = labpaths;   % all folders + the called code
set(groot, 'DefaultFigureVisible', 'off');
tmp = tempname; mkdir(tmp); dd = fullfile(tmp, '2026-11-12');
labD = L.labDdata;
w = @(name, lines) writestub(fullfile(tmp, [name '.m']), lines);
w('meas_mag_spec2_SoundCard_LabE', {
 'function [fn,specn,f,spec,ch]=meas_mag_spec2_SoundCard_LabE(f1,f2,n_oct,fres,Nav,UmikSN,IncAngle,Nmeas)'
 'S = load(fullfile(fileparts(mfilename(''fullpath'')), ''stub.mat''));'
 'assert(size(S.H,2) == Nmeas, ''stub has %d states, routine asked for %d'', size(S.H,2), Nmeas);'
 'fn = S.f(:); Nf = numel(fn); tau = 0.047 + 1e-3*rand;'
 'specn = zeros(Nf,2,Nmeas);'
 'for k = 1:Nmeas, V = 0.05*exp(1j*2*pi*rand(Nf,1)); specn(:,:,k) = [V, V.*0.5.*S.H(:,k).*exp(-1j*2*pi*fn*tau)]; end'
 'f = (0:9)''; spec = zeros(10,2,Nmeas); ch = 0.2*ones(100,2,Nmeas);'
 'if Nmeas == 1, specn = specn(:,:,1); spec = spec(:,:,1); ch = ch(:,:,1); end'
 'end'});
w('meas_mag_spec2_LabD', {
 'function [fn,specn,f,spec,ch]=meas_mag_spec2_LabD(f1,f2,n_oct,fres,Nav)'
 'S = load(fullfile(fileparts(mfilename(''fullpath'')), ''stub.mat''));'
 'fn = S.fn(:); Va = 0.2*exp(1j*2*pi*rand(size(fn)));'
 'if S.nf, V1 = Va.*S.X; else, V1 = Va.*S.X./(S.R + S.X); end'
 'specn = [Va, V1]; f = (0:9)''; spec = zeros(10,2); ch = [0.3*sin((1:4800)''/50), 0.1*sin((1:4800)''/50)];'
 'end'});
addpath(tmp);
csv = @(a) fullfile(L.model, a);
[T0, h0] = readcsv(csv('expected_on.csv'));
col = @(T, h, s) T(:, strcmp(h, [s '_re'])) + 1j*T(:, strcmp(h, [s '_im']));
chamber = @(states, gain) savestub(tmp, struct('f', T0(:,1), ...
    'H', cell2mat(cellfun(@(s) col(T0, h0, s), states, 'UniformOutput', false)) .* gain));
opt = {'confirm', false, 'datadir', dd, 'save', false};
ok = true;

chamber({'byp_woofer', 'byp_mid', 'byp_tw'}, [1 1 1]);
m = lab('P', opt{:}); R = lab_check(m);
ok = rep(all(strcmp({R.verdict}, 'OK')), sprintf('placement P1-P3 all OK (%s)', sprintf('%.2f ', [R.shape]))) && ok;
ok = rep(strcmp(m.label, 'P') && isequal(m.ids, {'P1', 'P2', 'P3'}), 'lab P = one run of P1, P2, P3') && ok;

chamber({'byp_woofer'}, 1);
s = load(fullfile(dd, 'P.mat'));    % placement wrong: 5 dB ripple across the band
fr = T0(:,1); bad = (1 + 0.8*sin(2*pi*log2(fr))) ; savestub(tmp, struct('f', fr, 'H', col(T0, h0, 'byp_woofer') .* bad));
m = lab('P1', opt{:}); R = lab_check(m);
ok = rep(~strcmp(R(1).verdict, 'OK') && contains(R(1).msg, 'placement'), ['wrong placement caught: ' R(1).msg]) && ok;

chamber({'woofer', 'midtw', 'all'}, [1 1 1]);
m = lab('S', opt{:}); R = lab_check(m);
ok = rep(all(strcmp({R.verdict}, 'OK')) && any(strcmp({R.id}, 'bal')) && any(strcmp({R.id}, 'sum')), ...
    'run S: S1-S3, balance and sum check all OK') && ok;

chamber({'woofer', 'midtw', 'all'}, [2 1 1]);    % woofer 6 dB too loud
m = lab('S', opt{:}); R = lab_check(m); b = R(strcmp({R.id}, 'bal'));
ok = rep(strcmp(b.verdict, 'BAD') && contains(b.msg, '-6.0 dB'), ['wrong balance caught: ' b.msg]) && ok;

chamber({'all', 'flipW', 'flipT'}, [1 1 1]);
m = lab('F', opt{:}); R = lab_check(m); n1 = R(strcmp({R.id}, 'F1n')); n2 = R(strcmp({R.id}, 'F2n'));
ok = rep(strcmp(n1.verdict, 'OK') && strcmp(n2.verdict, 'OK'), sprintf('flips: %s | %s', n1.msg, n2.msg)) && ok;

[Tz, hz] = readcsv(csv('expected_zi.csv'));
savestub(tmp, struct('fn', Tz(:,1), 'X', col(Tz, hz, 'Zboth'), 'nf', false, 'R', 32.9));
try
    lab('Z1', opt{:}); ok = rep(false, 'Z1 without R_series refused') && ok;
catch
    ok = rep(true, 'Z1 without R_series refused') && ok;
end
zo = [opt, {'set', struct('R_series', 32.9)}];
m = lab('Z1', zo{:}); R = lab_check(m);
ok = rep(strcmp(R.verdict, 'OK') && abs(R.x(1) - 4.40) < 0.05, ['Z1 board: ' R.msg]) && ok;
W = load(fullfile(labD, 'labD_vent_L160.mat'));
savestub(tmp, struct('fn', W.fn, 'X', W.Z, 'nf', false, 'R', 32.9));
m = lab('Z4', zo{:}); R = lab_check(m);
ok = rep(strcmp(R.verdict, 'OK'), ['Z4 woofer: ' R.msg]) && ok;
N = load(fullfile(labD, 'labD_nf_cone_L160.mat'));
savestub(tmp, struct('fn', N.fn, 'X', N.H, 'nf', true, 'R', NaN));
m = lab('N1', zo{:}); R = lab_check(m);
ok = rep(strcmp(R.verdict, 'OK'), ['N1 near field: ' R.msg]) && ok;

fig = lab_dash(dd, 'save', true);
pngs = dir(fullfile(dd, 'figures', '*.png'));
ok = rep(numel(pngs) >= 7, sprintf('dashboard drawn, %d tabs saved as PNG', numel(pngs))) && ok;
close(fig);
lab('list', opt{:});

rmpath(tmp);
if ok, fprintf('\nPASS   (dashboard PNGs kept in %s)\n', fullfile(dd, 'figures')); else, error('test_lab FAILED'); end
end

function writestub(file, lines)
fid = fopen(file, 'w'); fprintf(fid, '%s\n', lines{:}); fclose(fid);
end

function savestub(tmp, s) %#ok<INUSD>
save(fullfile(tmp, 'stub.mat'), '-struct', 's');
end

function [T, hdr] = readcsv(f)
T = readmatrix(f, 'NumHeaderLines', 1);
fid = fopen(f); hdr = strsplit(strtrim(fgetl(fid)), ','); fclose(fid);
end

function ok = rep(c, msg)
if c, fprintf('  ok    %s\n', msg); else, fprintf('  FAIL  %s\n', msg); end
ok = c;
end
