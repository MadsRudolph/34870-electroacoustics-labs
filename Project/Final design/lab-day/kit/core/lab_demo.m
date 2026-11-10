function [fn, specn, f, spec, ch] = lab_demo(st, S, D, Nav)
% LAB_DEMO  Stand-in for the two course routines: "measures" the expected curves.
%   No hardware. Same outputs as meas_mag_spec2_SoundCard_LabE (chamber steps) and
%   meas_mag_spec2_LabD (Zi/Nfield steps): the model curve of each step, a level shift
%   (-6 dB), one random latency per run and a little noise. It waits like the real
%   thing, only faster (D.speed), so the progress display can be rehearsed.
%
%   D.speed     how many times faster than real (default 15; a run S then takes 15 s)
%   D.fault     what goes wrong (default 'none'):
%                 'woofer loud'   the channels balance at Out 1 = -12.6 dB instead of -10.3
%                                 (set Out 1 to -12.6 in Settings and the run turns OK)
%                 'placement'     the box/mic is not where it was in Lab E (ripple)
%                 'not switched'  state 2 was not switched in time (= state 1 again)
%                 'quiet'         almost no UMIK signal      'clipping'  near full scale
%                 'dc offset'     Zi: AI0 on 9.4 V DC, reading half the voltage (Lab D)
%                 'no umik'       the course routine fails: UMIK not found
%                 'no beeps'      the course routine fails: beeps.wav not found
%   D.balanced  Out 1 gain at which woofer and mid+tweeter are level (default -10.3)

if ~isfield(D, 'speed') || isempty(D.speed), D.speed = 15; end
if ~isfield(D, 'fault') || isempty(D.fault), D.fault = 'none'; end
if ~isfield(D, 'balanced') || isempty(D.balanced), D.balanced = -10.3; end
if strcmp(D.fault, 'woofer loud'), D.balanced = -12.6; end
chamber = strcmp(st(1).station, 'chamber');

if chamber
    switch D.fault
    case 'no umik'
        pause(0.3);
        error('MATLAB:audiovideo:audiorecorder:invalidDeviceID', ...
            'Demo fault: invalid audio device ID (NaN): the UMIK was not found by audiodevinfo.');
    case 'no beeps'
        error('MATLAB:audiovideo:audioread:fileNotFound', 'The filename specified was not found in the MATLAB path.');
    end
end

T = lab_timeline(st, Nav);
t0 = tic; total = T.total / D.speed;
while toc(t0) < total, pause(min(0.05, max(total - toc(t0), 0.001))); end

f = (0:9)'; n = numel(st);
if chamber
    tau = 0.047 + 1e-3*rand;                      % one latency per run, as with the real USB clocks
    g = 10^((S.out1_gain - D.balanced)/20);       % woofer level re balanced
    for k = 1:n
        M = lab_model('chamber_raw', st(k).model, st(k).angle);
        if k == 1, fn = M.f(:); Nf = numel(fn); specn = zeros(Nf, 2, n); end
        H = M.H;
        if strcmp(st(k).dsp, 'on')
            W = lab_model('chamber_raw', 'woofer', st(k).angle);
            switch st(k).model
                case 'woofer',          H = H * g;
                case {'all', 'flipT'},  H = H + (g - 1)*W.H;
                case 'flipW',           H = H - (g - 1)*W.H;
            end
        end
        if strcmp(D.fault, 'placement'), H = H .* (1 + 0.8*sin(2*pi*log2(fn))); end
        Hk(:,k) = H; %#ok<AGROW>
    end
    if strcmp(D.fault, 'not switched') && n > 1, Hk(:,2) = Hk(:,1); end
    for k = 1:n
        V = 0.05*exp(1j*2*pi*rand(Nf,1));
        P = V .* 0.5 .* Hk(:,k) .* exp(-1j*2*pi*fn*tau);
        P = P + 1e-3*max(abs(P)) * (randn(Nf,1) + 1j*randn(Nf,1))/sqrt(2);
        specn(:,:,k) = [V, P];
    end
    a = 0.1; if strcmp(D.fault, 'quiet'), a = 0.004; elseif strcmp(D.fault, 'clipping'), a = 0.99; end
    t = (0:4799)'/48000;
    ch = repmat([0.2*sin(2*pi*500*t), a*sin(2*pi*500*t)], 1, 1, n);
    spec = zeros(10, 2, n);
    if n == 1, specn = specn(:,:,1); spec = spec(:,:,1); ch = ch(:,:,1); end
else
    L = labpaths;
    kind = st.model; nf = startsWith(kind, 'nf');
    vent = S.vent_mm;
    switch kind
    case {'board', 'board_mid', 'board_tw'}
        M = lab_model('zinf_raw', kind, 0); fn = M.f(:); X = M.H;
    case 'woofer'
        file = fullfile(L.labDdata, sprintf('labD_vent_L%d.mat', vent));
        if ~exist(file, 'file'), file = fullfile(L.labDdata, 'labD_vent_L160.mat'); end
        R0 = load(file); fn = R0.fn(:); X = R0.Z(:);
    otherwise
        file = fullfile(L.labDdata, sprintf('labD_nf_%s_L%d.mat', erase(kind, 'nf_'), vent));
        if ~exist(file, 'file'), file = fullfile(L.labDdata, sprintf('labD_nf_%s_L160.mat', erase(kind, 'nf_'))); end
        R0 = load(file); fn = R0.fn(:); X = R0.H(:) * S.NexusVperPa;
    end
    Va = 0.2*exp(1j*2*pi*rand(size(fn)));
    if nf, V1 = Va .* X; else, V1 = Va .* X ./ (S.R_series + X); end
    V1 = V1 + 1e-3*median(abs(V1)) * (randn(size(fn)) + 1j*randn(size(fn)))/sqrt(2);
    k = 1; dc = 0;
    if strcmp(D.fault, 'dc offset'), k = 2; dc = 9.4; end
    specn = [Va/k, V1]; spec = zeros(10, 2);
    t = (1:4800)'/50;
    ch = [dc + 0.3*sin(t)/k, 0.1*sin(t)];
    if strcmp(D.fault, 'clipping'), ch(1:200, 2) = 9.95; end
end
end
