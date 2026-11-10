function test_labgui(shotdir)
% TEST_LABGUI  The GUI in demo mode, driven from code: must print PASS.
%   Builds labgui('demo') on a temporary day folder and goes through the day:
%   P, S (balanced, then Out 1 4 dB too hot), F, a run with a state not switched in
%   time, a missing UMIK, Z1 without and with the series R, Z4, N1, N2; every view;
%   a restart (settings kept), copy to "USB", export, and "Load manual runs" on the
%   real 10-Nov files (which must stay untouched). Screenshots -> SHOTDIR
%   (default kit/tests/screenshots). Needs a display (uifigure).

here = fileparts(mfilename('fullpath'));
kit = fileparts(here); addpath(kit, fullfile(kit, 'core'));
L = labpaths();
if nargin < 1, shotdir = fullfile(here, 'screenshots'); end
if ~exist(shotdir, 'dir'), mkdir(shotdir); end
set(groot, 'DefaultFigureVisible', 'off');
tmp = tempname; dd = fullfile(tmp, '2026-11-12');
shot = @(app, name) app.screenshot(fullfile(shotdir, [name '.png']));
ok = true;

app = labgui('demo', 'datadir', dd, 'speed', 0, 'quiet', true, 'position', [40 40 1560 950]);
c = onCleanup(@() delete(app));
ok = rep(app.Demo && strcmp(app.Sel, 'P'), 'demo app starts on step P (nothing measured yet)') && ok;
ok = rep(app.S.out1_gain == -10.3, 'settings from lab_setup.m (Out 1 -10.3 dB)') && ok;
shot(app, '00_start');

% ---- P: placement
app.select('P'); ok = rep(app.measure(), 'P measured') && ok;
ok = rep(all(strcmp(cellfun(@app.verdict, {'P1', 'P2', 'P3'}, 'UniformOutput', false), 'OK')), 'P1-P3 lamps green') && ok;
ok = rep(exist(fullfile(dd, 'P.mat'), 'file') == 2 && exist(fullfile(dd, 'figures', 'P.png'), 'file') == 2, ...
    'P.mat saved + its graph figures/P.png') && ok;
shot(app, '01_after_P');

% ---- S: balanced
app.select('S'); app.measure();
v = cellfun(@app.verdict, {'S1', 'S2', 'S3', 'S:bal', 'S:sum'}, 'UniformOutput', false);
ok = rep(all(strcmp(v, 'OK')), ['S1-S3, balance and sum check green: ' strjoin(v, ' ')]) && ok;
ok = rep(strcmp(app.LastVerdict, 'OK'), 'verdict panel says OK') && ok;
shot(app, '02_after_S');

% ---- S with Out 1 4 dB too hot: the GUI must say what to change
app.setSetting('out1_gain', -6.3);
ok = rep(contains(fileread(fullfile(dd, 'session.json')), '-6.3'), 'setting saved to session.json at once') && ok;
app.select('S'); app.measure();
adv = strjoin(app.LastAdvice, newline);
ok = rep(strcmp(app.verdict('S:bal'), 'BAD') && contains(adv, 'Out 1 gain by -4.0 dB'), ...
    'woofer 4 dB too hot: balance lamp red, advice "change Out 1 gain by -4.0 dB"') && ok;
ok = rep(exist(fullfile(dd, 'S_2.mat'), 'file') == 2 && exist(fullfile(dd, 'S.mat'), 'file') == 2, ...
    'second S saved as S_2.mat (nothing overwritten)') && ok;
s2 = load(fullfile(dd, 'S_2.mat'), 'setup', 'demo');
ok = rep(s2.setup.out1_gain == -6.3 && s2.demo, 'settings + demo flag stored in the file') && ok;
shot(app, '03_balance_BAD');
app.setSetting('out1_gain', -10.3);

% ---- F: flips
app.select('F'); app.measure();
v = cellfun(@app.verdict, {'F0', 'F1', 'F2', 'F:F1n', 'F:F2n'}, 'UniformOutput', false);
ok = rep(all(strcmp(v, 'OK')), ['F0-F2 and both notches green: ' strjoin(v, ' ')]) && ok;

