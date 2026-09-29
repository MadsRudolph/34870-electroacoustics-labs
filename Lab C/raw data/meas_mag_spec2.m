function  [fn,specn,f,spec,ch]=meas_mag_spec2(f1,f2,Amax,n_oct,Nav,fb,fres,range1)
% NI-6356 USB data acquisition routine
% This function measures the spectrum of input channels 0 and 1 
% when driver with a multitone signal from output 0
%fn    :  vector of signal frequencies 
% specn :  spectrum for fn
% f     :  full frequency vector
% spec  :  full spectrum
% ch    :  averaged timesignals
%
% Input parameters
% f1 : lower measurement frequency
% f2 : upper measurement frequency
% Amax : maximum signal level (output 0)
% n_oct : number of measurement frequencies pr octave
% Nav  :  Number of periods to average over
% fb  :  frequency below which the measurement is increase 6 dB/oct
% fres : frequency resolution of spectrum, signal period T=1/fres
%
% Finn Agerkvist 09-2014
%
if nargin<8
    range1=[-1 1]
    if nargin<7
        fres=1
        if nargin<6
            fb=1
            if nargin<5
               Nav=4
               if nargin<4
                  n_oct=3
                  if nargin<3
                      Amax=1
                  end
               end
            end
        end
    end
end
        

FS=1.25e6;
fs=96000

T=1/fres;


Nmeas=ceil(Nav/16); % number of measurements 
Navg=min(Nav,16); % Number of periods of measurement signal
Nrep=Navg+1;  % add one period for transient part

[t,sig1,fn]=createMultitone_w(fs,f1,f2,n_oct,fres,Amax,fb);


Np=length(sig1);
sig=[];
for n=1:Nrep
    sig=[sig sig1];
end

N=length(sig);
%t=(0:N-1)/fs;

outrange=[-3.5 3.5];
range0=[-10 10];
 
d=daq.getDevices;
s=daq.createSession('ni');

s.Rate=fs;
s.addAnalogOutputChannel('Dev4',0,'Voltage');
s.Channels(1).Range=outrange;
s.addAnalogInputChannel('Dev4',0,'Voltage');
s.Channels(2).Range=range0;
s.addAnalogInputChannel('Dev4',1,'Voltage');
s.Channels(3).Range=range1
%s.addAnalogInputChannel('Dev1',2,'Voltage')
%s.Channels(3).Range=[-1 1]
%s.Channels(2).Range=[-2 2]
%s.Channels(2).Range=[-5 5]
%s.Channels(2).Range=[-10 10]


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

figure(20)
subplot(2,1,1)
plot(t,data0)
axis([ 0 1/fres range0])
subplot(2,1,2)
plot(t,data1)
axis([ 0 1/fres range1])

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