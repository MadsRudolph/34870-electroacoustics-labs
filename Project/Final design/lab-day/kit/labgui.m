function app = labgui(varargin)
% LABGUI  The lab day in one window: pick a step, read what to set up, press Measure,
%         see the graph and the verdict, read what to do next.
%
%   labgui            real measurements (lab PC). Data: ../data/<date>/
%   labgui demo       rehearse at home: no hardware, stand-in routines "measure" the
%                     expected curves. Data: ../demo_data/<date>/ (never mixed with real data)
%
%   Left:    every step with a lamp (grey not done, green OK, orange CHECK, red BAD) and the
%            time it was measured. Click a step, or a run (P, S, F, A) to measure its three
%            steps in one go; Ctrl+click picks up to three chamber steps of your own.
%   Middle:  what to set up NOW and what to switch during the beeps, with the switchboard
%            (Woofer / Mid / Tweeter ON or OFF) drawn for each state; the Measure button;
%            the verdict and what to do next; the plots (this run, every "all" run of the
%            day, impedance, near field). Earlier runs: the "Show run" list.
%   Right:   the settings of the day (stored in every measurement, kept after a restart),
%            buttons (dashboard, export figures, copy data to USB, load runs made with the
%            Run Section scripts), and the log (saved files, warnings and their fixes).
%
%   Nothing is ever overwritten: a repeated run is saved as <name>_2, _3 ...
%   The same without a window:  lab P, lab S ...  or the Run Section file lab_run.m.
%
%   Options (Name, Value): 'datadir' (other data folder), 'visible' (false = build it hidden),
%   'speed' (demo: times faster than real, default 15), 'theme' ('light' | 'dark').
%   app = labgui(...) returns handles and functions to drive it from code (tests/test_labgui.m).

demo = false;
if nargin && (ischar(varargin{1}) || isstring(varargin{1})) && strcmpi(varargin{1}, 'demo')
    demo = true; varargin(1) = [];
end
ip = inputParser;
ip.addParameter('datadir', '');
ip.addParameter('visible', true);
ip.addParameter('speed', 15);
ip.addParameter('theme', '');
ip.parse(varargin{:});
opt = ip.Results;

addpath(fullfile(fileparts(mfilename('fullpath')), 'core'));    % everything that is only called
L = labpaths;
P = lab_plan();
S0 = lab_setup();
datadir = opt.datadir;
if isempty(datadir)
    if demo, datadir = fullfile(L.demodata, S0.date); else, datadir = fullfile(L.data, S0.date); end
end
[~, day] = fileparts(datadir);
[S, G] = lab_settings(datadir);
if ~isempty(opt.theme), G.theme = lower(char(opt.theme)); end
C = lab_palette(G.theme);
D = struct('speed', opt.speed, 'fault', 'none');     % demo only

runs = {}; status = struct(); manual = {};
sel = {}; selErr = 'Pick a step or a run on the left.'; swstate = cell(1, 3);
measuring = false; tmr = []; t0 = []; TL = []; viewIdx = 0;
loglines = {}; h = struct(); lastAdvice = struct('verdict', '', 'lines', {{}});
titles = struct('P', 'Placement check (bypassed)', 'S', 'System (MiniDSP on)', ...
    'F', 'Polarity flips', 'A', '30 degrees', 'Z', 'Impedance (Zi/Nfield station)', 'N', 'Near field (Zi/Nfield station)');

old = findall(groot, 'Type', 'figure', 'Tag', 'labgui');
if ~isempty(old), try, delete(old); catch, end, end

build();
applyTheme();
reload(0);
refreshInstr();
logmsg(sprintf('labgui started%s. Data folder: %s', tern(demo, ' in DEMO mode (no hardware)', ''), datadir));
if demo, logmsg(sprintf('Demo: the stand-in "measures" the expected curves, %gx faster than real.', D.speed)); end
if ~demo, preflight(); end
if ~demo && ~strcmp(day, S0.date)
    logmsg(sprintf('NOTE: this folder is not today''s (%s). It is shown as it is; a new measurement would be saved into it.', S0.date));
end
if opt.visible, h.fig.Visible = 'on'; end
drawnow;

app = struct('fig', h.fig, 'h', h, 'select', @select, 'measure', @doMeasure, 'state', @state, ...
    'set', @setSetting, 'view', @viewRun, 'loadManual', @loadManual, 'exportFigures', @exportFigures, ...
    'copyData', @copyData, 'dashboard', @dashboard, 'fault', @setFault, 'theme', @setTheme, ...
    'screenshot', @screenshot, 'close', @onClose);
if nargout == 0, clear app; end

