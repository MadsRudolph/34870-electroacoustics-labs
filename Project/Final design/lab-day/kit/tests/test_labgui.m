function test_labgui(shotdir)
% TEST_LABGUI  The GUI without hardware: builds labgui in demo mode, drives it through the
%   lab day from code (P, S, F, a custom run, Z1, Z4, N1), and checks the lamps, the verdicts,
%   the advice, the saved files, the settings, both colour modes and every failure path.
%   Must print PASS.
%
%   test_labgui              screenshots go to a temporary folder
%   test_labgui(folder)      screenshots (PNG, made with exportapp) go to FOLDER

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'), fullfile(here, '..', 'core')); L = labpaths;
tmp = tempname; mkdir(tmp); dd = fullfile(tmp, '2026-11-12');
if nargin < 1, shotdir = fullfile(tmp, 'screenshots'); end
if ~exist(shotdir, 'dir'), mkdir(shotdir); end
shot = @(app, name) snap(app, fullfile(shotdir, [name '.png']));
has = @(c, s) any(contains(c, s, 'IgnoreCase', true));
ok = true;

% ---- 1. start
app = labgui('demo', 'datadir', dd, 'speed', 300, 'theme', 'light');
s = app.state();
ok = rep(all(strcmp(struct2cell(s.lamp), 'grey')) && ~s.goEnabled && s.demo, 'start: every lamp grey, Measure disabled, demo mode') && ok;
shot(app, '01_start_light');

% ---- 2. run P: instructions, measurement, file, lamps, advice
app.select('P'); s = app.state();
ok = rep(isequal(s.selected, {'P1', 'P2', 'P3'}) && s.goEnabled && has(s.instructions, 'BYPASSED') && ...
    has(s.instructions, 'DURING BEEPS 2') && has(s.instructions, 'Out 1 -10.3 dB'), 'select P: three steps, NOW / beeps 1 / beeps 2, MiniDSP bypass, gains') && ok;
m = app.measure(); s = app.state();
ok = rep(~isempty(m) && exist(fullfile(dd, 'P.mat'), 'file') == 2 && isfield(m, 'demo'), 'P measured and saved as P.mat (marked demo)') && ok;
ok = rep(all(strcmp({s.lamp.P1, s.lamp.P2, s.lamp.P3}, 'green')) && strcmp(s.lamp.S1, 'grey') && strcmp(s.verdict, 'OK'), 'P1-P3 lamps green, verdict OK, others still grey') && ok;
ok = rep(has(s.advice, 'Next: S') && has(s.log, 'Saved') && ~s.measuring && s.goEnabled, 'advice says what is next; file name in the log; Measure enabled again') && ok;
shot(app, '02_P_ok_light');

% ---- 3. wrong placement is caught and explained; a repeat never overwrites
app.fault('placement'); app.select('P1'); app.measure(); s = app.state();
ok = rep(~strcmp(s.lamp.P1, 'green') && has(s.advice, 'placement differs from Lab E') && exist(fullfile(dd, 'P1.mat'), 'file') == 2, ...
    ['wrong placement: lamp ' s.lamp.P1 ', advice says move the box/mic and redo P']) && ok;
app.fault('none'); app.select('P'); app.measure(); s = app.state();
ok = rep(exist(fullfile(dd, 'P_2.mat'), 'file') == 2 && strcmp(s.lamp.P1, 'green') && strcmp(s.viewed, 'P_2'), 'P again: saved as P_2.mat (P.mat untouched), lamp green again') && ok;

% ---- 4. run S with the woofer too loud -> advice gives the new Out 1 gain -> fixed
app.fault('woofer loud'); app.select('S'); app.measure(); s = app.state();
ok = rep(~strcmp(s.lamp.S1, 'green') && has(s.advice, 'Change Out 1 gain by -2.3 dB') && has(s.advice, '-12.6'), ...
    ['woofer 2.3 dB loud: lamp ' s.lamp.S1 ', advice "change Out 1 gain by -2.3 dB: set it to -12.6"']) && ok;
shot(app, '03_S_woofer_loud_light');
app.set('out1_gain', '-12,6'); s = app.state();        % typed with a decimal comma
ok = rep(s.settings.out1_gain == -12.6 && has(s.instructions, 'Out 1 -12.6 dB') && exist(fullfile(dd, 'settings.json'), 'file') == 2, ...
    'setting Out 1 = -12.6 (decimal comma accepted): shown in the instructions, stored in settings.json') && ok;
m = app.measure(); s = app.state();
ok = rep(all(strcmp({s.lamp.S1, s.lamp.S2, s.lamp.S3}, 'green')) && m.setup.out1_gain == -12.6 && exist(fullfile(dd, 'S_2.mat'), 'file') == 2, ...
    'S again: all green, the new gain is stored in the measurement, saved as S_2.mat') && ok;

