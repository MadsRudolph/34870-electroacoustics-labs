function p = extract_ltspice_params(d,datadir)

%==============================================================
% LTSPICE SPEAKER PARAMETER EXTRACTION
%
% Output:
%
% Re
% Le
% HBLu
% HBLi
% Mmd
% Rms
% Cms
% FSdud
% ESdPd
% Ma1f
% Mab
% Cab
% Ral
%
%==============================================================

%% -------------------------------------------------------------
% PATHS
%% -------------------------------------------------------------

here = fileparts(mfilename('fullpath'));

if nargin < 1
    d = labD_dims();
end

if nargin < 2
    datadir = fullfile(here,'..','data');
end

ld = @(tag) load( ...
    fullfile(datadir,['labD_' tag '.mat']) );

%% -------------------------------------------------------------
% AIR CONSTANTS
%% -------------------------------------------------------------

T = d.T_celsius;

if isnan(T)
    T = 20;
end

c = 331.3 * sqrt(1 + T/273.15);

rho = 1.2041 * 293.15 /(273.15 + T);

%% -------------------------------------------------------------
% LOAD DATA
%% -------------------------------------------------------------

free   = ld('woofer_free');
closed = ld('woofer_closed');

%% -------------------------------------------------------------
% IMPEDANCE ANALYSIS
%% -------------------------------------------------------------

tsf = ts_from_Z( ...
    free.fn,...
    free.Z,...
    d.RE_woofer);

tsc = ts_from_Z( ...
    closed.fn,...
    closed.Z,...
    d.RE_woofer);

%% -------------------------------------------------------------
% BASIC PARAMETERS
%% -------------------------------------------------------------

Fs  = tsf.f0;
Qms = tsf.QM;
Qes = tsf.QE;

Re  = d.RE_woofer;

%% -------------------------------------------------------------
% LE ESTIMATION
%% -------------------------------------------------------------

hf = free.fn > 1000;

if nnz(hf) > 10

    w = 2*pi*free.fn(hf);

    LeVec = sqrt( ...
        max(abs(free.Z(hf)).^2-Re^2,0)) ./ w;

    Le = median(LeVec);

else

    Le = NaN;

end

%% -------------------------------------------------------------
% BOX VOLUME
%% -------------------------------------------------------------

VB = prod(d.box_inner);

alpha = (tsc.f0/Fs)^2 - 1;

Vas = VB * alpha;

%% -------------------------------------------------------------
% DIAPHRAGM AREA
%% -------------------------------------------------------------

Sd = pi*(d.cone_diam/2)^2;

%% -------------------------------------------------------------
% COMPLIANCES
%% -------------------------------------------------------------

Cas = Vas/(rho*c^2);

Cms = Cas/(Sd^2);

Cab = VB/(rho*c^2);

%% -------------------------------------------------------------
% MOVING MASS
%% -------------------------------------------------------------

ws = 2*pi*Fs;

Mmd = 1/(ws^2*Cms);

%% -------------------------------------------------------------
% MECHANICAL RESISTANCE
%% -------------------------------------------------------------

Rms = ws*Mmd/Qms;

%% -------------------------------------------------------------
% FORCE FACTOR
%% -------------------------------------------------------------

Bl = sqrt( ...
    ws*Re*Mmd/Qes );

%% -------------------------------------------------------------
% LTSPICE TRANSFORMERS
%% -------------------------------------------------------------

FSdud = Sd;

ESdPd = Sd;

%% -------------------------------------------------------------
% FRONT AIR MASS
%% -------------------------------------------------------------
%
% Radiation mass of circular piston
%
%% -------------------------------------------------------------

a = d.cone_diam/2;

Ma1f = 8*rho/(3*pi^2*a);

%% -------------------------------------------------------------
% RADIATION RESISTANCE
%% -------------------------------------------------------------

Ral = rho*c/Sd;

%% -------------------------------------------------------------
% PORT MASS
%% -------------------------------------------------------------

Mab = 0;

if isfield(d,'vents')

    if ~isempty(d.vents)

        aP = d.vent_radius;

        SP = pi*aP^2;

        L  = d.vents{1,2};

        N  = d.vents{1,3};

        Mab = rho * ...
            (L + 1.46*aP) / ...
            (N*SP);

    end

end

%% -------------------------------------------------------------
% NON-LINEAR TERMS
%% -------------------------------------------------------------
%
% Cannot be determined from small-signal
% impedance measurements.
%
%% -------------------------------------------------------------

HBLu = 0;
HBLi = 0;

%% -------------------------------------------------------------
% OUTPUT STRUCTURE
%% -------------------------------------------------------------

p.Re    = Re;
p.Le    = Le;

p.HBLu  = HBLu;
p.HBLi  = HBLi;

p.Mmd   = Mmd;
p.Rms   = Rms;
p.Cms   = Cms;

p.FSdud = FSdud;
p.ESdPd = ESdPd;

p.Ma1f  = Ma1f;
p.Mab   = Mab;

p.Cab   = Cab;
p.Ral   = Ral;

p.Bl    = Bl;
p.Fs    = Fs;
p.Qms   = Qms;
p.Qes   = Qes;
p.Vas   = Vas;

%% -------------------------------------------------------------
% PRINT RESULTS
%% -------------------------------------------------------------

fprintf('\n');
fprintf('=====================================\n');
fprintf('LTSPICE DRIVER PARAMETERS\n');
fprintf('=====================================\n');

fprintf('Re     = %.6g\n',p.Re);
fprintf('Le     = %.6g\n',p.Le);

fprintf('HBLu   = %.6g\n',p.HBLu);
fprintf('HBLi   = %.6g\n',p.HBLi);

fprintf('Mmd    = %.6g\n',p.Mmd);
fprintf('Rms    = %.6g\n',p.Rms);
fprintf('Cms    = %.6g\n',p.Cms);

fprintf('FSdud  = %.6g\n',p.FSdud);
fprintf('ESdPd  = %.6g\n',p.ESdPd);

fprintf('Ma1f   = %.6g\n',p.Ma1f);
fprintf('Mab    = %.6g\n',p.Mab);

fprintf('Cab    = %.6g\n',p.Cab);
fprintf('Ral    = %.6g\n',p.Ral);

fprintf('\n');
fprintf('Bl     = %.6g\n',Bl);
fprintf('Fs     = %.3f Hz\n',Fs);
fprintf('Vas    = %.3f L\n',1000*Vas);

fprintf('=====================================\n');

end