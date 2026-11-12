function P = gui_palette(mode)
% GUI_PALETTE  Every colour of labgui and of the kit's graphs, for 'light' or 'dark'.
%   Set explicitly on each component (BackgroundColor, FontColor, axes colours), so the
%   dark mode also works on MATLAB versions without the uifigure Theme property (< R2025a).
%   Report figures (dashboard PNGs, exported graphs) always use the light palette.

if nargin < 1 || isempty(mode), mode = 'light'; end
switch lower(char(mode))
case 'dark'
    P.name    = 'dark';
    P.bg      = [0.11 0.12 0.13];        % window
    P.panel   = [0.16 0.17 0.19];        % panels, tabs
    P.fg      = [0.92 0.93 0.94];        % text
    P.muted   = [0.66 0.68 0.71];        % secondary text
    P.field   = [0.22 0.23 0.26];        % edit fields, text areas, drop-downs
    P.btn     = [0.27 0.28 0.31];
    P.grpbtn  = [0.15 0.30 0.50];        % "whole run" buttons
    P.sel     = [0.66 0.50 0.06];        % the selected step
    P.selfg   = [1 1 1];
    P.accent  = [1 0.62 0.25];
    P.measure = [0.13 0.52 0.22];
    P.banner  = struct('demo', [0.72 0.36 0.04], 'live', [0.12 0.40 0.17]);
    P.status  = struct('ready', [0.24 0.25 0.28], 'busy', [0.10 0.30 0.52], 'beeps', [0.70 0.40 0.04], 'fail', [0.50 0.12 0.12]);
    P.lamp    = struct('none', [0.36 0.37 0.40], 'OK', [0.25 0.82 0.35], 'CHECK', [1 0.66 0.15], 'BAD', [1 0.30 0.30]);
    P.vbg     = struct('none', [0.34 0.35 0.38], 'OK', [0.12 0.52 0.22], 'CHECK', [0.80 0.45 0.05], 'BAD', [0.76 0.13 0.13], 'ERROR', [0.45 0.05 0.05]);
    P.axbg    = [0.13 0.14 0.16];
    P.axfg    = [0.86 0.87 0.89];
    P.grid    = [0.80 0.82 0.85];
    P.ink     = [0.96 0.96 0.96];        % "measured" when there is one curve
    P.model   = [1 0.42 0.42];           % "model / Lab D" dashed
    P.swon    = [0.13 0.58 0.25]; P.swonfg = [1 1 1];       % switchboard indicator ON
    P.swoff   = [0.30 0.31 0.34]; P.swofffg = [0.62 0.64 0.67]; % ... OFF
    P.lines   = [0.35 0.70 1.00; 1.00 0.56 0.25; 1.00 0.86 0.30; 0.80 0.56 1.00; 0.45 0.90 0.55; 0.40 0.90 0.95; 1.00 0.50 0.75];
otherwise
    P.name    = 'light';
    P.bg      = [0.95 0.95 0.95];
    P.panel   = [0.98 0.98 0.98];
    P.fg      = [0.10 0.10 0.10];
    P.muted   = [0.38 0.38 0.38];
    P.field   = [1 1 1];
    P.btn     = [0.96 0.96 0.96];
    P.grpbtn  = [0.82 0.90 1.00];
    P.sel     = [1 0.88 0.45];
    P.selfg   = [0 0 0];
    P.accent  = [0.80 0.40 0];
    P.measure = [0.10 0.55 0.20];
    P.banner  = struct('demo', [0.85 0.45 0.05], 'live', [0.15 0.45 0.20]);
    P.status  = struct('ready', [0.92 0.92 0.92], 'busy', [0.75 0.87 1.00], 'beeps', [1 0.72 0.30], 'fail', [1 0.80 0.80]);
    P.lamp    = struct('none', [0.78 0.78 0.78], 'OK', [0 0.55 0], 'CHECK', [0.90 0.50 0], 'BAD', [0.85 0 0]);
    P.vbg     = struct('none', [0.70 0.70 0.70], 'OK', [0 0.55 0], 'CHECK', [0.90 0.50 0], 'BAD', [0.85 0 0], 'ERROR', [0.55 0 0]);
    P.axbg    = [1 1 1];
    P.axfg    = [0.15 0.15 0.15];
    P.grid    = [0.15 0.15 0.15];
    P.ink     = [0 0 0];
    P.model   = [0.90 0 0];
    P.swon    = [0 0.58 0.15];    P.swonfg = [1 1 1];
    P.swoff   = [0.86 0.86 0.86]; P.swofffg = [0.45 0.45 0.45];
    P.lines   = [0 0.447 0.741; 0.850 0.325 0.098; 0.929 0.694 0.125; 0.494 0.184 0.556; 0.466 0.674 0.188; 0.301 0.745 0.933; 0.635 0.078 0.184];
end
P.vtext = P.lamp;                        % verdict colour for text on the axes background
end