% ---- 5. flips, a run of our own, and "not switched in time"
app.select('F'); s = app.state();
ok = rep(isequal(s.selected, {'F0', 'F1', 'F2'}) && has(s.instructions, 'NOW F0'), 'select F: F0, F1, F2 in the plan''s order') && ok;
app.measure(); s = app.state();
ok = rep(all(strcmp({s.lamp.F0, s.lamp.F1, s.lamp.F2}, 'green')) && has(s.advice, 'swap the tweeter'), 'F: green, reminder to swap the tweeter back') && ok;
app.select({'S3', 'S5', 'S4'}); s = app.state();
ok = rep(isequal(s.selected, {'S4', 'S5', 'S3'}), 'own run S4 + S5 + S3 ("all" is put last)') && ok;
app.measure();
ok = rep(exist(fullfile(dd, 'S4+S5+S3.mat'), 'file') == 2, 'saved as S4+S5+S3.mat') && ok;
app.fault('not switched'); app.select('A'); app.measure(); s = app.state();
ok = rep(strcmp(s.lamp.A2, 'red') && has(s.advice, 'switched in time'), 'state not switched during the beeps: A2 red, advice says so') && ok;
app.fault('none');

% ---- 6. Zi/Nfield station
app.select('Z1'); n0 = numel(dir(fullfile(dd, '*.mat')));
m = app.measure(); s = app.state();
ok = rep(isempty(m) && strcmp(s.verdict, 'ERROR') && has(s.advice, 'Series R') && numel(dir(fullfile(dd, '*.mat'))) == n0 && isvalid(app.fig), ...
    'Z1 without the series resistor: refused with the fix, nothing saved, window alive') && ok;
app.set('R_series', 32.9); app.measure(); s = app.state();
ok = rep(strcmp(s.lamp.Z1, 'green') && exist(fullfile(dd, 'Z1.mat'), 'file') == 2, 'Z1 with R = 32.9 ohm: green') && ok;
app.fault('dc offset'); app.select('Z4'); app.measure(); s = app.state();
ok = rep(strcmp(s.lamp.Z4, 'green') && has(s.log, 'DC offset'), 'Z4 woofer: green; AI0 DC offset noted in the log') && ok;
app.h.tabs.SelectedTab = app.h.tabZ; shot(app, '04_impedance_light');
app.fault('none'); app.select('N1'); app.measure(); app.select('N2'); app.measure(); s = app.state();
ok = rep(strcmp(s.lamp.N1, 'green') && strcmp(s.lamp.N2, 'green'), 'N1, N2 near field: green') && ok;
app.h.tabs.SelectedTab = app.h.tabNF; shot(app, '05_nearfield_light');
app.h.tabs.SelectedTab = app.h.tabAll; shot(app, '06_all_runs_light');

% ---- 7. failures of the course routine: caught, explained, nothing saved, window alive
n0 = numel(dir(fullfile(dd, '*.mat')));
app.fault('no umik'); app.select('P1'); app.measure(); s = app.state();
ok = rep(strcmp(s.verdict, 'ERROR') && has(s.advice, 'RESTART MATLAB') && isvalid(app.fig) && s.goEnabled, 'no UMIK: caught, fix shown (plug in, restart MATLAB)') && ok;
shot(app, '07_error_no_umik_light');
app.fault('no beeps'); app.measure(); s = app.state();
ok = rep(strcmp(s.verdict, 'ERROR') && has(s.advice, 'beeps.wav') && has(s.advice, 'cd('), 'beeps.wav not found: caught, fix shown (cd into the course folder or copy Beeps.wav)') && ok;
ok = rep(numel(dir(fullfile(dd, '*.mat'))) == n0, 'nothing saved by the failed measurements') && ok;
app.fault('quiet'); app.measure(); s = app.state();
ok = rep(has(s.log, 'Very small UMIK signal') && has(s.advice, 'WARNING'), 'small UMIK signal: warning with fix') && ok;
app.fault('clipping'); app.measure(); s = app.state();
ok = rep(has(s.log, 'Near full scale'), 'clipping: warning with fix') && ok;
app.fault('none');

% ---- 8. closing
app.close(); pause(0.2);
ok = rep(~isvalid(app.fig), 'window closes when not measuring') && ok;

