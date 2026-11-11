function C = lab_palette(mode)
% LAB_PALETTE  Every colour of the GUI, for 'light' (default) or 'dark'. ONE place.
%   Window:  bg, panel, field (edit boxes, lists), text, muted, line (borders)
%   Buttons: btn, btntext, go (Measure), gotext, busy, busytext
%   Hints:   now (the instruction that applies right now), facts (the fact line), demo (banner)
%   Switchboard: swon / swontext (a unit that is ON), swoff / swofftext (OFF)
%   Verdict: ok, check, bad, none  (readable as text AND as a lamp on that background)
%   Plots:   axbg, axfg (ticks, labels), grid, model (reference lines), curves (n x 3,
%            distinct from each other and from the background)

if nargin < 1 || ~strcmpi(mode, 'dark')
    C.mode = 'light';
    C.bg = [0.94 0.94 0.94];   C.panel = [1 1 1];          C.field = [1 1 1];
    C.text = [0.10 0.10 0.10]; C.muted = [0.40 0.40 0.40]; C.line = [0.75 0.75 0.75];
    C.btn = [0.96 0.96 0.96];  C.btntext = [0.10 0.10 0.10];
    C.go = [0.13 0.55 0.13];   C.gotext = [1 1 1];
    C.busy = [0.80 0.80 0.80]; C.busytext = [0.30 0.30 0.30];
    C.swon = [0.05 0.45 0.10]; C.swontext = [1 1 1];        C.swoff = [0.86 0.86 0.86]; C.swofftext = [0.35 0.35 0.35];
    C.now = [1.00 0.93 0.55];  C.facts = [0.88 0.93 1.00];  C.demo = [1.00 0.85 0.40];
    C.ok = [0.00 0.55 0.00];   C.check = [0.80 0.40 0.00];  C.bad = [0.85 0.00 0.00];
    C.none = [0.62 0.62 0.62];
    C.axbg = [1 1 1];          C.axfg = [0.15 0.15 0.15];   C.grid = [0.15 0.15 0.15];
    C.model = [0.25 0.25 0.25];
    C.curves = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19; 0.49 0.18 0.56; ...
                0.93 0.69 0.13; 0.30 0.75 0.93; 0.64 0.08 0.18; 0.20 0.20 0.20];
else
    C.mode = 'dark';
    C.bg = [0.11 0.12 0.14];   C.panel = [0.16 0.17 0.20];  C.field = [0.21 0.22 0.26];
    C.text = [0.92 0.92 0.92]; C.muted = [0.62 0.64 0.68];  C.line = [0.36 0.38 0.42];
    C.btn = [0.26 0.28 0.32];  C.btntext = [0.94 0.94 0.94];
    C.go = [0.20 0.68 0.28];   C.gotext = [0.03 0.08 0.03];
    C.busy = [0.30 0.31 0.34]; C.busytext = [0.70 0.70 0.70];
    C.swon = [0.30 0.80 0.38]; C.swontext = [0.02 0.08 0.02]; C.swoff = [0.27 0.28 0.31]; C.swofftext = [0.72 0.72 0.74];
    C.now = [0.45 0.38 0.05];  C.facts = [0.15 0.24 0.38];  C.demo = [0.60 0.42 0.00];
    C.ok = [0.35 0.85 0.40];   C.check = [1.00 0.70 0.20];  C.bad = [1.00 0.50 0.46];
    C.none = [0.50 0.52 0.56];
    C.axbg = [0.13 0.14 0.16]; C.axfg = [0.88 0.88 0.88];   C.grid = [0.80 0.80 0.80];
    C.model = [0.80 0.80 0.80];
    C.curves = [0.35 0.70 1.00; 1.00 0.60 0.30; 0.55 0.88 0.35; 0.82 0.58 1.00; ...
                1.00 0.85 0.30; 0.40 0.90 0.90; 1.00 0.50 0.60; 0.90 0.90 0.90];
end
end
