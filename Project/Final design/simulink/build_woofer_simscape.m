%% Woofer box (Task 1) in Simscape: the same circuit as ltspice/task1/Woofer_Vented_L160.asc
%  matlab -batch build_woofer_simscape      (builds Woofer_Vented_L160_simscape.slx, sweeps it, plots)
%
%  Same impedance analogy as LTspice, three loops coupled by controlled sources:
%    electrical:  e_g -> Re -> Le -> [sense i] -> Bl*u (CCVS "HBLu")
%    mechanical:  Bl*i (CCVS "HBLi") -> Mmd -> Rms -> Cms -> [sense u] -> S_D*p (VCVS "ESdPd")
%    acoustical:  S_D*u (CCCS "FSdud") -> Ma1f -> [U_D] -> Ral || ([U_box] Cab) || ([U_P] Map + Rap)
%  In Simscape the controlled sources carry their own sensing branch, so the 0 V ammeters Vd1/Vd2 of
%  the LTspice file are inside HBLi/HBLu/FSdud. Current sensors give U_D, U_P, U_box and the coil current.
%  The frequency response comes from linmod (linearised state space), evaluated at s = j*w.

set(groot, 'defaultFigureVisible', 'off');
here = fileparts(mfilename('fullpath')); cd(here);
mdl = 'Woofer_Vented_L160_simscape';

% ---- values: identical to Woofer_Vented_L160.asc (box_model.fit(), one vent L = 160 mm)
P = struct('Re', 5.7, 'Le', 1.498e-3, 'Bl', 8.283, 'Mmd', 36.68e-3, 'Rms', 0.6085, 'Cms', 1.1735e-3, ...
           'Sd', 0.034967, 'Ma1f', 3.084, 'Ral', 66114, 'Cab', 0.621e-6, 'Map', 67.44, 'Rap', 348.9, ...
           'rho', 1.2041, 'aD', 0.1055, 'aP', 0.0325);

% ---- build
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl); load_system('fl_lib'); load_system('nesl_utility');
E = 'fl_lib/Electrical/Electrical Elements/'; S = sprintf('fl_lib/Electrical/Electrical Sources/');
lib = struct('R', [E 'Resistor'], 'L', [E 'Inductor'], 'C', [E 'Capacitor'], 'G', [E 'Electrical Reference'], ...
    'CCVS', sprintf([S 'Current-Controlled\nVoltage Source']), 'CCCS', sprintf([S 'Current-Controlled\nCurrent Source']), ...
    'VCVS', sprintf([S 'Voltage-Controlled\nVoltage Source']), 'V', sprintf([S 'Controlled Voltage\nSource']), ...
    'Isens', 'fl_lib/Electrical/Electrical Sensors/Current Sensor', ...
    'SPS', sprintf('nesl_utility/Simulink-PS\nConverter'), 'PSS', sprintf('nesl_utility/PS-Simulink\nConverter'), ...
    'SC', sprintf('nesl_utility/Solver\nConfiguration'));
B = @(name, kind, x, y, w, h, varargin) add_block(lib.(kind), [mdl '/' name], 'Position', [x y x+w y+h], varargin{:});
L = @(p1, p2) add_line(mdl, p1, p2, 'autorouting', 'smart');
ph = @(name) get_param([mdl '/' name], 'PortHandles');
annot = @(x, y, txt) set(Simulink.Annotation([mdl '/' txt]), 'Position', [x y x+10 y+10], 'FontSize', 11);