% =========================================================================
%  Build the window
% =========================================================================
    function build()
        scr = get(groot, 'ScreenSize');
        w = min(1560, scr(3) - 40); ht = min(940, scr(4) - 90);
        ttl = 'Lab day, Group 10, System D';
        if demo, ttl = [ttl '   [DEMO: no hardware]']; end
        h.fig = uifigure('Name', ttl, 'Position', [20 50 w ht], 'Tag', 'labgui', 'Visible', 'off', ...
            'CloseRequestFcn', cb(@onClose));
        h.main = uigridlayout(h.fig, [2 3], 'RowHeight', {40, '1x'}, 'ColumnWidth', {370, '1x', 340}, ...
            'Padding', [8 8 8 8], 'RowSpacing', 8, 'ColumnSpacing', 8, 'Tag', 'bg');

        try                                    % a small window scrolls instead of squashing the plots
            h.fig.AutoResizeChildren = 'off';
            h.fig.SizeChangedFcn = cb(@(~, ~) onResize());
        catch
        end

        % ---- header
        g = uigridlayout(h.main, [1 5], 'ColumnWidth', {'1x', 'fit', 'fit', 50, 110}, 'Padding', [4 2 4 2], 'Tag', 'bg');
        g.Layout.Row = 1; g.Layout.Column = [1 3];
        h.title = uilabel(g, 'Text', sprintf('Lab day %s    Group %g, System D', day, S.group), ...
            'FontSize', 20, 'FontWeight', 'bold');
        h.demo = uilabel(g, 'Text', tern(demo, '  DEMO MODE: no hardware, nothing here is a real measurement  ', ''), ...
            'FontSize', 15, 'FontWeight', 'bold', 'Tag', 'demo', 'HorizontalAlignment', 'center');
        h.folder = uilabel(g, 'Text', ['data: ' shortpath(datadir)], 'FontSize', 12, 'Tag', 'muted');
        uilabel(g, 'Text', 'Mode', 'FontSize', 13, 'HorizontalAlignment', 'right');
        h.theme = uiswitch(g, 'slider', 'Items', {'Light', 'Dark'}, 'Value', tern(strcmp(G.theme, 'dark'), 'Dark', 'Light'), ...
            'ValueChangedFcn', cb(@(s, ~) setTheme(lower(s.Value))), 'Tooltip', 'Light or dark window (remembered)');

        % ---- left: the steps
        p = uipanel(h.main, 'Title', 'Steps   (click one step, or a run P / S / F / A)', 'FontSize', 14, 'FontWeight', 'bold');
        p.Layout.Row = 2; p.Layout.Column = 1;
        g = uigridlayout(p, [2 1], 'RowHeight', {'1x', 40}, 'Padding', [6 6 6 6], 'RowSpacing', 4);
        h.tree = uitree(g, 'FontSize', 14, 'Multiselect', 'on', 'SelectionChangedFcn', cb(@(~, ~) onTree()));
        letters = unique(cellfun(@(s) s(1), {P.id}), 'stable');
        h.grp = struct(); h.node = struct();
        for c = letters
            ids = {P(strcmp({P.grp}, c)).id};
            t = titles.(c);
            if ~isempty(ids), t = sprintf('%s   [run %s]', t, c); end
            h.grp.(c) = uitreenode(h.tree, 'Text', t, 'NodeData', struct('grp', c));
            for s = P(cellfun(@(x) x(1) == c, {P.id}))'
                h.node.(s.id) = uitreenode(h.grp.(c), 'Text', s.id, 'NodeData', struct('id', s.id));
            end
        end
        expand(h.tree, 'all');
        h.legend = uilabel(g, 'Text', ['Lamp: grey = not done, green = OK, orange = CHECK, red = BAD.' newline ...
            'Ctrl+click = your own run of up to 3 chamber steps.'], 'FontSize', 11, 'Tag', 'muted', 'WordWrap', 'on');

        % ---- middle
        mid = uigridlayout(h.main, [4 1], 'RowHeight', {236, 58, 104, '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 8, 'Tag', 'bg');
        mid.Layout.Row = 2; mid.Layout.Column = 2;

        p = uipanel(mid, 'Title', 'What to set up', 'FontSize', 14, 'FontWeight', 'bold');
        g = uigridlayout(p, [5 3], 'RowHeight', {28, '1x', '1x', '1x', 28}, 'ColumnWidth', {150, 320, '1x'}, ...
            'Padding', [8 4 8 6], 'RowSpacing', 3, 'ColumnSpacing', 8);
        h.runTitle = uilabel(g, 'Text', '', 'FontSize', 18, 'FontWeight', 'bold');
        h.runTitle.Layout.Row = 1; h.runTitle.Layout.Column = [1 3];
        unit = {'WOOFER', 'MID', 'TWEETER'};
        for k = 1:3
            h.when(k) = uilabel(g, 'Text', '', 'FontSize', 15, 'FontWeight', 'bold', 'Tag', 'instr', ...
                'HorizontalAlignment', 'center', 'WordWrap', 'on');
            h.when(k).Layout.Row = k + 1; h.when(k).Layout.Column = 1;
            % the switchboard for this step: three ON/OFF indicators
            h.swgrid(k) = uigridlayout(g, [1 3], 'Padding', [2 8 2 8], 'ColumnSpacing', 5, 'Tag', 'sw');
            h.swgrid(k).Layout.Row = k + 1; h.swgrid(k).Layout.Column = 2;
            for u = 1:3
                h.sw(k, u) = uilabel(h.swgrid(k), 'Text', unit{u}, 'FontSize', 12, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', 'Tag', 'swlamp', 'UserData', unit{u}, ...
                    'Tooltip', 'The switchboard in the chamber: set this unit ON or OFF');
            end
            h.what(k) = uilabel(g, 'Text', '', 'FontSize', 14, 'WordWrap', 'on', 'Tag', 'instr');
            h.what(k).Layout.Row = k + 1; h.what(k).Layout.Column = 3;
        end
        h.facts = uilabel(g, 'Text', '', 'FontSize', 14, 'FontWeight', 'bold', 'Tag', 'facts');
        h.facts.Layout.Row = 5; h.facts.Layout.Column = [1 3];

        g = uigridlayout(mid, [1 3], 'ColumnWidth', {250, '1x', 330}, 'Padding', [0 0 0 0], 'ColumnSpacing', 10, 'Tag', 'bg');
        h.go = uibutton(g, 'Text', 'Measure', 'FontSize', 24, 'FontWeight', 'bold', 'Tag', 'go', ...
            'ButtonPushedFcn', cb(@(~, ~) doMeasure()));
        h.bar = uigridlayout(g, [1 2], 'ColumnWidth', {'0x', '1x'}, 'Padding', [0 14 0 14], 'ColumnSpacing', 0, 'Tag', 'bg');
        h.barDone = uilabel(h.bar, 'Text', '', 'Tag', 'bardone');
        h.barLeft = uilabel(h.bar, 'Text', '', 'Tag', 'barleft');
        h.prog = uilabel(g, 'Text', '', 'FontSize', 14, 'WordWrap', 'on');

        p = uipanel(mid, 'Title', 'Verdict and what to do next', 'FontSize', 14, 'FontWeight', 'bold');
        g = uigridlayout(p, [1 2], 'ColumnWidth', {170, '1x'}, 'Padding', [6 4 6 6], 'ColumnSpacing', 8);
        h.verdict = uilabel(g, 'Text', '', 'FontSize', 26, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
            'Tag', 'verdict', 'WordWrap', 'on');
        h.advice = uitextarea(g, 'Editable', 'off', 'FontSize', 14, 'Value', {''});

        h.tabs = uitabgroup(mid);
        t = uitab(h.tabs, 'Title', '  This run  ');
        g = uigridlayout(t, [3 2], 'RowHeight', {26, '2x', '1x'}, 'ColumnWidth', {80, '1x'}, 'Padding', [6 4 6 4], 'RowSpacing', 2);
        uilabel(g, 'Text', 'Show run:', 'FontSize', 13);
        h.pick = uidropdown(g, 'Items', {'no runs yet'}, 'ItemsData', 0, 'FontSize', 13, ...
            'ValueChangedFcn', cb(@(s, ~) viewRun(s.Value)));
        h.axRun = gobjects(1, 2);
        for k = 1:2, h.axRun(k) = uiaxes(g); h.axRun(k).Layout.Row = k + 1; h.axRun(k).Layout.Column = [1 2]; end
        h.tabRun = t;
        t = uitab(h.tabs, 'Title', '  All runs today  ');
        g = uigridlayout(t, [2 1], 'RowHeight', {'2x', '1x'}, 'Padding', [6 4 6 4], 'RowSpacing', 2);
        h.axAll = [uiaxes(g) uiaxes(g)];
        h.tabAll = t;
        t = uitab(h.tabs, 'Title', '  Impedance  ');
        g = uigridlayout(t, [2 2], 'RowHeight', {'3x', '2x'}, 'Padding', [6 4 6 4], 'RowSpacing', 2);
        h.axZ = [uiaxes(g) uiaxes(g) uiaxes(g) uiaxes(g)];
        h.axZ(1).Layout.Row = 1; h.axZ(1).Layout.Column = 1; h.axZ(2).Layout.Row = 2; h.axZ(2).Layout.Column = 1;
        h.axZ(3).Layout.Row = 1; h.axZ(3).Layout.Column = 2; h.axZ(4).Layout.Row = 2; h.axZ(4).Layout.Column = 2;
        h.tabZ = t;
        t = uitab(h.tabs, 'Title', '  Near field  ');
        g = uigridlayout(t, [2 1], 'RowHeight', {'3x', '2x'}, 'Padding', [6 4 6 4], 'RowSpacing', 2);
        h.axNF = [uiaxes(g) uiaxes(g)];
        h.tabNF = t;

        % ---- right
        flds = settingFields();
        rows = {30*size(flds, 1) + 44, 104, '1x'};
        if demo, rows = [rows(1) {62} rows(2:3)]; end
        right = uigridlayout(h.main, [numel(rows) 1], 'RowHeight', rows, 'Padding', [0 0 0 0], 'RowSpacing', 8, 'Tag', 'bg');
        right.Layout.Row = 2; right.Layout.Column = 3;

        p = uipanel(right, 'Title', 'Settings of the day (stored in every measurement)', 'FontSize', 13, 'FontWeight', 'bold');
        g = uigridlayout(p, [size(flds, 1) 2], 'RowHeight', repmat({24}, 1, size(flds, 1)), 'ColumnWidth', {165, '1x'}, ...
            'Padding', [6 4 6 4], 'RowSpacing', 6, 'ColumnSpacing', 6);
        h.set = struct();
        for i = 1:size(flds, 1)
            uilabel(g, 'Text', flds{i, 2}, 'FontSize', 12);
            n = flds{i, 1};
            if strcmp(flds{i, 3}, 'drop')
                h.set.(n) = uidropdown(g, 'Items', unique([flds{i, 4}, {S.(n)}], 'stable'), 'Value', S.(n), 'Editable', 'on', ...
                    'FontSize', 12, 'ValueChangedFcn', cb(@(s, ~) setSetting(n, s.Value)));
            else
                h.set.(n) = uieditfield(g, 'text', 'Value', val2str(S.(n)), 'FontSize', 12, ...
                    'ValueChangedFcn', cb(@(s, ~) setSetting(n, s.Value)));
            end
        end

        if demo
            p = uipanel(right, 'Title', 'Demo: what goes wrong in the next measurement', 'FontSize', 13, 'FontWeight', 'bold');
            g = uigridlayout(p, [1 1], 'Padding', [6 4 6 4]);
            h.fault = uidropdown(g, 'FontSize', 13, 'Items', {'none (everything as expected)', 'woofer loud', 'placement', ...
                'not switched', 'quiet', 'clipping', 'dc offset', 'no umik', 'no beeps'}, ...
                'ItemsData', {'none', 'woofer loud', 'placement', 'not switched', 'quiet', 'clipping', 'dc offset', 'no umik', 'no beeps'}, ...
                'ValueChangedFcn', cb(@(s, ~) setFault(s.Value)));
        end

        p = uipanel(right, 'Title', 'The day''s data', 'FontSize', 13, 'FontWeight', 'bold');
        g = uigridlayout(p, [2 2], 'Padding', [6 4 6 4], 'RowSpacing', 6, 'ColumnSpacing', 6);
        h.btnDash = uibutton(g, 'Text', 'Full dashboard', 'FontSize', 13, 'ButtonPushedFcn', cb(@(~, ~) dashboard()), ...
            'Tooltip', 'Every tab of the day in a normal MATLAB figure');
        h.btnExport = uibutton(g, 'Text', 'Export figures', 'FontSize', 13, 'ButtonPushedFcn', cb(@(~, ~) exportFigures()), ...
            'Tooltip', 'Save every dashboard tab as PNG (always light, for the report)');
        h.btnCopy = uibutton(g, 'Text', 'Copy data to ...', 'FontSize', 13, 'ButtonPushedFcn', cb(@(~, ~) copyData()), ...
            'Tooltip', 'Copy the whole day folder to a folder you choose (USB stick)');
        h.btnManual = uibutton(g, 'Text', 'Load manual runs ...', 'FontSize', 13, 'ButtonPushedFcn', cb(@(~, ~) loadManual()), ...
            'Tooltip', 'Show runs made with project_run.m / zinf_run.m (the files are only read)');

        p = uipanel(right, 'Title', 'Log (saved files, warnings and their fixes)', 'FontSize', 13, 'FontWeight', 'bold');
        g = uigridlayout(p, [1 1], 'Padding', [4 4 4 4]);
        h.log = uitextarea(g, 'Editable', 'off', 'FontSize', 12, 'Value', {''});
    end

    function onResize()
        p = h.fig.Position; lowH = p(4) < 760; lowW = p(3) < 1250;
        h.main.RowHeight = {40, tern(lowH, 700, '1x')};
        h.main.ColumnWidth = {370, tern(lowW, 540, '1x'), 340};
        try, h.main.Scrollable = tern(lowH || lowW, 'on', 'off'); catch, end
    end

    function f = settingFields()
        f = {
            'out1_gain',   'Out 1 gain, woofer (dB)',      'num',  {}
            'out2_gain',   'Out 2 gain, mid + tw (dB)',    'num',  {}
            'amp_volume',  'Amplifier volume',             'text', {}
            'UmikSN',      'UMIK serial (on its label)',   'drop', {'708-0329', '708-0332', '708-0335'}
            'R_series',    'Series R, multimeter (ohm)',   'num',  {}
            'vent_mm',     'Open vent length (mm)',        'num',  {}
            'NexusVperPa', 'Nexus setting (V/Pa)',         'num',  {}
            'T_celsius',   'Temperature (deg C)',          'num',  {}
            'placement',   'Placement',                    'text', {}
            'group',       'Group',                        'num',  {}
            'notes',       'Notes',                        'text', {}
            };
        f = f(ismember(f(:, 1), fieldnames(S)), :);
        for n = setdiff(fieldnames(S)', [f(:, 1)' {'date'}], 'stable')      % a field added to lab_setup.m later
            f(end+1, :) = {n{1}, n{1}, tern(isnumeric(S.(n{1})), 'num', 'text'), {}}; %#ok<AGROW>
        end
    end

% =========================================================================
%  Colours (one palette, light or dark)
% =========================================================================
    function applyTheme()
        C = lab_palette(G.theme);
        try, h.fig.Theme = G.theme; catch, end          % R2025a+; everything below is explicit anyway
        h.fig.Color = C.bg;
        for o = findall(h.fig)'
            try
                switch class(o)
                    case 'matlab.ui.container.GridLayout'
                        o.BackgroundColor = tern(strcmp(o.Tag, 'bg'), C.bg, C.panel);
                    case {'matlab.ui.container.Panel', 'matlab.ui.container.Tab'}
                        o.BackgroundColor = C.panel; o.ForegroundColor = C.text;
                        try, o.BorderColor = C.line; catch, end
                    case 'matlab.ui.control.Label'
                        o.FontColor = tern(strcmp(o.Tag, 'muted'), C.muted, C.text);
                    case {'matlab.ui.control.Button', 'matlab.ui.control.StateButton'}
                        o.BackgroundColor = C.btn; o.FontColor = C.btntext;
                    case {'matlab.ui.control.EditField', 'matlab.ui.control.DropDown', 'matlab.ui.control.TextArea', ...
                          'matlab.ui.container.Tree', 'matlab.ui.control.NumericEditField'}
                        o.BackgroundColor = C.field; o.FontColor = C.text;
                    case {'matlab.ui.control.Switch', 'matlab.ui.control.ToggleSwitch', 'matlab.ui.control.RockerSwitch'}
                        o.FontColor = C.text;
                end
            catch
            end
        end
        if demo, h.demo.BackgroundColor = C.demo; h.demo.FontColor = tern(strcmp(C.mode, 'dark'), [1 1 1], [0.2 0.1 0]); end
        h.facts.BackgroundColor = tern(isempty(sel), C.panel, C.facts);
        h.barDone.BackgroundColor = C.go; h.barLeft.BackgroundColor = C.field;
        lampIcons();
        refreshTree(); refreshSwitchboard(); refreshGo(); highlight(0); refreshVerdict(); redraw();
    end

    function setTheme(mode)
        mode = lower(char(mode));
        if ~any(strcmp(mode, {'light', 'dark'})), return; end
        G.theme = mode;
        h.theme.Value = tern(strcmp(mode, 'dark'), 'Dark', 'Light');
        applyTheme();
        saveSettings();
        drawnow;
    end

    function lampIcons()
        % small round lamps as PNG files (uitree icons), in the palette's colours
        d = fullfile(tempdir, 'labgui_icons'); if ~exist(d, 'dir'), mkdir(d); end
        [x, y] = meshgrid(linspace(-1, 1, 32));
        r = hypot(x, y); a = max(0, min(1, (0.86 - r)*12));
        h.icon = struct();
        for v = {'ok', 'check', 'bad', 'none'}
            c = C.(v{1}); img = zeros(32, 32, 3);
            for k = 1:3, img(:,:,k) = c(k) * (1 - 0.25*(r > 0.66)); end
            f = fullfile(d, sprintf('%s_%s.png', C.mode, v{1}));
            try, imwrite(img, f, 'Alpha', a); catch, f = ''; end
            h.icon.(v{1}) = f;
        end
    end

    function c = vcol(v)
        switch v
            case 'OK', c = C.ok; case 'CHECK', c = C.check; case 'BAD', c = C.bad; otherwise, c = C.none;
        end
    end

% =========================================================================
%  Data -> display
% =========================================================================
    function reload(show)
        % read the day's folder again (the files are the truth), then redraw everything
        try
            [runs, status] = lab_runs(datadir, manual);
        catch e
            runs = {}; status = struct(); logmsg(['Could not read the data folder: ' e.message]);
        end
        nday = sum(~cellfun(@(m) m.manual, runs));
        if nargin < 1 || isequal(show, 0), show = nday; end
        items = {'no runs yet'}; data = 0;
        if ~isempty(runs)
            items = cellfun(@(m) sprintf('%s   %s   [%s]   %s%s', char(datetime(m.time, 'Format', 'dd-MMM HH:mm')), m.file, ...
                strjoin(m.ids, ' '), m.verdict, tern(m.manual, '   (manual run, not from today''s folder)', '')), runs, 'UniformOutput', false);
            data = 1:numel(runs);
            if show < 1 || show > numel(runs), show = numel(runs); end
        end
        h.pick.Items = items; h.pick.ItemsData = data;
        viewIdx = show;
        if ~isempty(runs), h.pick.Value = viewIdx; end
        refreshTree(); refreshVerdict(); redraw();
    end

    function refreshTree()
        for s = P'
            n = h.node.(s.id); t = sprintf('%s   %s', s.id, s.title); v = '';
            if isfield(status, s.id)
                st = status.(s.id); v = st.verdict;
                t = sprintf('%s   %s %s   %s', s.id, v, char(datetime(st.time, 'Format', 'HH:mm')), regexprep(s.title, '^[^:]*: ', ''));
            end
            n.Text = t; setIcon(n, v);
        end
        for c = fieldnames(h.grp)'
            ids = {P(strcmp({P.grp}, c{1})).id}; v = '';
            if ~isempty(ids) && all(isfield(status, ids))
                v = lab_worst(cellfun(@(i) status.(i).verdict, ids, 'UniformOutput', false));
            end
            setIcon(h.grp.(c{1}), v);
        end
    end

    function setIcon(n, v)
        k = lower(v); if isempty(k), k = 'none'; end
        try, if ~isempty(h.icon.(k)), n.Icon = h.icon.(k); end, catch, end
    end

    function refreshInstr()
        for k = 1:3, h.when(k).Text = ''; h.what(k).Text = ''; end
        swstate = cell(1, 3);
        if isempty(sel)
            h.runTitle.Text = selErr; h.facts.Text = ''; TL = [];
        else
            st = lab_steps(sel);
            I = lab_instructions(st, S);
            TL = lab_timeline(st, 64);
            h.runTitle.Text = sprintf('%s    (takes about %s)', strjoin(cellfun(@(a, b) [a ' ' b], {st.id}, ...
                cellfun(@(t) regexprep(t, '^[^:]*: ', ''), {st.title}, 'UniformOutput', false), 'UniformOutput', false), '  +  '), mmss(TL.total));
            for k = 1:numel(st)
                h.when(k).Text = upper(I.when{k});
                h.what(k).Text = sprintf('%s:  %s', st(k).id, I.what{k});
                h.what(k).Tooltip = h.what(k).Text;
                swstate{k} = I.sw{k};
            end
            h.facts.Text = ['  ' I.facts];
        end
        h.facts.BackgroundColor = tern(isempty(sel), C.panel, C.facts);
        refreshSwitchboard();
        highlight(0); refreshGo();
    end

    function refreshSwitchboard()
        % Woofer / Mid / Tweeter ON or OFF for the state to set NOW and after each beep
        for k = 1:3
            on = swstate{k};
            for u = 1:3
                l = h.sw(k, u);
                if isempty(on)
                    l.Visible = 'off';
                else
                    l.Visible = 'on';
                    l.Text = sprintf('%s %s', l.UserData, tern(on(u), 'ON', 'OFF'));
                    l.BackgroundColor = tern(on(u), C.swon, C.swoff);
                    l.FontColor = tern(on(u), C.swontext, C.swofftext);
                end
            end
        end
    end

    function refreshGo()
        if measuring
            h.go.Text = 'Measuring ...'; h.go.Enable = 'off'; h.go.BackgroundColor = C.busy; h.go.FontColor = C.busytext;
        elseif isempty(sel)
            h.go.Text = 'Measure'; h.go.Enable = 'off'; h.go.BackgroundColor = C.busy; h.go.FontColor = C.busytext;
        else
            [~, ~, label] = lab_steps(sel);
            h.go.Text = ['Measure ' label]; h.go.Enable = 'on'; h.go.BackgroundColor = C.go; h.go.FontColor = C.gotext;
        end
    end

    function highlight(k)
        % mark the instruction that applies right now (k = 0: none)
        for i = 1:3
            on = i == k;
            h.when(i).BackgroundColor = tern(on, C.now, C.panel);
            h.what(i).BackgroundColor = tern(on, C.now, C.panel);
            h.swgrid(i).BackgroundColor = tern(on, C.now, C.panel);
            h.what(i).FontWeight = tern(on, 'bold', 'normal');
        end
    end

    function refreshVerdict()
        if viewIdx < 1 || viewIdx > numel(runs)
            lastAdvice = struct('verdict', '', 'lines', {{'Nothing measured yet. Pick a step on the left, set it up as the box above says, press Measure.'}});
            h.verdict.Text = '-'; h.verdict.BackgroundColor = C.none;
        else
            m = runs{viewIdx};
            try
                lastAdvice = lab_advice(m, status);
            catch e
                lastAdvice = struct('verdict', m.verdict, 'lines', {{['No advice for this run: ' e.message]}});
            end
            h.verdict.Text = sprintf('%s\n%s', m.verdict, m.label);
            h.verdict.BackgroundColor = vcol(m.verdict);
            if m.manual, h.verdict.Text = sprintf('%s\nmanual run', m.verdict); end
        end
        h.verdict.FontColor = tern(strcmp(C.mode, 'dark'), [0.05 0.05 0.05], [1 1 1]);
        h.advice.Value = lastAdvice.lines(:);
    end

    function redraw()
        if viewIdx >= 1 && viewIdx <= numel(runs)
            tryview('run', h.axRun, runs{viewIdx});
        else
            tryview('empty', h.axRun(1), {'Nothing measured yet', 'The run you measure is drawn here against its expected curve.'});
            tryview('empty', h.axRun(2), '');
        end
        tryview('overlay', h.axAll, runs);
        tryview('z', h.axZ, runs);
        tryview('nf', h.axNF, runs);
    end

    function tryview(kind, ax, arg)
        try
            lab_view(kind, ax, C, arg);
        catch e
            try, lab_view('empty', ax, C, {'This plot could not be drawn:', e.message}); catch, end
            logmsg(sprintf('Plot "%s" could not be drawn: %s', kind, e.message));
        end
    end

% =========================================================================
%  Actions
% =========================================================================
    function onTree()
        if measuring, return; end
        nodes = h.tree.SelectedNodes; ids = {}; g = '';
        for n = nodes(:)'
            d = n.NodeData;
            if isfield(d, 'id'), ids{end+1} = d.id; else, g = d.grp; end %#ok<AGROW>
        end
        if isempty(ids) && ~isempty(g)
            ids = {P(strcmp({P.grp}, g)).id};
            if isempty(ids)
                setSel({}, 'At the Zi/Nfield station one step is one run: pick ONE step below this heading.'); return
            end
        end
        setSel(ids, 'Pick a step or a run on the left.');
    end

    function select(what)
        % from code: select('P'), select('S4'), select({'S4','S5','S3'})
        [~, ids] = lab_steps(what);
        nodes = cellfun(@(i) h.node.(i), ids, 'UniformOutput', false);
        h.tree.SelectedNodes = [nodes{:}];
        setSel(ids, '');
    end

    function setSel(ids, hint)
        sel = {};
        if ~isempty(ids)
            [~, i] = ismember(ids, {P.id}); i = sort(i); ids = {P(i).id};
            g = unique({P(i).grp});
            whole = numel(g) == 1 && ~isempty(g{1}) && sum(strcmp({P.grp}, g{1})) == numel(ids);
            if ~whole                                                 % a run of your own: "all" last (everything is switched back ON at the end)
                last = ismember({P(i).model}, {'all'});
                ids = [ids(~last) ids(last)];
            end
            try
                lab_steps(ids); sel = ids;
            catch e
                [~, fix] = lab_fix(e); hint = [e.message ' ' fix];
            end
        end
        selErr = hint;
        refreshInstr();
        if ~isempty(sel) && isfield(status, sel{1}) && status.(sel{1}).run ~= viewIdx
            viewRun(status.(sel{1}).run);                             % a step already measured: show it
        end
    end

    function viewRun(i)
        if ischar(i) || isstring(i)
            i = find(cellfun(@(m) strcmp(m.file, char(i)), runs), 1, 'last');
        end
        if isempty(i) || i < 1 || i > numel(runs), return; end
        viewIdx = i; h.pick.Value = i;
        refreshVerdict();
        tryview('run', h.axRun, runs{i});
        h.tabs.SelectedTab = h.tabRun;
    end

    function m = doMeasure()
        m = [];
        if measuring, return; end
        if isempty(sel), logmsg('Pick a step or a run on the left first.'); return; end
        [st, ids, label] = lab_steps(sel);
        TL = lab_timeline(st, 64);
        measuring = true; busy(true);
        h.verdict.Text = 'measuring'; h.verdict.BackgroundColor = C.none;
        h.advice.Value = {'Measuring. Do not touch the amplifier volume or move the microphone.', ...
            'In a run of several steps: switch during the beeps, as the box above says.'};
        logmsg(sprintf('Measuring %s (%s), about %s ...', label, strjoin(ids, ' + '), mmss(TL.total)));
        t0 = tic; tick();
        tmr = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.2, 'TimerFcn', @(~, ~) tick(), 'ErrorFcn', @(~, ~) []);
        start(tmr); drawnow;
        err = [];
        try
            if demo, dm = D; else, dm = []; end
            [m, file, W] = lab_measure(sel, S, datadir, 'note', S.notes, 'demo', dm);
        catch e
            err = e;
        end
        try, stop(tmr); delete(tmr); catch, end
        tmr = []; measuring = false; busy(false); highlight(0);
        setbar(0); h.prog.Text = '';
        if ~isempty(err)
            [what, fix] = lab_fix(err);
            logmsg(sprintf('NOT MEASURED: %s', what));
            logmsg(sprintf('   message: %s%s', err.message, where(err)));
            logmsg(sprintf('   FIX: %s', fix));
            h.verdict.Text = sprintf('NOT\nMEASURED'); h.verdict.BackgroundColor = C.bad;
            h.advice.Value = {what, ['FIX: ' fix], ['(MATLAB said: ' err.message ')'], 'Nothing was saved. The earlier runs are untouched.'};
            lastAdvice = struct('verdict', 'ERROR', 'lines', {h.advice.Value'});
            drawnow; m = [];
            return
        end
        logmsg(sprintf('Saved %s', shortpath(file)));
        for w = W
            logmsg(sprintf('%s: %s', tern(strcmp(w.level, 'warn'), 'WARNING', 'Note'), w.msg));
            logmsg(sprintf('   FIX: %s', w.fix));
        end
        reload(0);
        mm = runs{viewIdx};
        logmsg(sprintf('Verdict %s: %s', mm.label, mm.verdict));
        for r = mm.R, if ~strcmp(r.verdict, 'OK'), logmsg(sprintf('   %s %s: %s', r.id, r.verdict, r.msg)); end, end
        if ~isempty(W) && any(strcmp({W.level}, 'warn'))
            h.advice.Value = [arrayfun(@(w) sprintf('WARNING: %s %s', w.msg, w.fix), W(strcmp({W.level}, 'warn')), 'UniformOutput', false)'; h.advice.Value];
            lastAdvice.lines = h.advice.Value';
        end
        h.tabs.SelectedTab = h.tabRun;
        drawnow;
    end

    function tick()
        % progress while the course routine runs (it blocks MATLAB: if the display does not
        % move on the lab PC, the expected end time shown at the start still holds)
        try
            if isempty(t0) || isempty(TL), return; end
            el = toc(t0); if demo, el = el * D.speed; end
            setbar(min(el / TL.total, 1));
            i = find(el >= [TL.seg.t0] & el < [TL.seg.t1], 1);
            n = numel(sel);
            if isempty(i)
                txt = 'finishing ...'; highlight(0);
            else
                s = TL.seg(i);
                if strcmp(s.kind, 'beeps')
                    txt = sprintf('BEEPS %d: SWITCH NOW for %s', s.k - 1, sel{s.k});
                else
                    txt = sprintf('measuring %s (step %d of %d)', sel{s.k}, s.k, n);
                end
                highlight(s.k);
            end
            h.prog.Text = sprintf('%s\n%s of about %s   (done at %s)', txt, mmss(el), mmss(TL.total), ...
                char(datetime('now') + seconds(max(TL.total - el, 0) / tern(demo, D.speed, 1)), 'HH:mm:ss'));
        catch
        end
    end

    function setbar(p)
        p = max(0, min(1, p));
        h.bar.ColumnWidth = {sprintf('%gx', round(1000*p)), sprintf('%gx', round(1000*(1 - p)))};
    end

    function busy(on)
        s = tern(on, 'off', 'on');
        h.tree.Enable = s; h.pick.Enable = s;
        for n = fieldnames(h.set)', h.set.(n{1}).Enable = s; end
        for b = [h.btnDash h.btnExport h.btnCopy h.btnManual], b.Enable = s; end
        if demo, h.fault.Enable = s; end
        refreshGo();
    end

    function ok = setSetting(name, value)
        % from a settings field or from code: setSetting('out1_gain', -8.1)
        ok = false;
        if ~isfield(S, name) || strcmp(name, 'date'), logmsg(['No such setting: ' name]); return; end
        old = S.(name);
        if isnumeric(old)
            if ischar(value) || isstring(value)
                t = strtrim(strrep(char(value), ',', '.'));
                if isempty(t) || strcmpi(t, 'nan'), value = NaN; else, value = str2double(t); end
                if isnan(value) && ~(isempty(t) || strcmpi(t, 'nan'))
                    logmsg(sprintf('"%s" is not a number: %s stays %s.', t, name, val2str(old)));
                    h.set.(name).Value = val2str(old); return
                end
            end
            value = double(value);
        else
            value = char(value);
        end
        S.(name) = value;
        if isa(h.set.(name), 'matlab.ui.control.DropDown')
            if ~any(strcmp(h.set.(name).Items, value)), h.set.(name).Items{end+1} = value; end
            h.set.(name).Value = value;
        else
            h.set.(name).Value = val2str(value);
        end
        if ~isequaln(old, value)
            logmsg(sprintf('Setting %s: %s -> %s (stored with every measurement from now on)', name, val2str(old), val2str(value)));
            saveSettings();
        end
        if strcmp(name, 'group'), h.title.Text = sprintf('Lab day %s    Group %g, System D', day, S.group); end
        refreshInstr();
        ok = true;
    end

    function saveSettings()
        try
            lab_settings(datadir, S, G);
        catch e
            logmsg(['Settings could not be stored: ' e.message]);
        end
    end

    function setFault(f)
        if ~demo, return; end
        D.fault = f; h.fault.Value = f;
        logmsg(sprintf('Demo: the next measurement goes wrong like this: %s', f));
    end

    function fig = dashboard()
        fig = [];
        if isempty(dir(fullfile(datadir, '*.mat'))), logmsg('Dashboard: nothing measured yet.'); return; end
        fig = lab_dash(datadir, 'focus', 'Plan', 'save', false);
        logmsg('Dashboard opened (a normal MATLAB figure; it is redrawn from the files each time).');
    end

    function files = exportFigures()
        files = {};
        if isempty(dir(fullfile(datadir, '*.mat'))), logmsg('Export: nothing measured yet.'); return; end
        had = ~isempty(findobj(0, 'Type', 'figure', 'Tag', 'labdash'));
        logmsg('Exporting the figures of the day ...'); drawnow;
        fig = lab_dash(datadir, 'focus', 'Plan', 'save', true);          % always light: for the report
        if ~had, try, close(fig); catch, end, end
        d = dir(fullfile(datadir, 'figures', '*.png'));
        files = fullfile({d.folder}, {d.name});
        logmsg(sprintf('Exported %d figures (PNG) to %s', numel(files), fullfile(datadir, 'figures')));
    end

    function target = copyData(dest)
        target = '';
        if nargin < 1 || isempty(dest)
            dest = uigetdir(char(java.lang.System.getProperty('user.home')), 'Copy the day''s data to (e.g. the USB stick)');
            figure(h.fig);
            if isequal(dest, 0), return; end
        end
        if ~exist(datadir, 'dir'), logmsg('Copy: nothing measured yet.'); return; end
        [~, day] = fileparts(datadir);
        base = fullfile(dest, [tern(demo, 'labday_DEMO_', 'labday_') day]); target = base; k = 2;
        while exist(target, 'dir') || exist(target, 'file'), target = sprintf('%s_%d', base, k); k = k + 1; end
        copyfile(datadir, target);
        n = numel(dir(fullfile(target, '*.mat')));
        logmsg(sprintf('Copied the day (%d runs, figures, settings, log) to %s', n, target));
    end

    function n = loadManual(files)
        % runs made with project_run.m / zinf_run.m: converted in memory, originals only read
        n = 0;
        if nargin < 1 || isempty(files)
            [f, d] = uigetfile({'project_*.mat;zinf_*.mat', 'Runs of the Run Section scripts'}, ...
                'Load manual runs (they are only read)', [L.data filesep], 'MultiSelect', 'on');
            figure(h.fig);
            if isequal(f, 0), return; end
            files = fullfile(d, cellstr(f));
        end
        files = cellstr(files);
        if numel(files) == 1 && exist(files{1}, 'dir')
            d = [dir(fullfile(files{1}, 'project_*.mat')); dir(fullfile(files{1}, 'zinf_*.mat'))];
            files = fullfile({d.folder}, {d.name});
        end
        for i = 1:numel(files)
            try
                m = lab_convert(files{i});
                manual(cellfun(@(x) strcmp(x.path, m.path), manual)) = [];
                manual{end+1} = m; n = n + 1; %#ok<AGROW>
                logmsg(sprintf('Loaded manual run %s as %s%s', m.file, strjoin(m.ids, ' + '), tern(isempty(m.note), '', [' (' m.note ')'])));
            catch e
                logmsg(sprintf('Could not load %s: %s', files{i}, e.message));
            end
        end
        if n
            [~, i] = sort(cellfun(@(m) posixtime(datetime(m.time)), manual)); manual = manual(i);
            reload(-1);
            logmsg('Manual runs are in the "Show run" list and in the plots. Their files were only read. The lamps show today''s folder only.');
        end
    end

    function preflight()
        % real mode: say early what is missing
        try
            if isempty(which('meas_mag_spec2_SoundCard_LabE')) && exist(L.labEcourse, 'dir'), addpath(L.labEcourse, '-end'); end
            if isempty(which('meas_mag_spec2_LabD')) && exist(L.labDcourse, 'dir'), addpath(L.labDcourse, '-end'); end
            if isempty(which('meas_mag_spec2_SoundCard_LabE')) && isempty(which('meas_mag_spec2_LabD'))
                logmsg('WARNING: the course routines were not found.');
                logmsg(sprintf('   FIX: the Labs folder must contain %s and %s.', L.labEcourse, L.labDcourse));
            end
            a = audiodevinfo; names = {};
            if isfield(a, 'input') && ~isempty(a.input), names = {a.input.Name}; end
            if any(contains(names, 'Umik'))
                logmsg('UMIK found: this is a chamber PC. Start with P.');
            else
                logmsg('No UMIK found: fine at the Zi/Nfield station. In the chamber: plug the UMIK in and RESTART MATLAB.');
            end
        catch
        end
    end

    function file = screenshot(file)
        drawnow; pause(0.5); drawnow;
        exportapp(h.fig, file);
    end

    function onClose(varargin)
        if measuring, logmsg('Measuring: wait until it has finished, then close.'); return; end
        try, if ~isempty(tmr), stop(tmr); delete(tmr); end, catch, end
        delete(h.fig);
    end

    function s = state()
        s = struct('selected', {sel}, 'measuring', measuring, 'datadir', datadir, 'demo', demo, ...
            'status', status, 'nruns', numel(runs), 'viewed', '', 'verdict', '', 'advice', {lastAdvice.lines}, ...
            'log', {loglines}, 'settings', S, 'theme', G.theme, 'goEnabled', strcmp(char(h.go.Enable), 'on'), ...
            'instructions', {[{h.runTitle.Text}, arrayfun(@(k) [h.when(k).Text ' ' h.what(k).Text], 1:3, 'UniformOutput', false), {h.facts.Text}]});
        wmt = 'WMT';
        s.switchboard = cell(1, 3);                       % per instruction row: e.g. 'W on, M off, T off'
        for q = 1:3
            if ~isempty(swstate{q})
                s.switchboard{q} = strjoin(arrayfun(@(u) sprintf('%s %s', wmt(u), tern(swstate{q}(u), 'on', 'off')), 1:3, 'UniformOutput', false), ', ');
            end
        end
        s.lamp = struct();
        for q = P', s.lamp.(q.id) = 'grey'; end
        for q = fieldnames(status)'
            s.lamp.(q{1}) = strrep(strrep(strrep(status.(q{1}).verdict, 'OK', 'green'), 'CHECK', 'orange'), 'BAD', 'red');
        end
        if viewIdx >= 1 && viewIdx <= numel(runs), s.viewed = runs{viewIdx}.file; s.verdict = runs{viewIdx}.verdict; end
        if strcmp(lastAdvice.verdict, 'ERROR'), s.verdict = 'ERROR'; end
    end

% =========================================================================
%  Small things
% =========================================================================
    function logmsg(txt)
        line = sprintf('%s  %s', char(datetime('now', 'Format', 'HH:mm:ss')), txt);
        loglines{end+1} = line;
        try
            h.log.Value = loglines(:);
            try, scroll(h.log, 'bottom'); catch, end
        catch
        end
        try
            if exist(datadir, 'dir')
                fid = fopen(fullfile(datadir, 'labgui_log.txt'), 'a');
                if fid > 0, fprintf(fid, '%s  %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd')), line); fclose(fid); end
            end
        catch
        end
    end

    function f = cb(fn)
        % every callback goes through here: an error is shown in the log, the window lives on
        f = @(varargin) guarded(fn, varargin{:});
    end

    function guarded(fn, varargin)
        try
            fn(varargin{:});
        catch e
            try
                [what, fix] = lab_fix(e);
                logmsg(sprintf('ERROR: %s (%s)', what, e.message));
                logmsg(sprintf('   FIX: %s', fix));
                if measuring, measuring = false; busy(false); end
            catch
            end
        end
    end
end

% ---- helpers without state ------------------------------------------------
function v = tern(c, a, b)
if c, v = a; else, v = b; end
end

function s = mmss(t)
t = round(t);
if t < 60, s = sprintf('%d s', t); else, s = sprintf('%d min %02d s', floor(t/60), mod(t, 60)); end
end

function s = val2str(v)
if isnumeric(v)
    if isempty(v) || (isscalar(v) && isnan(v)), s = ''; else, s = num2str(v); end
else
    s = char(v);
end
end

function s = where(e)
s = '';
if ~isempty(e.stack), s = sprintf('  [%s, line %d]', e.stack(1).name, e.stack(1).line); end
end

function s = shortpath(p)
parts = strsplit(p, filesep);
s = strjoin(parts(max(1, end-2):end), filesep);
end