% ---- 9. restart: settings, lamps and the colour mode come back from the day's folder
app = labgui('demo', 'datadir', dd, 'speed', 40);
s = app.state();
ok = rep(s.settings.out1_gain == -12.6 && s.settings.R_series == 32.9, 'restart: settings are back (Out 1 -12.6, R 32.9)') && ok;
ok = rep(strcmp(s.lamp.S1, 'green') && strcmp(s.lamp.Z1, 'green') && strcmp(s.lamp.A2, 'red') && strcmp(s.lamp.P2d, 'grey'), 'restart: lamps are back from the files') && ok;
app.fault('woofer loud'); app.select('S');            % (Out 1 is -12.6 now: this is the balanced case)
if isappdata(0, 'labgui_mid'), rmappdata(0, 'labgui_mid'); end
t = timer('StartDelay', 2.5, 'TimerFcn', @(~, ~) midshot(app, fullfile(shotdir, '08_measuring_light.png')));
start(t); app.measure(); stop(t); delete(t); app.fault('none');
mid = getappdata(0, 'labgui_mid');
ok = rep(~isempty(mid) && mid.measuring && ~mid.go && mid.alive, 'while measuring: Measure is disabled and closing the window is ignored') && ok;
ok = rep(exist(fullfile(shotdir, '08_measuring_light.png'), 'file') == 2, 'slow demo run: screenshot taken WHILE measuring (progress bar, "switch now")') && ok;

% ---- 10. light / dark
Cd = lab_palette('dark'); Cl = lab_palette('light');
app.theme('dark'); s = app.state();
ok = rep(strcmp(s.theme, 'dark') && isequal(app.fig.Color, Cd.bg) && isequal(app.h.axRun(1).Color, Cd.axbg) && ...
    isequal(app.h.tree.BackgroundColor, Cd.field) && isequal(app.h.log.FontColor, Cd.text), 'dark mode: window, tree, log and plot colours from the palette') && ok;
ok = rep(contrast(Cd.ok, Cd.field) > 4.5 && contrast(Cd.check, Cd.field) > 4.5 && contrast(Cd.bad, Cd.field) > 4.5 && ...
    contrast(Cl.ok, Cl.field) > 3 && contrast(Cl.check, Cl.field) > 3 && contrast(Cl.bad, Cl.field) > 3 && ...
    min(arrayfun(@(i) contrast(Cd.curves(i,:), Cd.axbg), 1:size(Cd.curves, 1))) > 4.5, 'OK / CHECK / BAD and the curve colours stand out on both backgrounds') && ok;
app.select('F'); shot(app, '09_F_ok_dark');
app.h.tabs.SelectedTab = app.h.tabZ; shot(app, '10_impedance_dark');
app.h.tabs.SelectedTab = app.h.tabAll; shot(app, '11_all_runs_dark');
app.close();
app = labgui('demo', 'datadir', dd, 'speed', 300); s = app.state();
ok = rep(strcmp(s.theme, 'dark') && isequal(app.fig.Color, Cd.bg), 'restart: the dark mode is remembered') && ok;
app.theme('light'); s = app.state();
ok = rep(strcmp(s.theme, 'light') && isequal(app.fig.Color, Cl.bg) && isequal(app.h.axRun(1).Color, Cl.axbg), 'back to light') && ok;

% ---- 11. export (always light), dashboard, copy to "USB"
app.theme('dark');
files = app.exportFigures();
img = imread(files{1}); app.theme('light');
ok = rep(numel(files) >= 7 && mean(img(:)) > 180, sprintf('export: %d dashboard PNGs, light although the GUI was dark', numel(files))) && ok;
set(groot, 'DefaultFigureVisible', 'off');
fd = app.dashboard();
ok = rep(~isempty(fd) && isvalid(fd), 'full dashboard opens') && ok; close(fd);
usb = fullfile(tmp, 'usb'); mkdir(usb);
t1 = app.copyData(usb); t2 = app.copyData(usb);
ok = rep(exist(fullfile(t1, 'P.mat'), 'file') == 2 && exist(fullfile(t1, 'settings.json'), 'file') == 2 && ~strcmp(t1, t2) && exist(t2, 'dir') == 7, ...
    'copy data: whole day folder copied; a second copy gets a new folder (nothing overwritten)') && ok;

% ---- 12. manual runs of the 10-Nov scripts: shown, originals untouched
app.close(); otherfigs(); app = labgui('demo', 'datadir', dd, 'speed', 300, 'theme', 'light');
src = {fullfile(L.data, 'project_R1_split_0.mat'), fullfile(L.data, 'project_R3_flip_0.mat'), fullfile(L.data, 'zinf_nf_cone_L200.mat')};
before = cellfun(@(f) dir(f), src); h0 = cellfun(@filehash, src, 'UniformOutput', false);
n = app.loadManual(src); s = app.state();
after = cellfun(@(f) dir(f), src);
ok = rep(n == 3 && has(s.log, 'Loaded manual run project_R1_split_0 as S1 + S2 + S3') && has(s.log, 'as F0 + F1 + F2') && has(s.log, 'as N1'), ...
    'manual runs loaded: R1 = S1+S2+S3, R3 = F0+F1+F2, near field = N1') && ok;