% electrical loop
add_block('simulink/Sources/In1', [mdl '/eg'], 'Position', [20 113 50 127]);
B('S-PS eg', 'SPS', 80, 110, 30, 20, 'Unit', 'V');
B('Veg', 'V', 140, 100, 40, 60);
B('Re', 'R', 230, 40, 50, 20, 'R', num2str(P.Re));
B('Le', 'L', 320, 40, 50, 20, 'l', num2str(P.Le), 'g', '0');
B('i coil', 'Isens', 410, 35, 40, 30);
B('HBLu', 'CCVS', 480, 100, 50, 60, 'K', num2str(P.Bl));          % sense branch in the MECHANICAL loop
B('Gnd e', 'G', 140, 210, 40, 30);
% mechanical loop
B('HBLi', 'CCVS', 620, 100, 50, 60, 'K', num2str(P.Bl));          % sense branch in the ELECTRICAL loop
B('Mmd', 'L', 720, 40, 50, 20, 'l', num2str(P.Mmd), 'g', '0');
B('Rms', 'R', 810, 40, 50, 20, 'R', num2str(P.Rms));
B('Cms', 'C', 900, 40, 50, 20, 'c', num2str(P.Cms), 'r', '0');
B('FSdud', 'CCCS', 1000, 100, 50, 60, 'K', num2str(P.Sd));       % sense branch = cone velocity u
B('ESdPd', 'VCVS', 1090, 100, 50, 60, 'K', num2str(P.Sd));       % output in the mechanical loop
B('Gnd m', 'G', 700, 210, 40, 30);
% acoustical loop
B('Ma1f', 'L', 1200, 40, 50, 20, 'l', num2str(P.Ma1f), 'g', '0');
B('U_D', 'Isens', 1290, 35, 40, 30);
B('Ral', 'R', 1380, 110, 20, 50, 'R', num2str(P.Ral), 'Orientation', 'down');
B('U_box', 'Isens', 1450, 80, 30, 40, 'Orientation', 'down');
B('Cab', 'C', 1450, 150, 20, 50, 'c', num2str(P.Cab), 'r', '0', 'Orientation', 'down');
B('U_P', 'Isens', 1540, 80, 30, 40, 'Orientation', 'down');
B('Map', 'L', 1540, 150, 20, 50, 'l', num2str(P.Map), 'r', num2str(P.Rap), 'g', '0', 'Orientation', 'down');
B('Gnd a', 'G', 1450, 260, 40, 30);
B('Solver', 'SC', 20, 200, 50, 30);
% outputs
outs = {'i coil', 'U_D', 'U_P', 'U_box'};
for k = 1:numel(outs)
    B(['PS-S ' outs{k}], 'PSS', 1650, 330 + 50*k, 30, 20, 'Unit', 'A');
    add_block('simulink/Sinks/Out1', [mdl '/' strrep(outs{k}, ' ', '_') '_out'], 'Position', [1720 333+50*k 1750 347+50*k]);
end

% wiring. Port order (Simscape): R/L/C LConn+ RConn-; sensors LConn+ RConn(1)=I RConn(2)-;
% controlled sources: LConn1 sense+, RConn1 sense-, LConn2 output+, RConn2 output-.
% Controlled Voltage Source: LConn=+, RConn1=signal input, RConn2=-.
p = ph('eg'); L(p.Outport, ph('S-PS eg').Inport);
L(ph('S-PS eg').RConn, ph('Veg').RConn(1));
v = ph('Veg'); L(v.LConn, ph('Re').LConn); L(ph('Re').RConn, ph('Le').LConn); L(ph('Le').RConn, ph('i coil').LConn);
s = ph('HBLi'); L(ph('i coil').RConn(2), s.LConn(1));                           % i flows into HBLi's sense +
h = ph('HBLu'); L(s.RConn(1), h.LConn(2)); L(h.RConn(2), v.RConn(2)); L(v.RConn(2), ph('Gnd e').LConn);
% mechanical: HBLi output drives Mmd - Rms - Cms - sense(HBLu) - sense(FSdud) - ESdPd output
L(s.LConn(2), ph('Mmd').LConn); L(ph('Mmd').RConn, ph('Rms').LConn); L(ph('Rms').RConn, ph('Cms').LConn);
L(ph('Cms').RConn, h.LConn(1));
f = ph('FSdud'); L(h.RConn(1), f.LConn(1));
e = ph('ESdPd'); L(f.RConn(1), e.LConn(2)); L(e.RConn(2), s.RConn(2)); L(s.RConn(2), ph('Gnd m').LConn);
% acoustical: FSdud output pushes U_D = S_D*u round the loop
L(f.LConn(2), ph('Ma1f').LConn); L(ph('Ma1f').RConn, ph('U_D').LConn);
top = ph('U_D').RConn(2); gnd = ph('Gnd a').LConn;
L(top, ph('Ral').LConn); L(ph('Ral').RConn, gnd);
L(top, ph('U_box').LConn); L(ph('U_box').RConn(2), ph('Cab').LConn); L(ph('Cab').RConn, gnd);
L(top, ph('U_P').LConn); L(ph('U_P').RConn(2), ph('Map').LConn); L(ph('Map').RConn, gnd);
L(f.RConn(2), gnd);
L(e.LConn(1), f.LConn(2)); L(e.RConn(1), gnd);                                 % ESdPd senses the pressure on the cone
L(ph('Solver').RConn, v.RConn(2));
for k = 1:numel(outs)
    L(ph(outs{k}).RConn(1), ph(['PS-S ' outs{k}]).LConn);
    L(ph(['PS-S ' outs{k}]).Outport, ph([strrep(outs{k}, ' ', '_') '_out']).Inport);
