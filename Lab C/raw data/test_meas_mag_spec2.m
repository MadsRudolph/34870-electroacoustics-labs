clear all
%close all

fs=96000;



f1=20;
f2=48000;
Amax=1;
n_oct=12;
Nav=4;
fb=100;
fres=1;
micrange=[-10 10];
%micrange=[-1 1];

T=1/fres;

[fn,specn,f,spec,ch]=meas_mag_spec2(f1,f2,Amax,n_oct,Nav,fb,fres,micrange);

vref=1;
pref=20e-6;

psens=3.16; %[V/pa]

figure(1)
subplot(2,1,1)
semilogx(f,db(abs(spec(:,1)/vref)),fn,db(abs(specn(:,1)/vref)))
legend('ch0')
title('Amplifier voltage - magnitude spectrum')
axis([5 f2 -110 20])

subplot(2,1,2)
semilogx(f,db(abs(spec(:,2))),fn,db(abs(specn(:,2))))
axis([5 f2*1.2 -80 20])
title('microphone voltage - magnitude spectrum')
legend('ch1')
axis([5 f2 -120 20])


figure(2)
H21n=specn(:,2)./specn(:,1);
subplot(2,1,1)
semilogx(fn,db(abs(H21n)))
legend('H21')
title('Transferfunction - magnitude spectrum')
%axis([5 f2*1.2 -20 20])

subplot(2,1,2)
semilogx(fn,180/pi*angle(H21n))
%axis([5 f2*1.2 -90 10])
title('Transfer function - phase ')
legend('H21')