ok = rep(isequal([before.bytes], [after.bytes]) && isequal([before.datenum], [after.datenum]) && isequal(h0, cellfun(@filehash, src, 'UniformOutput', false)) && ...
    numel(dir(fullfile(L.data, '*.mat'))) == 9, 'the original files are untouched (size, date, content) and nothing was added next to them') && ok;
app.view('project_R1_split_0'); s = app.state();
ok = rep(strcmp(s.viewed, 'project_R1_split_0') && ~isempty(s.verdict), ['manual run R1 shown with a verdict: ' s.verdict]) && ok;
shot(app, '12_manual_run_light');
app.close();

% ---- 13. the real 10-Nov data in the GUI (a copy of the folder, so the repo is not touched)
nov = fullfile(tmp, '2026-11-10'); copyfile(fullfile(L.data, '2026-11-10'), nov);
app = labgui('datadir', nov, 'theme', 'light'); s = app.state();
ok = rep(s.nruns == 7 && ~strcmp(s.lamp.S1, 'grey') && ~strcmp(s.lamp.F1, 'grey') && ~strcmp(s.lamp.N1, 'grey') && ~s.demo, ...
    sprintf('real 10-Nov data: 7 runs listed, lamps S1 %s, S2 %s, S3 %s, F1 %s, N1 %s', s.lamp.S1, s.lamp.S2, s.lamp.S3, s.lamp.F1, s.lamp.N1)) && ok;
app.view('S'); shot(app, '13_nov10_real_S_light');
app.theme('dark'); app.view('F'); shot(app, '14_nov10_real_F_dark');
app.h.tabs.SelectedTab = app.h.tabAll; shot(app, '15_nov10_real_all_dark');
app.h.tabs.SelectedTab = app.h.tabNF; shot(app, '16_nov10_real_nearfield_dark');

% ---- 14. real mode without hardware: the course routine fails -> caught, fix shown, nothing saved
app.theme('light'); app.select('P1'); n0 = numel(dir(fullfile(nov, '*.mat')));
m = app.measure(); s = app.state();
ok = rep(isempty(m) && strcmp(s.verdict, 'ERROR') && isvalid(app.fig) && s.goEnabled && numel(dir(fullfile(nov, '*.mat'))) == n0, ...
    ['real mode, no hardware: the course routine''s error is caught: ' strtrim(s.advice{1})]) && ok;
otherfigs(); shot(app, '17_real_mode_error_light');
app.close();

% ---- 15. demo and real data cannot mix; the Run Section file covers every step
try
    lab_measure('P1', lab_setup(), fullfile(L.data, 'x'), 'demo', struct('speed', 1e4));
    ok = rep(false, 'demo data refused in the real data folder') && ok;
catch
    ok = rep(~exist(fullfile(L.data, 'x'), 'dir'), 'demo data refused in the real data folder') && ok;
end
txt = fileread(fullfile(L.kit, 'lab_run.m')); P = lab_plan();
miss = P(cellfun(@(id) isempty(regexp(txt, ['%% ' id '\.'], 'once')), {P.id}));
ok = rep(isempty(miss), ['lab_run.m has a section for every step ' strjoin({miss.id}, ' ')]) && ok;

set(groot, 'DefaultFigureVisible', 'on');
if ok, fprintf('\nPASS   (screenshots in %s)\n', shotdir); else, error('test_labgui FAILED'); end
end

% ---------------------------------------------------------------------------
function snap(app, file)
try
    app.screenshot(file);
catch e
    fprintf('  (no screenshot %s: %s)\n', file, e.message);
end
end

function otherfigs()
% close figures other windows left open (the course routine plots; a tiling desktop then shrinks the GUI)
for f = findall(groot, 'Type', 'figure')'
    if ~strcmp(f.Tag, 'labgui'), try, close(f, 'force'); catch, end, end
end
drawnow; pause(1);
end

function midshot(app, file)
% runs from a timer in the middle of a measurement
try
    app.close();                                   % must be ignored while measuring
    s = app.state();
    setappdata(0, 'labgui_mid', struct('measuring', s.measuring, 'go', s.goEnabled, 'alive', isvalid(app.fig)));
    exportapp(app.fig, file);
catch
end
end

function c = contrast(a, b)
% WCAG contrast ratio of two sRGB colours
lum = @(c) [0.2126 0.7152 0.0722] * (((c <= 0.03928) .* c/12.92) + ((c > 0.03928) .* ((c + 0.055)/1.055).^2.4))';
la = lum(a); lb = lum(b);
c = (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
end

function hsh = filehash(f)
fid = fopen(f); b = fread(fid, Inf, '*uint8'); fclose(fid);
md = java.security.MessageDigest.getInstance('MD5'); md.update(b);
hsh = sprintf('%02x', typecast(md.digest(), 'uint8'));
end

function ok = rep(c, msg)
if c, fprintf('  ok    %s\n', msg); else, fprintf('  FAIL  %s\n', msg); end
ok = c;
end