end
annot(140, 0, 'ELECTRICAL  (V = volts, I = amps)');
annot(620, 0, 'MECHANICAL  (V = force, I = velocity)');
annot(1200, 0, 'ACOUSTICAL  (V = pressure, I = volume velocity)');
annot(1200, 310, 'outputs: coil current i, cone flow U_D, vent flow U_P, box flow U_box');
add_block('simulink/Signal Routing/Mux',[mdl '/Flows and current'],'Position',[1820 380 1825 550],'Inputs','4');
add_block('simulink/Sinks/Scope',[mdl '/Inspect flows and current'],'Position',[1900 430 1970 490]);
for k=1:numel(outs)
    add_line(mdl,[strrep(['PS-S ' outs{k}], '/', '//') '/1'],['Flows and current/' num2str(k)],'autorouting','on');
end
add_line(mdl,'Flows and current/1','Inspect flows and current/1');
set_param(mdl, 'Solver', 'ode23t', 'StopTime', '0.2', ...
    'LoadExternalInput','on','ExternalInput',"[(0:1e-4:0.2)' sin(2*pi*25*(0:1e-4:0.2)')]");
save_system(mdl);

% ---- sweep: linearise and evaluate at j*w
[A, Bm, Cm, Dm] = linmod(mdl);
f = logspace(log10(5), log10(500), 600); w = 2*pi*f;
H = zeros(size(Cm, 1), numel(f));
for k = 1:numel(f), H(:, k) = Cm * ((1j*w(k)*eye(size(A)) - A) \ Bm) + Dm; end
i_coil = H(1, :); UD = H(2, :); UP = H(3, :); Ubox = H(4, :);
ZE = 1 ./ i_coil;

% ---- the same circuit by hand (what LTspice solves), to check the Simscape wiring
jw = 1j*w;
vent = jw*P.Map + P.Rap; Zbox = 1 ./ (jw*P.Cab + 1/P.Ral + 1./vent);
Zm = jw*P.Mmd + P.Rms + 1./(jw*P.Cms) + P.Sd^2*(jw*P.Ma1f + Zbox);
ZEr = P.Re + jw*P.Le + P.Bl^2 ./ Zm; UDr = P.Sd*P.Bl ./ (ZEr .* Zm);
err = @(a, b) max(abs(20*log10(abs(a ./ b))));
fprintf('Simscape vs the circuit equations, 5-500 Hz: Z_E %.2e dB, U_D %.2e dB, U_P %.2e dB\n', ...
    err(ZE, ZEr), err(UD, UDr), err(UP, Zbox.*UDr./vent));

assert(max(abs(ZE./ZEr-1)) < 1e-5, 'Impedance mismatch');
assert(max(abs(UD./UDr-1)) < 1e-5, 'Cone flow mismatch');
assert(max(abs(UP./(Zbox.*UDr./vent)-1)) < 1e-5, 'Vent flow mismatch');
simout=sim(mdl); assert(~isempty(simout.tout),'Time simulation produced no samples');
save('woofer_validation.mat','f','H','P','A','Bm','Cm','Dm');
ff = @(U) 20*log10(abs(jw*P.rho.*U/(2*pi)) / 20e-6);           % far field, 1 m, half space, 1 V
fb = 1/(2*pi*sqrt(P.Map*P.Cab));
spl=ff(Ubox); ref = mean(spl(f >= 150 & f <= 300)); f3 = f(find(ff(Ubox) >= ref - 3, 1));
fprintf('f_B %.1f Hz, f_3 %.1f Hz\n', fb, f3);