% ---- live status while measuring: the beeps prompt (demo at 1/50 of real time)
seen = containers.Map();
app.setSpeed(0.02); app.select('S');
tm = timer('StartDelay', 1.7, 'TimerFcn', @(~, ~) grab(app, seen, fullfile(shotdir, '02b_during_beeps.png')));
start(tm); app.measure(); stop(tm); delete(tm); app.setSpeed(0);
ok = rep(isKey(seen, 'status') && contains(seen('status'), 'BEEPS 1 - SWITCH NOW to [S2]'), ...
    sprintf('live status during beeps 1: "%s"', strtrim(char(seen.values({'status'}))))) && ok;

% ---- a state not switched in time (demo fault) -> sum check
app.setFault('switch'); app.select('S'); app.measure(); app.setFault('none');
ok = rep(~strcmp(app.verdict('S:sum'), 'OK') && contains(strjoin(app.LastAdvice, ' '), 'Sum check'), ...
    sprintf('state not switched in time caught by the sum check (%s)', app.verdict('S:sum'))) && ok;
app.select('S'); app.measure();     % good again

% ---- missing UMIK: error shown, app alive, nothing saved
n0 = numel(dir(fullfile(dd, '*.mat')));
app.setFault('noumik'); app.select('S4'); saved = app.measure(); app.setFault('none');
ok = rep(~saved && contains(app.LastError, 'Umik') && strcmp(app.LastVerdict, 'ERROR') && ...
    contains(strjoin(app.LastAdvice, ' '), 'RESTART MATLAB') && isvalid(app.Fig) && ...
    numel(dir(fullfile(dd, '*.mat'))) == n0, 'no UMIK: error + fix shown, app alive, nothing saved') && ok;
shot(app, '04_error_noUMIK');
app.setFault('nobeeps'); app.measure(); app.setFault('none');
ok = rep(contains(strjoin(app.LastAdvice, ' '), 'Beeps.wav'), 'beeps.wav missing: the fix says where to copy it from') && ok;
app.measure(); app.select('S5'); app.measure();
ok = rep(strcmp(app.verdict('S4'), 'OK') && strcmp(app.verdict('S5'), 'OK') && ...
    contains(strjoin(app.LastAdvice, ' '), 'tweeter vs midrange'), 'S4, S5 OK and the tweeter-vs-mid level shown') && ok;

% ---- Zi station: Z1 without, then with the series resistor
app.select('Z1'); app.measure();
ok = rep(contains(strjoin(app.LastAdvice, ' '), 'multimeter') && strcmp(app.verdict('Z1'), ''), ...
    'Z1 without R_series refused, with the fix') && ok;
app.setSetting('R_series', 32.9); app.select('Z1'); app.measure();
ok = rep(strcmp(app.verdict('Z1'), 'OK'), 'Z1 board impedance OK') && ok;
shot(app, '05_Z1');
for id = {'Z2', 'Z3', 'Z4', 'N1', 'N2'}, app.select(id{1}); app.measure(); end
v = cellfun(@app.verdict, {'Z2', 'Z3', 'Z4', 'N1', 'N2'}, 'UniformOutput', false);
ok = rep(all(strcmp(v, 'OK')), ['Z2, Z3, Z4, N1, N2: ' strjoin(v, ' ')]) && ok;

% ---- the views
for vw = {'all', 'phase', 'zboard', 'zwoofer', 'nf', 'run'}
    app.setView(vw{1}); shot(app, ['06_view_' vw{1}]);
end
ok = rep(true, 'every view drawn') && ok;
app.select('A'); shot(app, '07_select_A');

% ---- dark mode: everything recoloured, saved for the session, report figures stay light
app.setView('run'); app.select('S'); app.setTheme('dark');
shot(app, '10_dark_S'); app.select('Z1'); shot(app, '11_dark_Z1');
app.setView('all'); shot(app, '12_dark_allruns'); app.setView('run');
app.select('S4'); shot(app, '13_dark_not_measured');
app.setFault('noumik'); app.select('S'); app.measure(); app.setFault('none'); shot(app, '14_dark_error');
app.select('S'); app.measure();
img = imread(fullfile(dd, 'figures', [app.ShownFile '.png']));
ok = rep(mean(img(:)) > 200, sprintf('dark mode: the saved run graph is still a light report figure (mean %.0f)', mean(img(:)))) && ok;
ok = rep(contains(fileread(fullfile(dd, 'session.json')), '"gui_theme": "dark"') || ...
    contains(fileread(fullfile(dd, 'session.json')), '"gui_theme":"dark"'), 'dark mode saved in session.json') && ok;

