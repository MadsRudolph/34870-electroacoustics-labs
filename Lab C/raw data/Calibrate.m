function  M=Calibrate(f,SPL,G_Nex)
% NI-6356 USB data acquisition 
% This function calculates the microphone sensitivity
% Input 
% f    :  calibration frequency  
% SPL  :  calibration sound pressure
% G_Nex:  microphone amplifier gain
%
% Output:
% M : Microphone sensitvity [V/Pa]
%
%
%  Finn Agerkvist 09-2014, 
%  Modified for NI 4431 sept 2017
%
if nargin<3
   G_Nex=10
   if nargin<2
      SPL=94
      if nargin<1
          f=1000
      end
   end
end
        
%fs=1.25e6/8
fs=96000;
fres=1;
T=1/fres;

Amax=1;
Navg=16; % Number of periods of measurement signal
Nrep=Navg+1;  % add one period for transient part

Np=fs/fres;
t=(0:Np-1)/fs;

sig1=Amax*sin(2*pi*f*t);

sig=[];
for n=1:Nrep
    sig=[sig sig1];
end

N=length(sig);

outrange=[-3.5 3.5];
range0=[-10 10];


d=daq.getDevices;
s=daq.createSession('ni');

s.Rate=fs;
s.addAnalogOutputChannel('Dev4',0,'Voltage');
s.Channels(1).Range=outrange;
s.addAnalogInputChannel('Dev4',1,'Voltage');
s.Channels(2).Range=range0;
s.queueOutputData(sig')


display('Start calibration devices and press enter')
pause
display('Measuring')

data=s.startForeground;

display('Done')
pspec=zeros(Np,1);

for n=1:Navg
    Nn=(N-(fs/fres):N-1)-(n-1)*Np;
    pwr=abs(fft(sqrt(2)*fres*data(Nn,1)/fs)).^2;
    pspec=pspec+pwr;
end
pspec=pspec/Navg;

i_f=round(f/fres)+1

if abs(f-250)<20 %f==250 
    v2_f0=pspec(i_f+(-5:0)/fres);  % pistonphone
end
if abs(f-1000)<50 %f==1000
    v2_f0=pspec(i_f+(-1:15)/fres);  % calibrator 
end

v_rms=sqrt(sum(abs(v2_f0)));
p_rms=20e-6*10^(SPL/20);
M=v_rms/p_rms/G_Nex;

figure(30)
subplot(2,1,1)
plot(t,data(Nn))
axis([ 0 1/fres range0])
subplot(2,1,2)
fn=(0:Np-1)*fres;
semilogx(fn,db(abs(pspec))/2)
ymax=ceil(db(v_rms)/5)*5;
axis([ 0  fs/2 ymax-100 ymax+5])

