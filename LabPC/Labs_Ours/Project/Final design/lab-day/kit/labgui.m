classdef labgui < handle
% LABGUI  The lab day with buttons: pick a step, read what to set up, press Measure,
%   see the graph and the verdict (green OK / orange CHECK / red BAD) and what to do next.
%
%   labgui              real measurements (lab PC): data -> lab-day/data/<today>/
%   labgui('demo')      rehearsal without hardware: stand-in routines (the expected curves,
%                       level -6 dB, random latency, a little noise), data -> lab-day/demo_data/<today>/
%
%   Options (Name, Value): 'datadir' (another day folder), 'speed' (demo: real seconds per
%   simulated second, default 0.04 = a 4-minute run takes 10 s), 'quiet' (no pop-up dialogs,
%   for tests), 'visible' (default true), 'Nav' (chamber averages, default 64), 'position'
%   ([x y w h] of the window; default: as large as the biggest screen allows, max 1560 x 950).
%
%   Left: every step with a lamp (grey = not measured). Blue buttons measure a whole run
%   (P1-P3, S1-S3, F0-F2, A1-A3 in one go: switch during the beeps).
%   Centre: what to set up NOW and during the beeps, the Measure button, the graphs, the verdict.
%   Right: the settings of the day (stored in every file and in <day>/session.json, which the
%   'lab' commands read too), data buttons (dashboard, export, copy to USB, load manual runs), log.
%
%   The same methods the buttons call can be called from code (see test_labgui):
%   app.select('S'), app.measure(), app.setSetting('out1_gain', -12), app.setView('all'),
%   app.importManual(files), app.copyDay(folder), app.exportFigures(), app.screenshot(png),
%   app.setTheme('dark').  Colours: Light/Dark in the settings (all colours come from
%   core/gui_palette.m, so dark mode also works on MATLAB versions before R2025a).
%   Report figures (exported graphs, dashboard PNGs) are always drawn light.

    properties (SetAccess = private)
        Fig                      % the uifigure
        Demo = false
        DataDir = ''
        S                        % settings in force (lab_setup.m + session.json)
        Runs = {}                % every run of the day (lab_runs), oldest first
        Sel = ''                 % selection: a run letter ('P') or a step id ('P1')
        ShownFile = ''           % run shown in the graphs
        View = 'run'
        Busy = false
        LastError = ''           % message of the last failed measurement ('' after a good one)
        LastVerdict = ''
        LastAdvice = {}
        StatusText = ''          % the status line under the instructions (e.g. 'BEEPS 1 - SWITCH NOW ...')
        Theme = 'light'          % 'light' | 'dark' (Colours menu; saved in session.json)
        Pal                      % gui_palette(Theme)
        Fault = 'none'           % demo only: which fault the stand-ins simulate
        Speed = 0.04
        Quiet = false
        Nav = 64
        Verdicts                 % containers.Map: lamp key -> 'OK' | 'CHECK' | 'BAD'
    end
    properties (Access = private)
        UI = struct()
        Lamps                    % containers.Map: key -> uilamp
        Times                    % containers.Map: key -> uilabel
        Buttons                  % containers.Map: selection -> uibutton
        Timer = []
        CancelFlag = false
        T0 = []
        Inst = []
        BadLogged = {}
        StatusKind = 'ready'
        NothingText = 'Nothing measured yet. Pick a step on the left and press Measure.'
        SelInst = []                          % lab_instructions of the selection
        SwState = struct('big', 1, 'beeps', 0) % what the switchboard indicators show
    end
    properties (Constant, Access = private)
        FIELDS = {'UmikSN', 'UMIK serial', 'text'; 'amp_volume', 'Amplifier volume', 'text'; ...
            'out1_gain', 'Out 1 gain (dB)', 'num'; 'out2_gain', 'Out 2 gain (dB)', 'num'; ...
            'vent_mm', 'Open vent (mm)', 'num'; 'R_series', 'Series R (ohm)', 'num'; ...
            'NexusVperPa', 'Nexus (V/Pa)', 'num'; 'T_celsius', 'Temperature (C)', 'num'; ...
            'placement', 'Placement', 'text'; 'notes', 'Notes of the day', 'text'}
        FAULTS = {'none', 'placement', 'switch', 'noumik', 'nobeeps', 'clip', 'noNI'}
    end

    methods
        % =================================================================== start
        function app = labgui(varargin)
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, 'core'));
            args = varargin; demo = false;
            if ~isempty(args) && (ischar(args{1}) || isstring(args{1})) && strcmpi(args{1}, 'demo')
                demo = true; args(1) = [];
            end
            p = inputParser;
            p.addParameter('datadir', '');
            p.addParameter('speed', 0.04);
            p.addParameter('quiet', false);
            p.addParameter('visible', true);
            p.addParameter('Nav', 64);
            p.addParameter('position', []);
            p.parse(args{:});
            o = p.Results;
            L = labpaths();
            S0 = lab_setup();
            datadir = char(o.datadir);
            if isempty(datadir)
                if demo, datadir = fullfile(L.demo, S0.date); else, datadir = fullfile(L.data, S0.date); end
            end
            if demo && startsWith(canon(datadir), canon(L.data))
                error('labgui:demo', 'Demo mode never writes into lab-day/data (real data). Use another folder.');
            end
            app.Demo = demo; app.DataDir = datadir; app.Speed = o.speed; app.Quiet = o.quiet; app.Nav = o.Nav;
            [app.S, src] = lab_settings(datadir);
            app.Theme = 'light';
            if isfield(app.S, 'gui_theme') && strcmpi(app.S.gui_theme, 'dark'), app.Theme = 'dark'; end
            app.Pal = gui_palette(app.Theme);
            app.Verdicts = containers.Map();
            app.Lamps = containers.Map(); app.Times = containers.Map(); app.Buttons = containers.Map();
            app.build(o.position);
            if demo
                app.log('DEMO MODE: stand-in routines, nothing is measured. Data go to a separate demo folder.');
            end
            app.log(sprintf('Day folder: %s', datadir));
            app.log(sprintf('Settings from %s.', src));
            if ~demo, app.preflight(); end
            app.refresh();
            [~, ~, nxt] = lab_advice([], app.Runs);
            if isempty(nxt), nxt = 'P'; end
            app.select(nxt);
            if ~isempty(app.Runs), app.showRun(app.Runs{end}.file); end
            app.applyTheme();
            if o.visible, app.Fig.Visible = 'on'; end
            if isempty(o.position)                % a lab station: use the whole screen
                try, app.Fig.WindowState = 'maximized'; catch, end
            end
            drawnow;
        end

        function delete(app)
            app.stopTimer();
            if ~isempty(app.Fig) && isvalid(app.Fig), delete(app.Fig); end
        end

        % =================================================================== actions
        function select(app, what)
            % SELECT  Show what to do for a run letter ('S') or a step ('S4').
            if app.Busy, return; end
            try
                [st, ids, label] = lab_steps(what);
            catch err
                app.log(['Cannot select ' char(what) ': ' err.message]); return
            end
            app.Sel = char(what);
            I = lab_instructions(st, app.S, app.Nav);
            txt = [I.lines(1:end-1), {'', ['>> ' I.lines{end}]}, ...
                {'', sprintf('Takes about %s.  %s', dur(I.secs), I.timeline)}];
            if ~app.Demo && strcmp(st(1).station, 'chamber') && numel(st) > 1
                txt{end+1} = 'The beeps (~30 s) come from the speakers: switch only then.';
            end
            app.UI.Instr.Value = txt;
            app.SelInst = I;
            app.showSwitches(struct('big', 1, 'beeps', 0));
            app.UI.Instr.Parent.Parent.Title = sprintf('What to do: %s  (%s)', label, strjoin(ids, ' + '));
            app.UI.Measure.Text = sprintf('Measure %s', label);
            app.status(sprintf('Ready: set up as above, then press "Measure %s" (about %s).', label, dur(I.secs)), 'ready');
            app.colourButtons();
            if strcmp(st(1).station, 'chamber')
                app.UI.Tabs.SelectedTab = app.UI.TabCh;
                app.UI.Station.Text = 'Anechoic chamber';
            else
                app.UI.Tabs.SelectedTab = app.UI.TabZi;
                app.UI.Station.Text = 'Zi / near field (NI card)';
            end
            % show the latest run of this step; if there is none, say so (never an older, other run)
            for i = numel(app.Runs):-1:1
                if any(ismember(ids, app.Runs{i}.ids)), app.showRun(app.Runs{i}.file); return; end
            end
            app.ShownFile = ''; app.View = 'run'; app.UI.ViewDD.Value = 'run';
            app.draw('nothing', sprintf('%s is not measured yet today. Set up as described above and press Measure.', label));
            app.setVerdict('-', {sprintf('%s (%s): not measured yet.', label, strjoin(ids, ' + ')), ...
                'Other runs: pick one under "Run:" above the graph, or "Show:" for the overviews.'});
        end

        function ok = measure(app)
            % MEASURE  Measure the selection now. Returns true when a file was saved.
            ok = false;
            if app.Busy || isempty(app.Sel), return; end
            [st, ids, label] = lab_steps(app.Sel);
            S = app.S;
            I = lab_instructions(st, S, app.Nav);
            args = {'datadir', app.DataDir, 'Nav', app.Nav, 'note', app.UI.Note.Value, 'demo', app.Demo};
            if app.Demo
                opt = struct('speed', app.Speed, 'fault', app.Fault, 'wait', @(t) app.demoWait(t));
                args = [args, {'chamber_fun', @(varargin) lab_demo('chamber', st, S, opt, varargin{:}), ...
                    'zinf_fun', @(varargin) lab_demo('zinf', st, S, opt, varargin{:})}];
            end
            app.setBusy(true, I);
            restore = onCleanup(@() app.setBusy(false)); %#ok<NASGU>   % also after Ctrl+C
            app.log(sprintf('Measuring %s (%s), about %s ...', label, strjoin(ids, ' '), dur(I.secs)));
            drawnow;
            try
                [m, file, warn] = lab_measure(app.Sel, S, args{:});
            catch err
                app.fail(err, label);
                return
            end
            ok = true;
            app.LastError = '';
            app.log(sprintf('Saved %s', app.rel(file)));
            for i = 1:numel(warn), app.log(['WARNING: ' warn{i}]); end
            app.UI.Note.Value = '';
            app.refresh();
            app.showRun(m.file);
            app.status(sprintf('Done: %s saved. Verdict %s (see below).', m.file, app.LastVerdict), 'ready');
            app.saveRunFigure(m.file);
        end

        function cancel(app)
            % CANCEL  Demo only: stop the running stand-in measurement (nothing is saved).
            app.CancelFlag = true;
        end

        function nextStep(app)
            % NEXTSTEP  Select the next step of the plan that is not OK yet.
            [~, ~, nxt] = lab_advice([], app.Runs);
            if isempty(nxt), app.log('Every step of the plan is OK.'); else, app.select(nxt); end
        end

        function setSetting(app, key, val)
            % SETSETTING  Change one setting of the day (saved to session.json at once).
            assert(isfield(app.S, key), 'Unknown setting %s', key);
            old = app.S.(key);
            if isnumeric(old) && ischar(val), val = str2double(val); end
            app.S.(key) = val;
            try
                lab_settings(app.DataDir, app.S);
            catch err
                app.log(['Could not save session.json: ' err.message]);
            end
            if isfield(app.UI.Fields, key), app.UI.Fields.(key).Value = fmt(val); end
            if ~isequaln(old, val), app.log(sprintf('Setting %s: %s -> %s', key, fmtlog(old), fmtlog(val))); end
            if ~isempty(app.Sel), sel = app.Sel; shown = app.ShownFile; app.select(sel); if ~isempty(shown), app.showRun(shown); end, end
        end

        function setFault(app, f)
            % SETFAULT  Demo only: 'none' | 'placement' | 'switch' | 'noumik' | 'nobeeps' | 'clip' | 'noNI'
            assert(any(strcmp(app.FAULTS, f)), 'Unknown fault %s', f);
            app.Fault = f;
            if isfield(app.UI, 'Fault'), app.UI.Fault.Value = f; end
            app.log(sprintf('Demo fault: %s', f));
        end

        function setTheme(app, mode)
            % SETTHEME  'light' or 'dark' (saved in session.json, so a restart keeps it).
            mode = lower(char(mode)); assert(any(strcmp(mode, {'light', 'dark'})), 'Theme: light or dark');
            app.Theme = mode; app.Pal = gui_palette(mode);
            app.UI.ThemeDD.Value = mode;
            app.applyTheme();
            if ~strcmp(app.S.gui_theme, mode)
                app.S.gui_theme = mode;
                try, lab_settings(app.DataDir, app.S); catch, end
                app.log(sprintf('Colours: %s', mode));
            end
        end

        function setSpeed(app, sp)
            % SETSPEED  Demo only: real seconds per simulated second (0 = instant).
            app.Speed = sp;
        end

        function setView(app, v)
            % SETVIEW  'run' | 'all' | 'phase' | 'zboard' | 'zwoofer' | 'nf'
            app.View = v;
            app.UI.ViewDD.Value = v;
            if strcmp(v, 'run')
                if isempty(app.ShownFile) && ~isempty(app.Runs), app.ShownFile = app.Runs{end}.file; end
                if isempty(app.ShownFile)
                    app.draw('nothing', 'Nothing measured yet. Pick a step on the left and press Measure.');
                else
                    app.showRun(app.ShownFile);
                end
            else
                app.draw(v, app.Runs);
            end
        end

        function showRun(app, file)
            % SHOWRUN  Graphs, verdict and advice of one saved run (file name without .mat).
            i = find(cellfun(@(m) strcmp(m.file, file), app.Runs), 1);
            if isempty(i), return; end
            m = app.Runs{i};
            app.ShownFile = file; app.View = 'run';
            app.UI.ViewDD.Value = 'run';
            if any(strcmp(app.UI.RunDD.ItemsData, file)), app.UI.RunDD.Value = file; end
            app.draw('run', m);
            [v, lines] = lab_advice(m, app.Runs);
            head = sprintf('%s  (%s, %s)', m.file, strjoin(m.ids, ' '), char(datetime(m.time, 'Format', 'HH:mm')));
            if ~isempty(m.note), head = [head '  note: ' m.note]; end
            if isfield(m, 'demo') && m.demo, head = [head '  [DEMO DATA]']; end
            app.setVerdict(v, [{head}, lines]);
        end

        function refresh(app)
            % REFRESH  Re-read the day folder: lamps, times, the run list.
            [app.Runs, bad] = lab_runs(app.DataDir);
            for i = 1:numel(bad)
                if ~any(strcmp(app.BadLogged, bad{i})), app.log(['Skipped file ' bad{i}]); app.BadLogged{end+1} = bad{i}; end
            end
            app.Verdicts = containers.Map();
            for i = 1:numel(app.Runs)
                m = app.Runs{i};
                for r = m.R
                    key = r.id;
                    if any(strcmp(key, {'bal', 'sum'}))
                        if any(strcmp(m.ids, 'A1')), key = ['A:' key]; else, key = ['S:' key]; end
                    elseif any(strcmp(key, {'F1n', 'F2n'}))
                        key = ['F:' key];
                    end
                    app.Verdicts(key) = r.verdict;
                    if isKey(app.Times, key), t = app.Times(key); t.Text = char(datetime(m.time, 'Format', 'HH:mm')); end
                end
            end
            for k = app.Lamps.keys
                l = app.Lamps(k{1});
                if isKey(app.Verdicts, k{1}), l.Color = app.Pal.lamp.(app.Verdicts(k{1}));
                else, l.Color = app.Pal.lamp.none; t = app.Times(k{1}); t.Text = '';
                end
            end
            if isempty(app.Runs)
                app.UI.RunDD.Items = {'(no runs yet)'}; app.UI.RunDD.ItemsData = {''};
            else
                items = cell(1, numel(app.Runs)); data = items;
                for i = numel(app.Runs):-1:1
                    m = app.Runs{i}; v = lab_advice(m, {});
                    items{end-i+1} = sprintf('%s   %s   (%s)   %s', char(datetime(m.time, 'Format', 'HH:mm')), ...
                        m.file, strjoin(m.ids, ' '), v);
                    data{end-i+1} = m.file;
                end
                app.UI.RunDD.Items = items; app.UI.RunDD.ItemsData = data;
                if any(strcmp(data, app.ShownFile)), app.UI.RunDD.Value = app.ShownFile; end
            end
            app.UI.Count.Text = sprintf('%d runs saved', numel(app.Runs));
        end

        function s = switchboard(app)
            % SWITCHBOARD  What the big indicators show now, e.g. 'WOOFER ON, MID OFF, TWEETER OFF'
            %   ('' at the Zi station).
            if strcmp(app.UI.SwBig(1).Visible, 'off'), s = ''; return; end
            s = strjoin(arrayfun(@(h) strjoin(cellstr(h.Text), ' '), app.UI.SwBig, 'UniformOutput', false), ', ');
        end

        function v = verdict(app, key)
            % VERDICT  The lamp of a step or check: 'OK', 'CHECK', 'BAD' or '' (not measured).
            %   Checks: 'S:bal', 'S:sum', 'A:bal', 'A:sum', 'F:F1n', 'F:F2n'.
            if isKey(app.Verdicts, key), v = app.Verdicts(key); else, v = ''; end
        end

        function made = importManual(app, files)
            % IMPORTMANUAL  Show runs measured with Tuesday's scripts (lab-day/data/project_*.mat,
            %   zinf_*.mat) in this GUI. The originals are only read.
            made = {};
            if nargin < 2
                files = {};
                if ~app.Quiet
                    a = uiconfirm(app.Fig, sprintf(['Show runs measured with the Tuesday scripts ' ...
                        '(manual/project_run.m, zinf_run.m) in this GUI?\nThey are copied into the day folder; ' ...
                        'the originals stay untouched.']), 'Load manual runs', ...
                        'Options', {'All of today', 'Choose files...', 'Cancel'}, 'DefaultOption', 1, 'CancelOption', 3);
                    if strcmp(a, 'Cancel'), return; end
                    if strcmp(a, 'Choose files...')
                        L = labpaths();
                        [f, pth] = uigetfile(fullfile(L.data, '*.mat'), 'Manual runs (project_*.mat, zinf_*.mat)', 'MultiSelect', 'on');
                        figure(app.Fig);
                        if isequal(f, 0), return; end
                        files = fullfile(pth, cellstr(f));
                    end
                end
            end
            [made, msgs] = lab_import(app.DataDir, files);
            for i = 1:numel(msgs), app.log(['Import: ' msgs{i}]); end
            app.refresh();
            if ~isempty(made), [~, f] = fileparts(made{end}); app.showRun(f); end
        end

        function dest = copyDay(app, target)
            % COPYDAY  Copy the day folder (+ today's manual-script files) to TARGET, e.g. the USB stick.
            %   Never overwrites: a second copy gets _2.
            dest = '';
            if nargin < 2
                target = uigetdir('', 'Choose the USB stick (or a folder) to copy today''s data to');
                figure(app.Fig);
                if isequal(target, 0), return; end
            end
            if ~exist(app.DataDir, 'dir'), app.log('Nothing to copy yet.'); return; end
            [~, day] = fileparts(app.DataDir);
            name = sprintf('34870_G10_lab_%s', day); if app.Demo, name = [name '_DEMO']; end
            dest = fullfile(target, name); n = 2;
            while exist(dest, 'dir'), dest = fullfile(target, sprintf('%s_%d', name, n)); n = n + 1; end
            try
                mkdir(dest);
                copyfile(app.DataDir, dest);
                nman = 0;
                if ~app.Demo
                    L = labpaths();
                    d = [dir(fullfile(L.data, 'project_*.mat')); dir(fullfile(L.data, 'zinf_*.mat'))];
                    for i = 1:numel(d)
                        f = fullfile(d(i).folder, d(i).name);
                        w = load(f, 'time');
                        if strcmp(char(datetime(w.time, 'Format', 'yyyy-MM-dd')), day)
                            if ~nman, mkdir(fullfile(dest, 'manual_scripts')); end
                            copyfile(f, fullfile(dest, 'manual_scripts')); nman = nman + 1;
                        end
                    end
                end
                nf = numel(dir(fullfile(dest, '**', '*.*')));
                app.log(sprintf('Copied the day to %s (%d files incl. %d from the manual scripts).', dest, nf, nman));
                if ~app.Quiet, uialert(app.Fig, sprintf('Copied to\n%s', dest), 'Copy done', 'Icon', 'success'); end
            catch err
                app.log(['COPY FAILED: ' err.message]);
                if ~app.Quiet, uialert(app.Fig, err.message, 'Copy failed'); end
                dest = '';
            end
        end

        function exportFigures(app)
            % EXPORTFIGURES  Every dashboard tab + a picture of this window -> <day>/figures/.
            if isempty(app.Runs), app.log('Nothing measured yet: no figures to export.'); return; end
            fd = fullfile(app.DataDir, 'figures');
            if ~exist(fd, 'dir'), mkdir(fd); end
            had = ~isempty(findobj(0, 'Type', 'figure', 'Tag', 'labdash'));
            old = get(groot, 'DefaultFigureVisible');
            try
                if ~had, set(groot, 'DefaultFigureVisible', 'off'); end
                f = lab_dash(app.DataDir, 'save', true);
                if ~had, close(f); end
                set(groot, 'DefaultFigureVisible', old);
                was = app.Theme;                        % the window picture is light too
                if ~strcmp(was, 'light'), app.Theme = 'light'; app.Pal = gui_palette('light'); app.applyTheme(); end
                app.screenshot(fullfile(fd, sprintf('labgui_%s.png', char(datetime('now', 'Format', 'HHmmss')))));
                if ~strcmp(was, 'light'), app.Theme = was; app.Pal = gui_palette(was); app.applyTheme(); end
                app.log(sprintf('Figures saved in %s', app.rel(fd)));
            catch err
                set(groot, 'DefaultFigureVisible', old);
                app.log(['Export failed: ' err.message]);
            end
        end

        function openDashboard(app)
            % OPENDASHBOARD  The full dashboard (all tabs) in its own window.
            try
                lab_dash(app.DataDir, 'save', false);
            catch err
                app.log(['Dashboard failed: ' err.message]);
            end
        end

        function openFolder(app)
            d = app.DataDir; if ~exist(d, 'dir'), mkdir(d); end
            try
                if ispc, winopen(d); elseif ismac, system(['open "' d '" &']); else, system(['xdg-open "' d '" &']); end
            catch err
                app.log(['Cannot open the folder: ' err.message]);
            end
        end

        function screenshot(app, file)
            % SCREENSHOT  Save this window as a PNG.
            drawnow;
            try
                exportapp(app.Fig, file);              % R2020b+
            catch
                app.log('Screenshot skipped: needs MATLAB R2020b or newer.');
            end
        end
    end

    % ======================================================================= internals
    methods (Hidden)
        function onSetting(app, key, type, src)
            v = strtrim(src.Value);
            if strcmp(type, 'num')
                x = str2double(strrep(v, ',', '.'));
                if isnan(x) && ~(isempty(v) || strcmpi(v, 'nan'))
                    src.Value = fmt(app.S.(key));
                    app.log(sprintf('"%s" is not a number: %s unchanged.', v, key));
                    if ~app.Quiet, uialert(app.Fig, sprintf('"%s" is not a number.', v), 'Settings'); end
                    return
                end
                app.setSetting(key, x);
            else
                app.setSetting(key, v);
            end
        end

        function stop = demoWait(app, t)
            app.showPhase(t);
            drawnow;
            stop = app.CancelFlag;
        end

        function tick(app)
            if isvalid(app) && app.Busy && ~isempty(app.T0), app.showPhase(toc(app.T0)); end
        end
    end

    methods (Access = private)
        function build(app, pos)
            if isempty(pos)                    % on the biggest monitor (the primary may be a portrait one)
                mp = get(groot, 'MonitorPositions');
                [~, i] = max(mp(:,3)); mp = mp(i, :);
                w = min(1560, mp(3) - 40); h = min(950, mp(4) - 80);
                if w < 600 || h < 400, w = 1560; h = 950; end
                pos = [mp(1) + 20, mp(2) + 40, w, h];
            end
            w = pos(3);
            ttl = '34870 Group 10 - lab GUI (System D)';
            if app.Demo, ttl = [ttl '  [DEMO]']; end
            app.Fig = uifigure('Name', ttl, 'Position', pos, 'Visible', 'off', ...
                'CloseRequestFcn', @(~, ~) app.onClose());
            try                                   % narrower side panels when the window is small
                app.Fig.AutoResizeChildren = 'off';
                app.Fig.SizeChangedFcn = @(~, ~) app.fitColumns(app.Fig.Position(3));
            catch
            end
            g = uigridlayout(app.Fig, [2 3]); g.Tag = 'top';
            g.RowHeight = {38, '1x'};
            app.UI.Top = g; app.UI.InstrGrid = [];
            app.fitColumns(w);
            g.Padding = [8 8 8 8]; g.RowSpacing = 6; g.ColumnSpacing = 8;

            % ---- banner
            b = uilabel(g, 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontColor', 'w', 'Tag', 'banner');
            b.Layout.Row = 1; b.Layout.Column = [1 3];
            if app.Demo
                b.Text = sprintf('DEMO MODE: stand-in data, nothing is measured.   Data -> %s', app.rel(app.DataDir));
            else
                b.Text = sprintf('LIVE: real measurements.   Data -> %s', app.rel(app.DataDir));
            end
            app.UI.Banner = b;

            % ---- left: the steps
            lp = uipanel(g, 'Title', 'Steps  (blue = the whole run in one go)', 'FontWeight', 'bold', 'FontSize', 13);
            lp.Layout.Row = 2; lp.Layout.Column = 1;
            lg = uigridlayout(lp, [3 1]); lg.RowHeight = {'1x', 22, 40}; lg.Padding = [4 4 4 4]; lg.RowSpacing = 4;
            app.UI.Tabs = uitabgroup(lg);
            app.UI.TabCh = uitab(app.UI.Tabs, 'Title', 'Anechoic chamber');
            app.UI.TabZi = uitab(app.UI.Tabs, 'Title', 'Zi / near field');
            P = lab_plan(); T = @(id) P(strcmp({P.id}, id)).title;
            ch = {
                {'grp', 'P', 'Run P: P1 + P2 + P3 (placement, MiniDSP bypassed)'}, {'step', 'P1'}, {'step', 'P2'}, {'step', 'P3'}, ...
                {'step', 'P2d'}, {'step', 'P3d'}, ...
                {'grp', 'S', 'Run S: S1 + S2 + S3 (system, MiniDSP on)'}, {'step', 'S1'}, {'step', 'S2'}, {'step', 'S3'}, ...
                {'check', 'S:bal', 'check: woofer vs mid+tw level'}, {'check', 'S:sum', 'check: woofer + mid/tw = all'}, ...
                {'step', 'S4'}, {'step', 'S5'}, ...
                {'grp', 'F', 'Run F: F0 + F1 + F2 (polarity flips)'}, {'step', 'F0'}, {'step', 'F1'}, {'step', 'F2'}, ...
                {'check', 'F:F1n', 'check: woofer-flip notch'}, {'check', 'F:F2n', 'check: tweeter-flip notch'}, ...
                {'grp', 'A', 'Run A: A1 + A2 + A3 (30 deg)'}, {'step', 'A1'}, {'step', 'A2'}, {'step', 'A3'}, ...
                {'check', 'A:bal', 'check: woofer vs mid+tw level'}, {'check', 'A:sum', 'check: woofer + mid/tw = all'}};
            zi = {{'head', 'Impedance (series R in the circuit)'}, {'step', 'Z1'}, {'step', 'Z2'}, {'step', 'Z3'}, {'step', 'Z4'}, ...
                {'head', ''}, {'head', 'Near field (series R SHORTED)'}, {'step', 'N1'}, {'step', 'N2'}};
            app.rows(app.UI.TabCh, ch, T);
            app.rows(app.UI.TabZi, zi, T);
            app.UI.Count = uilabel(lg, 'Text', '', 'Tag', 'muted');
            ol = uilabel(lg, 'Text', 'Order: P > S > S4 > S5 > F > A > Z1-Z4 > N1, N2.  Lamp: grey = not yet, green OK, orange CHECK, red BAD.', ...
                'FontSize', 11, 'Tag', 'muted');
            try, ol.WordWrap = 'on'; catch, end

            % ---- centre: instructions, graphs, verdict
            cg = uigridlayout(g, [3 1]); cg.Layout.Row = 2; cg.Layout.Column = 2;
            cg.RowHeight = {335, '1x', 165}; cg.Padding = [0 0 0 0]; cg.RowSpacing = 6;
            ip = uipanel(cg, 'Title', 'What to do', 'FontWeight', 'bold', 'FontSize', 14);
            ig = uigridlayout(ip, [4 2]); ig.ColumnWidth = {'1x', 215}; ig.RowHeight = {'1x', 74, 46, 26};
            ig.Padding = [6 6 6 6]; ig.RowSpacing = 5; app.UI.InstrGrid = ig;
            app.fitColumns(w);
            app.UI.Instr = uitextarea(ig, 'Editable', 'off', 'FontSize', 15);
            app.UI.Instr.Layout.Row = 1; app.UI.Instr.Layout.Column = 1;
            % ---- the switchboard, drawn: the state to set NOW (big) and after beeps 1 / 2 (small)
            sb = uigridlayout(ig, [1 7]); sb.Layout.Row = 2; sb.Layout.Column = [1 2];
            sb.ColumnWidth = {'1.1x', '1x', '1x', '1x', 4, '1.25x', '1.25x'}; sb.Padding = [0 0 0 0]; sb.ColumnSpacing = 6;
            app.UI.SwHead = uilabel(sb, 'Text', {'Switchboard', 'NOW:'}, 'FontSize', 15, 'FontWeight', 'bold', 'Tag', 'sw');
            nm = {'WOOFER', 'MID', 'TWEETER'};
            for i = 1:3
                app.UI.SwBig(i) = uilabel(sb, 'Text', {nm{i}, 'OFF'}, 'FontSize', 16, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', 'Tag', 'sw');
            end
            uilabel(sb, 'Text', '', 'Tag', 'sw');
            for j = 1:2
                g2 = uigridlayout(sb, [2 3]); g2.RowHeight = {'1x', '1x'}; g2.Padding = [0 4 0 4];
                g2.RowSpacing = 3; g2.ColumnSpacing = 3;
                app.UI.SwSmallHead(j) = uilabel(g2, 'Text', sprintf('after beeps %d:', j), 'FontSize', 12, 'Tag', 'sw');
                app.UI.SwSmallHead(j).Layout.Column = [1 3];
                for i = 1:3
                    app.UI.SwSmall(j, i) = uilabel(g2, 'Text', nm{i}(1), 'FontSize', 12, 'FontWeight', 'bold', ...
                        'HorizontalAlignment', 'center', 'Tag', 'sw');
                end
                app.UI.SwSmallGrid(j) = g2;
            end
            app.UI.SwGrid = sb;
            app.fitColumns(w);
            mg = uigridlayout(ig, [3 1]); mg.Layout.Row = 1; mg.Layout.Column = 2;
            mg.RowHeight = {'1x', 32, 32}; mg.Padding = [0 0 0 0]; mg.RowSpacing = 5;
            app.UI.Measure = uibutton(mg, 'Text', 'Measure', 'FontSize', 22, 'FontWeight', 'bold', ...
                'FontColor', 'w', 'Tag', 'measure', 'ButtonPushedFcn', @(~, ~) app.measure());
            app.UI.Cancel = uibutton(mg, 'Text', 'Cancel (demo only)', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) app.cancel());
            if ~app.Demo
                app.UI.Cancel.Text = 'Stop: Ctrl+C in Command Window';
                app.UI.Cancel.Tooltip = 'The course routine cannot be stopped from the GUI. Ctrl+C in the MATLAB Command Window stops it; nothing is saved.';
            end
            app.UI.Next = uibutton(mg, 'Text', 'Go to the next step >', 'ButtonPushedFcn', @(~, ~) app.nextStep());
            app.UI.Status = uilabel(ig, 'Text', '', 'FontSize', 15, 'FontWeight', 'bold', 'Tag', 'status');
            try, app.UI.Status.WordWrap = 'on'; catch, end
            app.UI.Status.Layout.Row = 3; app.UI.Status.Layout.Column = [1 2];
            ng = uigridlayout(ig, [1 2]); ng.Layout.Row = 4; ng.Layout.Column = [1 2];
            ng.ColumnWidth = {250, '1x'}; ng.Padding = [0 0 0 0];
            uilabel(ng, 'Text', 'Note for this measurement (saved with it):');
            app.UI.Note = uieditfield(ng, 'text');

            pp = uipanel(cg, 'Title', 'Graphs', 'FontWeight', 'bold', 'FontSize', 13, 'Tag', 'plot');
            app.UI.PlotPanel = pp;
            pg = uigridlayout(pp, [3 1]); pg.RowHeight = {28, '2x', '1x'}; pg.Padding = [6 4 6 4];
            pg.RowSpacing = 2; pg.Tag = 'plot';
            app.UI.PlotGrid = pg;
            tb = uigridlayout(pg, [1 4]); tb.ColumnWidth = {42, 300, 36, '1x'}; tb.Padding = [0 0 0 0];
            tb.Tag = 'plot';
            uilabel(tb, 'Text', 'Show:');
            app.UI.ViewDD = uidropdown(tb, 'Items', {'Selected run vs expected', 'Every "all" run today (drift)', ...
                'Phase woofer vs mid/tw (latest S)', 'Board impedance Z1-Z3', 'Woofer impedance Z4', 'Near field N1 + N2'}, ...
                'ItemsData', {'run', 'all', 'phase', 'zboard', 'zwoofer', 'nf'}, 'Value', 'run', ...
                'ValueChangedFcn', @(src, ~) app.setView(src.Value));
            uilabel(tb, 'Text', 'Run:');
            app.UI.RunDD = uidropdown(tb, 'Items', {'(no runs yet)'}, 'ItemsData', {''}, ...
                'ValueChangedFcn', @(src, ~) app.onRunPicked(src.Value));
            app.UI.Ax1 = uiaxes(pg); app.UI.Ax2 = uiaxes(pg);
            for a = [app.UI.Ax1 app.UI.Ax2]
                try, a.Toolbar.Visible = 'off'; catch, end
            end

            vp = uipanel(cg, 'Title', 'Verdict and what to do next', 'FontWeight', 'bold', 'FontSize', 13);
            vg = uigridlayout(vp, [1 2]); vg.ColumnWidth = {150, '1x'}; vg.Padding = [6 6 6 6];
            app.UI.Verdict = uilabel(vg, 'Text', '-', 'FontSize', 30, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'FontColor', 'w', 'Tag', 'verdict');
            app.UI.Advice = uitextarea(vg, 'Editable', 'off', 'FontSize', 13);

            % ---- right: settings, data buttons, log
            rg = uigridlayout(g, [3 1]); rg.Layout.Row = 2; rg.Layout.Column = 3;
            rg.RowHeight = {450, 140, '1x'}; rg.Padding = [0 0 0 0]; rg.RowSpacing = 6;
            sp = uipanel(rg, 'Title', 'Settings (stored with every measurement)', 'FontWeight', 'bold', 'FontSize', 13);
            nf = size(app.FIELDS, 1);
            sg = uigridlayout(sp, [nf + 4, 2]); sg.ColumnWidth = {118, '1x'};
            sg.RowHeight = repmat({25}, 1, nf + 4); sg.RowSpacing = 4; sg.Padding = [6 6 6 6];
            uilabel(sg, 'Text', 'Colours', 'FontWeight', 'bold');
            app.UI.ThemeDD = uidropdown(sg, 'Items', {'Light', 'Dark'}, 'ItemsData', {'light', 'dark'}, ...
                'Value', app.Theme, 'ValueChangedFcn', @(src, ~) app.setTheme(src.Value));
            uilabel(sg, 'Text', 'Station', 'FontWeight', 'bold');
            app.UI.Station = uilabel(sg, 'Text', '');
            uilabel(sg, 'Text', 'Day folder', 'FontWeight', 'bold');
            app.UI.Folder = uilabel(sg, 'Text', app.rel(app.DataDir), 'Tooltip', app.DataDir, 'FontSize', 11);
            app.UI.Fields = struct();
            for i = 1:nf
                [key, lbl, type] = app.FIELDS{i, :};
                uilabel(sg, 'Text', lbl);
                app.UI.Fields.(key) = uieditfield(sg, 'text', 'Value', fmt(app.S.(key)), ...
                    'ValueChangedFcn', @(src, ~) app.onSetting(key, type, src));
            end
            app.UI.Fields.R_series.Tooltip = 'Zi station: the MULTIMETER value of the series resistor (about 32.9), not R_E.';
            app.UI.Fields.out1_gain.Tooltip = 'Type the value set in the MiniDSP app. Design -4.5 dB; -5.8 dB balanced the lab amplifier on 10-Nov.';
            if app.Demo
                uilabel(sg, 'Text', 'Demo fault', 'FontWeight', 'bold', 'Tag', 'accent');
                app.UI.Fault = uidropdown(sg, 'Items', {'none', 'placement off', 'state not switched in time', ...
                    'no UMIK', 'beeps.wav missing', 'clipping', 'no NI card'}, 'ItemsData', app.FAULTS, ...
                    'Value', 'none', 'ValueChangedFcn', @(src, ~) app.setFault(src.Value), ...
                    'Tooltip', 'Rehearse what a wrong setup or a missing device looks like.');
            else
                uilabel(sg, 'Text', 'Mode', 'FontWeight', 'bold');
                uilabel(sg, 'Text', 'LIVE (course routines)');
            end

            bp = uipanel(rg, 'Title', 'Data', 'FontWeight', 'bold', 'FontSize', 13);
            bg = uigridlayout(bp, [3 2]); bg.RowHeight = {28, 28, 28}; bg.Padding = [6 6 6 6]; bg.RowSpacing = 5;
            uibutton(bg, 'Text', 'Open dashboard', 'ButtonPushedFcn', @(~, ~) app.openDashboard());
            uibutton(bg, 'Text', 'Export figures', 'ButtonPushedFcn', @(~, ~) app.exportFigures());
            uibutton(bg, 'Text', 'Copy day to USB...', 'ButtonPushedFcn', @(~, ~) app.copyDay(), 'FontWeight', 'bold');
            uibutton(bg, 'Text', 'Load manual runs...', 'ButtonPushedFcn', @(~, ~) app.importManual(), ...
                'Tooltip', 'Show runs made with the Tuesday scripts (manual/project_run.m, zinf_run.m)');
            uibutton(bg, 'Text', 'Open data folder', 'ButtonPushedFcn', @(~, ~) app.openFolder());
            uibutton(bg, 'Text', 'Refresh', 'ButtonPushedFcn', @(~, ~) app.refresh());

            lgp = uipanel(rg, 'Title', 'Log (newest on top; also in <day>/labgui_log.txt)', 'FontWeight', 'bold', 'FontSize', 13);
            lgg = uigridlayout(lgp, [1 1]); lgg.Padding = [4 4 4 4];
            app.UI.Log = uitextarea(lgg, 'Editable', 'off', 'FontSize', 11, 'Value', {''});
        end

        function rows(app, tab, spec, T)
            gl = uigridlayout(tab, [numel(spec) 3]);
            gl.RowHeight = repmat({27}, 1, numel(spec)); gl.ColumnWidth = {22, '1x', 40};
            gl.RowSpacing = 3; gl.Padding = [4 6 4 6];
            try, gl.Scrollable = 'on'; catch, end
            for i = 1:numel(spec)
                r = spec{i};
                switch r{1}
                case 'grp'
                    b = uibutton(gl, 'Text', r{3}, 'FontWeight', 'bold', 'Tag', 'grp', ...
                        'HorizontalAlignment', 'left', 'ButtonPushedFcn', @(~, ~) app.select(r{2}));
                    b.Layout.Row = i; b.Layout.Column = [1 3];
                    app.Buttons(r{2}) = b;
                case 'step'
                    l = uilamp(gl, 'Color', [0.78 0.78 0.78]); l.Layout.Row = i; l.Layout.Column = 1;
                    b = uibutton(gl, 'Text', sprintf('%s   %s', r{2}, T(r{2})), 'HorizontalAlignment', 'left', ...
                        'Tag', 'step', 'ButtonPushedFcn', @(~, ~) app.select(r{2}));
                    b.Layout.Row = i; b.Layout.Column = 2;
                    t = uilabel(gl, 'Text', '', 'Tag', 'muted', 'FontSize', 11);
                    t.Layout.Row = i; t.Layout.Column = 3;
                    app.Lamps(r{2}) = l; app.Buttons(r{2}) = b; app.Times(r{2}) = t;
                case 'check'
                    l = uilamp(gl, 'Color', [0.78 0.78 0.78]); l.Layout.Row = i; l.Layout.Column = 1;
                    x = uilabel(gl, 'Text', ['      ' r{3}], 'FontAngle', 'italic', 'Tag', 'muted');
                    x.Layout.Row = i; x.Layout.Column = 2;
                    t = uilabel(gl, 'Text', '', 'Tag', 'muted', 'FontSize', 11);
                    t.Layout.Row = i; t.Layout.Column = 3;
                    app.Lamps(r{2}) = l; app.Times(r{2}) = t;
                case 'head'
                    x = uilabel(gl, 'Text', r{2}, 'FontWeight', 'bold');
                    x.Layout.Row = i; x.Layout.Column = [1 3];
                end
            end
        end

        function draw(app, kind, arg)
            % one graph, or two (measured vs expected + the difference) for a chamber run.
            % The layout is set BEFORE drawing: an axes drawn while its row has zero height
            % keeps a squashed layout when the row comes back.
            a1 = app.UI.Ax1; a2 = app.UI.Ax2;
            two = strcmp(kind, 'run') && isstruct(arg) && strcmp(arg.station, 'chamber');
            if two
                app.UI.PlotGrid.RowHeight = {28, '2x', '1x'}; a2.Visible = 'on';
            else
                cla(a2, 'reset'); legend(a2, 'off'); a2.Visible = 'off';
                app.UI.PlotGrid.RowHeight = {28, '1x', 0};
            end
            drawnow;
            if strcmp(kind, 'nothing')
                cla(a1, 'reset'); legend(a1, 'off'); app.NothingText = arg;
                text(a1, 0.5, 0.5, arg, ...
                    'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', app.Pal.muted);
                a1.XTick = []; a1.YTick = []; xlim(a1, [0 1]); ylim(a1, [0 1]); box(a1, 'on');
                set(a1, 'Color', app.Pal.axbg, 'XColor', app.Pal.axfg, 'YColor', app.Pal.axfg);
            else
                if two, b = a2; else, b = []; end
                try
                    lab_plot(kind, a1, b, arg, app.Pal);
                catch err
                    app.log(['Plot failed: ' err.message]);
                end
            end
            a2.Color = app.Pal.axbg;
        end

        function setVerdict(app, v, lines)
            app.LastVerdict = v; app.LastAdvice = lines;
            app.UI.Verdict.Text = v;
            if isfield(app.Pal.vbg, v), c = app.Pal.vbg.(v); else, c = app.Pal.vbg.none; end
            app.UI.Verdict.BackgroundColor = c;
            app.UI.Verdict.FontColor = [1 1 1];
            app.UI.Advice.Value = lines;
        end

        function fail(app, err, label)
            if strcmp(err.identifier, 'labgui:cancel')
                app.log(sprintf('%s cancelled: nothing saved.', label));
                app.setVerdict('-', {sprintf('%s cancelled: nothing saved.', label)});
                app.LastError = 'cancelled';
                return
            end
            fix = lab_errfix(err);
            app.LastError = err.message;
            app.log(sprintf('ERROR in %s: %s', label, err.message));
            app.log(['FIX: ' fix]);
            app.setVerdict('ERROR', {sprintf('Measurement %s failed: nothing was saved.', label), '', ...
                err.message, '', ['DO: ' fix]});
            app.status(['Failed: ' fix], 'fail');
            if ~app.Quiet
                uialert(app.Fig, sprintf('%s\n\nWhat to do: %s', err.message, fix), 'Measurement failed', 'Icon', 'error');
            end
        end

        function setBusy(app, on, I)
            if ~isvalid(app) || isempty(app.Fig) || ~isvalid(app.Fig), return; end
            app.Busy = on;
            en = 'on'; if on, en = 'off'; end
            app.UI.Measure.Enable = en; app.UI.Next.Enable = en;
            for k = app.Buttons.keys, b = app.Buttons(k{1}); b.Enable = en; end
            if on
                app.CancelFlag = false; app.Inst = I; app.T0 = tic;
                app.UI.Measure.Text = 'Measuring...';
                if app.Demo, app.UI.Cancel.Enable = 'on'; end
                done = datetime('now') + seconds(I.secs);
                if app.Demo && app.Speed > 0, done = datetime('now') + seconds(I.secs*app.Speed); end
                app.status(sprintf('Measuring: about %s, done about %s.  %s', dur(I.secs), ...
                    char(done, 'HH:mm:ss'), I.phases(1).text), 'busy');
                if ~app.Demo
                    app.Timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.5, 'BusyMode', 'drop', ...
                        'TimerFcn', @(~, ~) app.tick());
                    start(app.Timer);
                end
            else
                app.stopTimer();
                app.UI.Cancel.Enable = 'off';
                app.T0 = [];
                if ~isempty(app.Sel)
                    [~, ~, label] = lab_steps(app.Sel); app.UI.Measure.Text = sprintf('Measure %s', label);
                    app.showSwitches(struct('big', 1, 'beeps', 0));
                end
            end
            drawnow;
        end

        function showPhase(app, t)
            I = app.Inst;
            if isempty(I), return; end
            k = find([I.phases.t0] <= t & t < [I.phases.t1], 1);
            clock = sprintf('[%s of about %s]', mmss(t), mmss(I.secs));
            if isempty(k)
                app.status(sprintf('Finishing and saving ... %s', clock), 'busy');
            elseif strcmp(I.phases(k).name, 'beeps')
                app.status(sprintf('%s   %s', I.phases(k).text, clock), 'beeps');
                app.showSwitches(struct('big', I.phases(k).k + 1, 'beeps', I.phases(k).k));
            else
                app.status(sprintf('%s   %s', I.phases(k).text, clock), 'busy');
                app.showSwitches(struct('big', I.phases(k).k, 'beeps', 0));
            end
        end

        function status(app, txt, kind)
            app.StatusText = txt; app.StatusKind = kind;
            app.UI.Status.Text = ['  ' txt];
            app.UI.Status.BackgroundColor = app.Pal.status.(kind);
            app.UI.Status.FontColor = app.Pal.fg;
        end

        function onRunPicked(app, file)
            if ~isempty(file), app.showRun(file); end
        end

        function saveRunFigure(app, file)
            % the graph of a run as a report figure: always light, drawn in a hidden figure
            fd = fullfile(app.DataDir, 'figures');
            i = find(cellfun(@(m) strcmp(m.file, file), app.Runs), 1);
            if isempty(i), return; end
            f = [];
            try
                if ~exist(fd, 'dir'), mkdir(fd); end
                f = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1100 720]);
                try, f.Theme = 'light'; catch, end
                a1 = subplot(3, 1, [1 2], 'Parent', f); a2 = subplot(3, 1, 3, 'Parent', f);
                if ~lab_plot('run', a1, a2, app.Runs{i}), delete(a2); a1.Position = [0.09 0.1 0.87 0.8]; end
                save_png(f, fullfile(fd, [file '.png']), 110);
            catch err
                app.log(['Could not save the graph: ' err.message]);
            end
            if ~isempty(f) && isvalid(f), close(f); end
        end

        function fitColumns(app, w)
            % side columns and the Measure column shrink on small windows (lab PCs, tiling WMs)
            if ~isfield(app.UI, 'Top') || isempty(app.UI.Top) || ~isvalid(app.UI.Top), return; end
            if w >= 1450, app.UI.Top.ColumnWidth = {345, '1x', 330}; mw = 215;
            elseif w >= 1200, app.UI.Top.ColumnWidth = {300, '1x', 280}; mw = 190;
            else, app.UI.Top.ColumnWidth = {265, '1x', 245}; mw = 160;
            end
            if ~isempty(app.UI.InstrGrid) && isvalid(app.UI.InstrGrid), app.UI.InstrGrid.ColumnWidth = {'1x', mw}; end
            if isfield(app.UI, 'SwBig')
                fs = 16; if w < 1200, fs = 12; elseif w < 1450, fs = 14; end
                set(app.UI.SwBig, 'FontSize', fs); app.UI.SwHead.FontSize = min(fs, 15);
            end
        end

        function showSwitches(app, w)
            % the switchboard indicators: w.big = which state is drawn big (1 = the one to set
            % NOW); w.beeps = k while beeps k are playing (then big = the state to switch TO)
            app.SwState = w;
            P = app.Pal; I = app.SelInst; nm = {'WOOFER', 'MID', 'TWEETER'};
            if app.Busy && ~isempty(app.Inst), I = app.Inst; end
            chamber = ~isempty(I) && ~isempty(I.sw);
            set([app.UI.SwBig, app.UI.SwHead], 'Visible', 'on');
            if ~chamber
                app.UI.SwHead.Text = {'Zi / near field:', 'see the text'};
                app.UI.SwHead.FontColor = P.muted;
                set(app.UI.SwBig, 'Visible', 'off'); set(app.UI.SwSmallGrid, 'Visible', 'off');
                return
            end
            b = min(max(w.big, 1), size(I.sw, 1));
            if w.beeps > 0
                app.UI.SwHead.Text = {sprintf('BEEPS %d:', w.beeps), 'SWITCH TO'}; app.UI.SwHead.FontColor = P.accent;
            elseif app.Busy
                app.UI.SwHead.Text = {'Switchboard', sprintf('state %d:', b)}; app.UI.SwHead.FontColor = P.fg;
            else
                app.UI.SwHead.Text = {'Switchboard', 'NOW:'}; app.UI.SwHead.FontColor = P.fg;
            end
            for i = 1:3
                on = I.sw(b, i) > 0;
                if on
                    set(app.UI.SwBig(i), 'Text', {nm{i}, 'ON'}, 'BackgroundColor', P.swon, 'FontColor', P.swonfg);
                else
                    set(app.UI.SwBig(i), 'Text', {nm{i}, 'OFF'}, 'BackgroundColor', P.swoff, 'FontColor', P.swofffg);
                end
            end
            for j = 1:2
                has = size(I.sw, 1) >= j + 1;
                if has, app.UI.SwSmallGrid(j).Visible = 'on'; else, app.UI.SwSmallGrid(j).Visible = 'off'; end
                app.UI.SwSmallHead(j).FontColor = P.muted;
                if ~has, continue; end
                for i = 1:3
                    if I.sw(j + 1, i) > 0
                        set(app.UI.SwSmall(j, i), 'BackgroundColor', P.swon, 'FontColor', P.swonfg);
                    else
                        set(app.UI.SwSmall(j, i), 'BackgroundColor', P.swoff, 'FontColor', P.swofffg);
                    end
                end
            end
        end

        function colourButtons(app)
            for k = app.Buttons.keys
                b = app.Buttons(k{1});
                if strcmp(k{1}, app.Sel)
                    b.BackgroundColor = app.Pal.sel; b.FontColor = app.Pal.selfg;
                elseif numel(k{1}) == 1
                    b.BackgroundColor = app.Pal.grpbtn; b.FontColor = app.Pal.fg;
                else
                    b.BackgroundColor = app.Pal.btn; b.FontColor = app.Pal.fg;
                end
            end
        end

        function applyTheme(app)
            % every component's colours from the palette (explicitly: no Theme property needed)
            P = app.Pal;
            try, app.Fig.Theme = app.Theme; catch, end         % R2025a+: popups, scroll bars
            app.Fig.Color = P.bg;
            for h = findall(app.Fig)'
                if h == app.Fig, continue; end
                tag = ''; try, tag = h.Tag; catch, end
                try   % older MATLAB lacks some colour properties (e.g. GridLayout.BackgroundColor): skip them
                switch h.Type
                case 'uigridlayout'
                    if strcmp(tag, 'top'), h.BackgroundColor = P.bg;
                    elseif strcmp(tag, 'plot'), h.BackgroundColor = P.axbg;
                    else, h.BackgroundColor = P.panel;
                    end
                case 'uipanel'
                    h.ForegroundColor = P.fg;
                    if strcmp(tag, 'plot'), h.BackgroundColor = P.axbg; else, h.BackgroundColor = P.panel; end
                case 'uitab'
                    h.BackgroundColor = P.panel; h.ForegroundColor = P.fg;
                case 'uilabel'
                    switch tag
                        case 'banner'
                            h.FontColor = [1 1 1];
                            if app.Demo, h.BackgroundColor = P.banner.demo; else, h.BackgroundColor = P.banner.live; end
                        case {'verdict', 'status', 'sw'}      % set by setVerdict / status / showSwitches
                        case 'muted',  h.FontColor = P.muted;
                        case 'accent', h.FontColor = P.accent;
                        otherwise,     h.FontColor = P.fg;
                    end
                case {'uieditfield', 'uitextarea', 'uidropdown'}
                    h.BackgroundColor = P.field; h.FontColor = P.fg;
                case 'uibutton'
                    if strcmp(tag, 'measure'), h.BackgroundColor = P.measure; h.FontColor = [1 1 1];
                    else, h.BackgroundColor = P.btn; h.FontColor = P.fg;
                    end
                case 'axes'
                    set(h, 'Color', P.axbg, 'XColor', P.axfg, 'YColor', P.axfg);
                end
                catch
                end
            end
            app.colourButtons();
            app.showSwitches(app.SwState);
            app.status(app.StatusText, app.StatusKind);
            app.refresh();
            v = app.LastVerdict; a = app.LastAdvice;
            if strcmp(app.View, 'run') && ~isempty(app.ShownFile)
                app.showRun(app.ShownFile);
            elseif ~strcmp(app.View, 'run')
                app.setView(app.View);
            else
                app.draw('nothing', app.NothingText);
            end
            if ~isempty(v), app.setVerdict(v, a); end
        end

        function preflight(app)
            % what the course routines need, checked before the first measurement
            L = labpaths();
            if isempty(which('meas_mag_spec2_SoundCard_LabE')), addpath(L.labEcourse); end
            if isempty(which('meas_mag_spec2_LabD')), addpath(L.labDcourse); end
            r = which('meas_mag_spec2_SoundCard_LabE');
            if isempty(r)
                app.log('Chamber routine meas_mag_spec2_SoundCard_LabE NOT FOUND: copy the whole labs folder (Lab E/matlab/course).');
            else
                d = dir(fileparts(r)); here = dir(pwd);
                if any(strcmpi({d.name}, 'beeps.wav')) || any(strcmpi({here.name}, 'beeps.wav'))
                    app.log('Chamber routine and Beeps.wav found.');
                else
                    app.log('Beeps.wav NOT found next to the chamber routine: copy it from Lab E/matlab/course.');
                end
            end
            if isempty(which('meas_mag_spec2_LabD')), app.log('Zi routine meas_mag_spec2_LabD NOT FOUND.'); end
            try
                info = audiodevinfo;
                ins = {}; outs = {};
                if ~isempty(info.input), ins = {info.input.Name}; end
                if ~isempty(info.output), outs = {info.output.Name}; end
                yn = {'MISSING', 'found'};
                u = any(contains(ins, 'Umik')); li = any(contains(ins, 'Line')); sp = any(contains(outs, 'Speakers'));
                app.log(sprintf('Audio devices: UMIK %s, Line In %s, Speakers %s.', yn{u + 1}, yn{li + 1}, yn{sp + 1}));
                if ~u, app.log('At the chamber: plug in the UMIK, then RESTART MATLAB (it lists audio devices only at start-up).'); end
            catch
                app.log('Audio devices could not be listed (fine at the Zi station).');
            end
        end

        function stopTimer(app)
            if ~isempty(app.Timer)
                try, stop(app.Timer); delete(app.Timer); catch, end
                app.Timer = [];
            end
        end

        function onClose(app)
            if app.Busy && ~app.Demo
                app.log('Wait for the measurement to finish before closing (or Ctrl+C in the Command Window).');
                return
            end
            delete(app);
        end

        function log(app, txt)
            line = sprintf('%s  %s', char(datetime('now', 'Format', 'HH:mm:ss')), txt);
            v = app.UI.Log.Value;                         % newest line on top
            if numel(v) == 1 && isempty(v{1}), v = {}; end
            v = [{line}; v(:)];
            app.UI.Log.Value = v(1:min(end, 400));
            if exist(app.DataDir, 'dir')
                fid = fopen(fullfile(app.DataDir, 'labgui_log.txt'), 'a');
                if fid > 0, fprintf(fid, '%s %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd')), line); fclose(fid); end
            end
        end

        function r = rel(~, f)
            L = labpaths();
            r = strrep(f, [L.root filesep], 'lab-day/');
            r = strrep(r, filesep, '/');
        end
    end
end

% ===================================================================== helpers
function s = fmt(v)
if ischar(v) || isstring(v), s = char(v);
elseif isnumeric(v) && isscalar(v) && isnan(v), s = '';
else, s = num2str(v);
end
end

function s = fmtlog(v)
s = fmt(v); if isempty(s), s = '(empty)'; end
end

function s = dur(t)
t = round(t);
if t < 60, s = sprintf('%d s', t); else, s = sprintf('%d min %02d s', floor(t/60), mod(t, 60)); end
end

function s = mmss(t)
t = round(t); s = sprintf('%d:%02d', floor(t/60), mod(t, 60));
end

function c = canon(d)
% absolute path without '..' (for comparing folders)
try
    c = char(java.io.File(char(d)).getCanonicalPath());
catch
    c = char(d);
end
end