% ---- figure: Simscape result against Lab D
csv = @(n) readmatrix(fullfile(here, '..', 'data', 'csv', [n '.csv']));
Zm_ = csv('Z_vent_L160'); NFc = csv('NF_cone_L160'); NFv = csv('NF_vent_L160');
fig = figure('Position', [0 0 1200 700]); try, fig.Theme = 'light'; catch, end
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact');
ax = nexttile(tl, [1 2]); hold(ax, 'on');
semilogx(ax, f, ff(UD), 'Color', [0.12 0.47 0.71], 'LineWidth', 1.4);
semilogx(ax, f, ff(UP), 'Color', [0.84 0.15 0.16], 'LineWidth', 1.4);
semilogx(ax, f, ff(Ubox), 'k', 'LineWidth', 2.2);
xline(ax, fb, ':', sprintf('f_B = %.1f Hz', fb)); xline(ax, f3, ':', sprintf('f_3 = %.0f Hz', f3));
set(ax, 'XScale', 'log'); xlim(ax, [5 500]); ylim(ax, [50 95]); grid(ax, 'on');
ylabel(ax, 'SPL at 1 m, 1 V (dB re 20 \muPa)'); legend(ax, 'cone U_D', 'vent U_P', 'total U_{box}', 'Location', 'southeast');
title(ax, 'Simscape: woofer in the 88.1 L box, one vent L = 160 mm (far field, half space)');
ax = nexttile(tl); hold(ax, 'on');
semilogx(ax, Zm_(:,1), abs(Zm_(:,2) + 1j*Zm_(:,3)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2);
semilogx(ax, f, abs(ZE), 'k--', 'LineWidth', 1.5);
set(ax, 'XScale', 'log'); xlim(ax, [5 500]); ylim(ax, [0 60]); grid(ax, 'on');
ylabel(ax, '|Z_E| (\Omega)'); xlabel(ax, 'Frequency (Hz)'); legend(ax, 'Lab D', 'Simscape'); title(ax, 'Input impedance');
ax = nexttile(tl); hold(ax, 'on');
semilogx(ax, NFc(:,1), 20*log10(abs(NFc(:,2) + 1j*NFc(:,3))), 'Color', [0.55 0.73 0.88]);
semilogx(ax, NFv(:,1), 20*log10(abs(NFv(:,2) + 1j*NFv(:,3))), 'Color', [0.94 0.6 0.6]);
semilogx(ax, f, 20*log10(abs(jw*P.rho.*UD/(pi*P.aD))), 'Color', [0.12 0.47 0.71], 'LineStyle', '--', 'LineWidth', 1.6);
semilogx(ax, f, 20*log10(abs(jw*P.rho.*UP/(pi*P.aP))), 'Color', [0.84 0.15 0.16], 'LineStyle', '--', 'LineWidth', 1.6);
set(ax, 'XScale', 'log'); xlim(ax, [5 500]); ylim(ax, [-30 25]); grid(ax, 'on');
ylabel(ax, '|p/V| (dB re 1 Pa/V)'); xlabel(ax, 'Frequency (Hz)');
legend(ax, 'cone, Lab D', 'vent, Lab D', 'cone, Simscape', 'vent, Simscape', 'Location', 'southwest'); title(ax, 'Near field');
if ~isfolder(fullfile(here,'figures')), mkdir(fullfile(here,'figures')); end
exportgraphics(fig, fullfile(here, 'figures', 'woofer_simscape_response.png'), 'Resolution', 150);
print(['-s' mdl], '-dpng', '-r110', fullfile(here, 'figures', 'woofer_simscape_model.png'));
close_system(mdl, 0);
disp('wrote Woofer_Vented_L160_simscape.slx and figures/woofer_simscape_*.png');
