function  [fn,specn,f,spec,ch]=meas_mag_spec2_LabD(f1,f2,n_oct,fres,Nav)
% NI-4431 USB data acquisition routine
% This function measures the spectrum of input channels 0 and 1 
% when driver with a multitone signal from output 0
% fn    :  vector of signal frequencies 
% specn :  spectrum for fn
% f     :  full frequency vector
% spec  :  full spectrum
% ch    :  averaged timesignals
%
% Input parameters
% f1 : lower measurement frequency
% f2 : upper measurement frequency
% n_oct : number of measurement frequencies pr octave
% fres : frequency resolution of spectrum, signal period T=1/fres
% Nav  :  Number of periods to average over
%
% Finn Agerkvist 09-2014
% Modified for Lab D and NI 4431 2017
%
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

% NI 4431
fs=96000;
T=1/fres;
Amax=3.5; % NI 4431
rms_out=0.1;

fb=0.1; % No boost

Nmeas=ceil(Nav/16); % number of measurements 
Navg=min(Nav,16); % Number of periods of measurement signal
Nrep=Navg+1;  % add one period for transient part

[t,sig1,fn]=createMultitone_w(fs,f1,f2,n_oct,fres,Amax,fb);

rmssig=sqrt(mean(sig1.^2));
sig1=sig1*rms_out/rmssig;
sigmax=max(abs(sig1));

Np=length(sig1);
sig=[];
for n=1:Nrep
    sig=[sig sig1];
end

N=length(sig);
%t=(0:N-1)/fs;

outrange=[-3.5 3.5];
range_in=[-10 10];
 
d=daq.getDevices;
s=daq.createSession('ni');

s.Rate=fs;
s.addAnalogOutputChannel('Dev4',0,'Voltage');
s.Channels(1).Range=outrange;
s.addAnalogInputChannel('Dev4',0,'Voltage');
s.Channels(2).Range=range_in;
s.addAnalogInputChannel('Dev4',1,'Voltage');
s.Channels(3).Range=range_in;
%s.addAnalogInputChannel('Dev2',2,'Voltage')


data0=zeros(Np,1);
data1=zeros(Np,1);
%data2=zeros(Np,1);

for m=1:Nmeas

    nmeas=m
    s.queueOutputData(sig');
    data=s.startForeground;
    data0t=zeros(Np,1);
    data1t=zeros(Np,1);
%   data2t=zeros(Np,1);
    for n=1:Navg
        Nn=(N-(fs/fres):N-1)-(n-1)*Np;
        data0t=data0t+data(Nn,1);
        data1t=data1t+data(Nn,2);
%       data2t=data2t+data(Nn,3);
    end
    data0=data0+data0t/Navg;
    data1=data1+data1t/Navg;
%   data2=data2+data2t/Navg;
end
data0=data0/Nmeas;
data1=data1/Nmeas;
%data2=data2/Nmeas;
rms_0=sqrt(mean(data0.^2))
rms_1=sqrt(mean(data1.^2))


figure(20)
subplot(2,1,1)
plot(t,data0)
%axis([ 0 1/fres range_in])
subplot(2,1,2)
plot(t,data1)
%axis([ 0 1/fres range_in])

% max1=max(abs(data0));
% if max1>8 
%     warning('Amplifier voltage too high for antialiasing filter')
% end


spec0=fft(2*fres*data0/fs);
spec1=fft(2*fres*data1/fs);

spec=[spec0 spec1];

f=(0:Np-1)*fres;

i_f=fn/fres+1;
specn=[spec0(i_f) spec1(i_f)];
ch=[data0 data1];

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


specmax=db(max(max(abs(specn)))/vref);

Lmax=10*ceil(specmax/10);



subplot(2,1,1)
semilogx(fn,db(abs(specn(:,1)/vref)),f(idx_ND),db(abs(spec(idx_ND,1)/vref)))
legend('Signal spectrum','Noise + distortion')
title('Channel 0 voltage - magnitude spectrum')
axis([f1 f2 Lmax-120 Lmax])

subplot(2,1,2)
semilogx(fn,db(abs(specn(:,2)/vref)),f(idx_ND),db(abs(spec(idx_ND,2)/vref)))
title('Channel 1 voltage - magnitude spectrum')
legend('Signal spectrum','Noise + distortion')
axis([f1 f2 Lmax-120 Lmax])

