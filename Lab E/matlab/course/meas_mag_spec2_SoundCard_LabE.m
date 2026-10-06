function  [fn,specn,f,spec,ch]=meas_mag_spec2_SoundCard_LabE(f1,f2,n_oct,fres,Nav,UmikSN,IncAngle,Nmeas)
% [fn,specn,f,spec,ch]=meas_mag_spec2_SoundCard_LabE(f1,f2,n_oct,fres,Nav,UmikSN,IncAngle,Nmeas)
% Data acquisition routine. This function measures the spectrum of two input channels.
% when driven with a multitone signal. This version uses a regular PC sound card.
% The function produces verification plots with the readings from the two channels. 
%
% Preparation (consult teacher/TA):
%    - Check that play and record device IDs are detected. 
%    - Check that the calibration file corresponds to the correct UMIK s/n.
%    - Computer play volume needs to be set to a convenient output level (max +/- 1)
%
% Output parameters:
% fn    :  vector of signal frequencies 
% specn :  spectrum for fn. Matrix with indexes: (values, ch. 1/2, meas. up to Nmeas) 
% f     :  full frequency vector
% spec  :  full spectrum. Matrix with indexes: (values, ch. 1/2, meas. up to Nmeas)
% ch    :  averaged time signals. Matrix with indexes: (values, ch. 1/2, meas. up to Nmeas)
%
% Input parameters:
% f1        : lower measurement frequency
% f2        : upper measurement frequency
% n_oct     : number of measurement frequencies pr octave
% fres      : frequency resolution of spectrum, signal period T=1/fres
% Nav       : number of periods to average over
% UmikSN    : Umik serial number as a string. e.g. '708-0335'
% IncAngle  : wave incidence angle on the UMIK microphone, either 90 (side
%             incidence) or 0 (axial incidence). The corresponding correction
%             curve will be used.
% Nmeas     : Perform 1,2 or 3 consecutive measurements. A warning signal
%             will be played in between measurements for setup changing.
%             This may be used e.g. for the measurement of the three units
%             in a loudspeaker. The measurement is continuous to obtain
%             consistent relative phases.
%
% Finn Agerkvist 09-2014
% Modified for Lab D and NI 4431 2017
% Modified to use PC sound card and UMIK microphone from MiniDSP - VCH 09-2023
% I/O devices detection and setting of mic correction files - VCH 09-2024

if nargin<5
    Nav=4
    if nargin<4
        fres=1
        if nargin<3
           n_oct=12
           if nargin<2
              f2=20000
              if nargin<1
                  f1=1
              end
           end
        end
    end
end
% fs=96000;
fs=48000;
T=1/fres;
Amax=3.5; % NI 4431
rms_out=0.1;
fb=0.1; % No boost

% Nmeas=ceil(Nav/16); % number of measurements (*)
% (*) Sound card measurement must be done in one run. The phase shifts change for 
%     every run and cannot be averaged.
Navg=Nav;% Navg=min(Nav,16); % Number of periods of measurement signal
Nrep=Navg+1;  % add one period for transient part

% Warning sound in between measurements
[beeps,fbeeps] = audioread('beeps.wav');beeps=beeps';  % fbeeps is 48000, should be the same as fs
Nbp=length(beeps); % this is around 30 seconds

[t,sig1,fn]=createMultitone_w(fs,f1,f2,n_oct,fres,Amax,fb);
rmssig=sqrt(mean(sig1.^2));
sig1=sig1*rms_out/rmssig;
sigmax=max(abs(sig1));

Np=length(sig1);
sig=[];
for n=1:Nrep
    sig=[sig sig1];
end
N=length(sig);%t=(0:N-1)/fs;

if Nmeas==2
    sig=[sig beeps sig];
elseif Nmeas==3
    sig=[sig beeps sig beeps sig];
else
    Nmeas=1;
end

%outrange=[-3.5 3.5];
%range_in=[-10 10];

% Explore and assign I/O devices. All devices should be connected before starting Matlab.
nIDev = audiodevinfo(1); % Count input devices
nODev = audiodevinfo(0); % Count output devices
infoIO=audiodevinfo;     % See conected audio devices and their IDs

deviceID1=NaN; deviceID2=NaN; deviceID3=NaN;  % Initialize
for II=1:nIDev % Find microphone and line input
    if contains(infoIO.input(II).Name,'Umik')
        deviceID2=infoIO.input(II).ID;
    end
    if contains(infoIO.input(II).Name,'Line')% && contains(infoIO.input(II).Name,'USB') % For use with external sound card "7.1 Surround"
        deviceID1=infoIO.input(II).ID;
    end
end
for II=1:nODev % Find loudspeaker output
    if contains(infoIO.output(II).Name,'Speakers')% && contains(infoIO.output(II).Name,'USB') % For use with external sound card "7.1 Surround"
        deviceID3=infoIO.output(II).ID;
    end
end
disp(['Microphone ID: ' num2str(deviceID2) ';  Line In ID: ' num2str(deviceID1) ';  Speaker ID: ' num2str(deviceID3)])

nBits=24;   % bits per sample: what HW allows
nChannels=1; % Mono/stereo


