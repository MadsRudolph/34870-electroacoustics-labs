function varargout = lab_demo(station, st, S, opt, varargin)
% LAB_DEMO  Stand-ins for the two course routines, for labgui's demo mode (rehearsal at home).
%
%   fun = @(varargin) lab_demo('chamber', st, S, opt, varargin{:})   % = meas_mag_spec2_SoundCard_LabE
%   fun = @(varargin) lab_demo('zinf',    st, S, opt, varargin{:})   % = meas_mag_spec2_LabD
%
%   They return what the real routines return, "measured" from the expected curves:
%   level -6 dB, a random latency per run, a little noise. The MiniDSP gains in S act like
%   the real knobs: Out 1 = -10.3 dB balances the woofer (as on 10-Nov), anything else
%   unbalances it by the difference. Board impedance from the model, woofer and near
%   field from the Lab D data at S.vent_mm (160 mm if Lab D has no data at that length).
%
%   opt.speed   real seconds per simulated second (0 = no waiting; 0.04 = a 4-minute
%               run takes 10 s)
%   opt.fault   'none' | 'placement' (ripple: P/S shape BAD) | 'switch' (last state not
%               switched in time) | 'noumik' | 'nobeeps' | 'clip' | 'noNI'  (rehearse errors)
%   opt.wait    function handle called as wait(t_sim) while "measuring", returns true to
%               cancel (labgui uses it to update the clock and for the Cancel button)

if ~isfield(opt, 'speed'), opt.speed = 0; end
if ~isfield(opt, 'fault'), opt.fault = 'none'; end
if ~isfield(opt, 'wait'), opt.wait = []; end
L = labpaths();
switch station
case 'chamber'
    [~, ~, ~, fres, Nav, UmikSN, ~, Nmeas] = varargin{:};
    switch opt.fault
        case 'noumik'
            error('labdemo:noumik', ['Microphone ID: NaN;  Line In ID: 1;  Speaker ID: 3\n' ...
                'Error using audiorecorder: DeviceID NaN is not a valid input device (no device named Umik).']);
        case 'nobeeps'
            error('MATLAB:audiovideo:audioread:fileNotFound', 'The filename specified was not found in the MATLAB path: beeps.wav');
    end
    if ~any(contains(UmikSN, {'0329', '0332', '0335'}))
        error('No correction available for this microphone. Check S/N.');
    end
    [T, hdr] = readcsv(fullfile(L.model, ifelse(st(1).angle == 30, 'expected_off30.csv', 'expected_on.csv')));
    fn = T(:,1); col = @(s) T(:, strcmp(hdr, [s '_re'])) + 1j*T(:, strcmp(hdr, [s '_im']));
    W = col('woofer');                           % all = W + midtw, flipW = -W + midtw, flipT = W + mid - tw
    gw = 10^((S.out1_gain - (-10.3))/20);        % -10.3 dB = what balanced the lab's amplifier
    g2 = 10^(S.out2_gain/20);
    H = zeros(numel(fn), Nmeas);
    for k = 1:Nmeas
        s = st(min(k, numel(st)));
        Hk = col(s.model);
        if strcmp(s.dsp, 'on')                    % the Out gains only act with the MiniDSP on
            sw = 0;
            if any(strcmp(s.model, {'woofer', 'all', 'flipT'})), sw = 1; end
            if strcmp(s.model, 'flipW'), sw = -1; end
            Hk = sw*gw*W + g2*(Hk - sw*W);
        end
        if strcmp(opt.fault, 'placement')
            Hk = Hk .* (1 + 0.6*sin(2*pi*1.3*log2(fn/100)));
        end
        H(:,k) = Hk;
    end
    if strcmp(opt.fault, 'switch') && Nmeas > 1, H(:,end) = H(:,end-1); end
    tau = 0.047 + 1e-3*rand;
    specn = zeros(numel(fn), 2, Nmeas);
    for k = 1:Nmeas
        V = 0.05*exp(1j*2*pi*rand(numel(fn), 1));
        noise = 1 + 0.015*(randn(numel(fn), 1) + 1j*randn(numel(fn), 1));
        specn(:,:,k) = [V, V .* 0.5 .* H(:,k) .* noise .* exp(-1j*2*pi*fn*tau)];
    end
    pk = 0.25; if strcmp(opt.fault, 'clip'), pk = 0.99; end
    ch = repmat([0.2 pk] .* ones(100, 2), [1 1 Nmeas]);
    f = (0:9)'; spec = zeros(10, 2, Nmeas);
    if Nmeas == 1, specn = specn(:,:,1); spec = spec(:,:,1); ch = ch(:,:,1); end
    secs = Nmeas*(Nav + 1)/fres + (Nmeas - 1)*30.2 + 3;