% ---- restart: settings and lamps come back
delete(app);
app = labgui('demo', 'datadir', dd, 'speed', 0, 'quiet', true, 'position', [40 40 1560 950]);
c = onCleanup(@() delete(app)); %#ok<NASGU>
ok = rep(app.S.R_series == 32.9 && strcmp(app.verdict('P1'), 'OK') && strcmp(app.Sel, 'A') && strcmp(app.Theme, 'dark'), ...
    'restart: R_series and dark mode kept (session.json), lamps restored, opens on the next step (A)') && ok;
shot(app, '15_dark_restart');
app.setTheme('light');

% ---- copy to "USB", export
usb = fullfile(tmp, 'usb'); mkdir(usb);
d1 = app.copyDay(usb); d2 = app.copyDay(usb);
ok = rep(exist(fullfile(d1, 'P.mat'), 'file') == 2 && ~strcmp(d1, d2) && endsWith(d2, '_2'), ...
    'copy to USB works, a second copy does not overwrite the first') && ok;
app.exportFigures();
ok = rep(numel(dir(fullfile(dd, 'figures', 'Plan.png'))) == 1 && ~isempty(dir(fullfile(dd, 'figures', 'labgui_*.png'))), ...
    'export: dashboard tabs + window picture in figures/') && ok;

% ---- manual runs (Tuesday's scripts): the real 10-Nov files, read only
src = [dir(fullfile(L.data, 'project_*.mat')); dir(fullfile(L.data, 'zinf_*.mat'))];
files = fullfile({src.folder}, {src.name});
before = cellfun(@filehash, files, 'UniformOutput', false);
d10 = fullfile(tmp, '2026-11-10');
app10 = labgui('demo', 'datadir', d10, 'speed', 0, 'quiet', true, 'position', [40 40 1560 950]);
made = app10.importManual(files);
again = app10.importManual(files);
after = cellfun(@filehash, files, 'UniformOutput', false);
ok = rep(numel(made) == 6 && isempty(again), sprintf('manual runs: %d imported (3 marked unused skipped), none twice', numel(made))) && ok;
ok = rep(isequal(before, after), 'the original manual files are unchanged') && ok;
v = cellfun(@app10.verdict, {'S1', 'S4', 'S5', 'F1', 'N1', 'N2'}, 'UniformOutput', false);
ok = rep(~any(cellfun(@isempty, v)), ['10-Nov runs shown with lamps: ' strjoin(v, ' ')]) && ok;
app10.setView('all'); shot(app10, '08_manual_10Nov_allruns');
app10.select('S'); shot(app10, '09_manual_10Nov_S');
delete(app10);

% ---- demo never writes into the real data folder
try
    x = labgui('demo', 'datadir', fullfile(L.data, 'x'), 'quiet', true); delete(x);
    ok = rep(false, 'demo refused in lab-day/data') && ok;
catch
    ok = rep(true, 'demo mode refuses to write into lab-day/data') && ok;
end

delete(app);
rmdir(tmp, 's');
if ok, fprintf('\nPASS   (screenshots in %s)\n', shotdir); else, error('test_labgui FAILED'); end
end

function grab(app, seen, png)
seen('status') = app.StatusText;
try, app.screenshot(png); catch, end
end

function h = filehash(f)
fid = fopen(f, 'r'); b = fread(fid, Inf, '*uint8'); fclose(fid);
d = dir(f);
h = sprintf('%d-%.6f-%d', numel(b), d.datenum, sum(double(b) .* mod(1:numel(b), 251)'));
end

function ok = rep(c, msg)
if c, fprintf('  ok    %s\n', msg); else, fprintf('  FAIL  %s\n', msg); end
ok = c;
end