recorder1 = audiorecorder(fs,nBits,nChannels,deviceID1);
recorder2 = audiorecorder(fs,nBits,nChannels,deviceID2);
player1 = audioplayer(sig,fs,nBits,deviceID3);


% data0=zeros(Np,1);
% data1=zeros(Np,1);
data0=zeros(Np,Nmeas);
data1=zeros(Np,Nmeas);

%     nmeas=m

play(player1);
record(recorder1,length(sig)/fs+0.5);
recordblocking(recorder2,length(sig)/fs+0.5);
dataID1 = getaudiodata(recorder1);
dataID2 = getaudiodata(recorder2);

%     data0t=zeros(Np,1);
%     data1t=zeros(Np,1);
data0t=zeros(Np,Nmeas);
data1t=zeros(Np,Nmeas);
for m=1:Nmeas
    for n=1:Navg
%         Nn=(N-(fs/fres):N-1)-(n-1)*Np;
        Nn=(N-(fs/fres):N-1)-(n-1)*Np + (m-1)*Nbp+(m-1)*N;
        
        
        data0t(:,m)=data0t(:,m)+dataID1(Nn);
        data1t(:,m)=data1t(:,m)+dataID2(Nn);
    end
    data0(:,m)=data0(:,m)+data0t(:,m)/Navg;
    data1(:,m)=data1(:,m)+data1t(:,m)/Navg;
end
% data0=data0/Nmeas;
% data1=data1/Nmeas;

% rms_0=sqrt(mean(data0.^2))
% rms_1=sqrt(mean(data1.^2))

figure(20)
subplot(2,1,1)
plot(t,data0)
%axis([ 0 1/fres range_in])
subplot(2,1,2)
plot(t,data1)
%axis([ 0 1/fres range_in])

spec0=fft(2*fres*data0/fs);
spec1=fft(2*fres*data1/fs);

f=(0:Np-1)*fres;

% Correction for MiniDSP mic incidence (unit-dependent)
if contains(UmikSN,'0335')
    Field_correction_values_UMIK_MiniDSP_SN_7080335  % Load calibration values for the mic
elseif contains(UmikSN,'0332')
    Field_correction_values_UMIK_MiniDSP_SN_7080332  % Load calibration values for the mic
elseif contains(UmikSN,'0329')
    Field_correction_values_UMIK_MiniDSP_SN_7080329  % Load calibration values for the mic
else
    error('No correction available for this microphone. Check S/N.')
end

if IncAngle == 0
    Cal_angle=Cal_0deg;
else
    Cal_angle=Cal_90deg;
end

Cal_dB = interpn(Cal_angle(:,1),Cal_angle(:,2),f,'makima');
Cal = 10.^(Cal_dB'/20); % dB to linear correction (1)

Cal_n_dB = interpn(Cal_angle(:,1),Cal_angle(:,2),fn,'makima');
Cal_n = 10.^(Cal_n_dB'/20); % dB to linear correction (2)


i_f=fn/fres+1; Ni_f=length(fn);
spec=zeros(Np,2,Nmeas);
specn=zeros(Ni_f,2,Nmeas);
ch=zeros(Np,2,Nmeas);

for m=1:Nmeas
    spec(:,:,m)=[spec0(:,m) spec1(:,m)./Cal];
    specn(:,:,m)=[spec0(i_f,m) spec1(i_f,m)./Cal_n];
    % spec(:,:,m)=[spec0(:,m) spec1(:,m)];              % No correction
    % specn(:,:,m)=[spec0(i_f,m) spec1(i_f,m)];   % No correction
    ch(:,:,m)=[data0(:,m) data1(:,m)];
end



figure(21)
Nf=fs/fres/2;
idx_n=fn/fres+1;

fnN=[fn fs+1];

idx_ND=zeros(1,Nf);
idx_nn=1;
idx_nd=1;
for i=1:Nf
    if f(i)<fnN(idx_nn)
        idx_ND(idx_nd)=i;
        idx_nd=idx_nd+1;
    else
        idx_nn=idx_nn+1;
    end
end

idx_ND=idx_ND(1:idx_nd-1);
       

vref=1;
pref=20e-6;


specmax=db(max(max(max(abs(specn))))/vref);

Lmax=10*ceil(specmax/10);


for m=1:Nmeas
    
    subplot(2,Nmeas,m)
    semilogx(fn,db(abs(specn(:,1,m)/vref)),f(idx_ND),db(abs(spec(idx_ND,1,m)/vref)))
    legend('Signal spectrum','Noise + distortion')
    title('Channel 0 voltage - magnitude spectrum')
    % axis([f1 f2 Lmax-120 Lmax])
    
    subplot(2,Nmeas,Nmeas+m)
    semilogx(fn,db(abs(specn(:,2,m)/vref)),f(idx_ND),db(abs(spec(idx_ND,2,m)/vref)))
%     semilogx(fn,angle(specn(:,2,m)),f(idx_ND),angle(spec(idx_ND,2,m)))
    title('Channel 1 voltage - magnitude spectrum')
    legend('Signal spectrum','Noise + distortion')
    % axis([f1 f2 Lmax-120 Lmax])
    
end