case 'zinf'
    [~, ~, ~, fres, Nav] = varargin{:};
    if strcmp(opt.fault, 'noNI')
        error('daq:Session:noDevice', 'NI-DAQmx: Device identifier Dev4 is invalid (no data acquisition device found).');
    end
    model = st(1).model;
    vent = S.vent_mm;
    switch model
    case {'board', 'board_mid', 'board_tw'}
        [T, hdr] = readcsv(fullfile(L.model, 'expected_zi.csv'));
        c = struct('board', 'Zboth', 'board_mid', 'Zmid', 'board_tw', 'Ztw');
        fn = T(:,1); X = T(:, strcmp(hdr, [c.(model) '_re'])) + 1j*T(:, strcmp(hdr, [c.(model) '_im']));
    case 'woofer'
        f = fullfile(L.labDdata, sprintf('labD_vent_L%d.mat', vent));
        if ~exist(f, 'file'), f = fullfile(L.labDdata, 'labD_vent_L160.mat'); end
        W = load(f); fn = W.fn(:); X = W.Z(:);
    otherwise
        f = fullfile(L.labDdata, sprintf('labD_%s_L%d.mat', model, vent));
        if ~exist(f, 'file'), f = fullfile(L.labDdata, sprintf('labD_%s_L160.mat', model)); end
        N = load(f); fn = N.fn(:); X = N.H(:) * S.NexusVperPa;
    end
    nf = startsWith(model, 'nf');
    Va = 0.2*exp(1j*2*pi*rand(size(fn)));
    if ~strcmp(model, 'woofer')       % (noise on the flat impedance minimum would move the fb estimate)
        X = X .* (1 + 0.005*(randn(size(fn)) + 1j*randn(size(fn))));
    end
    if nf, V1 = Va .* X; else, V1 = Va .* X ./ (S.R_series + X); end
    specn = [Va, V1]; f = (0:9)'; spec = zeros(10, 2);
    a = 0.3; if strcmp(opt.fault, 'clip'), a = 10; end
    ch = [a*sin((1:4800)'/50), 0.1*sin((1:4800)'/50)];
    secs = (Nav + 1)/fres + 3;
otherwise
    error('lab_demo: station must be chamber or zinf');
end

% ---- take (a fraction of) the real time, so the GUI clock and the beeps can be rehearsed
if opt.speed > 0 || ~isempty(opt.wait)
    t0 = tic;
    while true
        tsim = toc(t0) / max(opt.speed, eps);
        if opt.speed == 0, tsim = secs; end
        if ~isempty(opt.wait) && opt.wait(min(tsim, secs))
            error('labgui:cancel', 'Cancelled by the user (demo): nothing saved.');
        end
        if tsim >= secs, break; end
        pause(0.1);
    end
end
varargout = {fn, specn, f, spec, ch};
end

function [T, hdr] = readcsv(f)
T = readmatrix(f, 'NumHeaderLines', 1);
fid = fopen(f); hdr = strsplit(strtrim(fgetl(fid)), ','); fclose(fid);
end

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end
