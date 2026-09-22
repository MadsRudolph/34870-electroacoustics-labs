f1=50;
f2=10e3;
n_oct=24;
fres=1;
Nav=32;
UmikSN='708-0332';
IncAngle=90;
[fn,specn,f,spec,ch]=meas_mag_spec2_SoundCard_LabB(f1,f2,n_oct,fres,Nav,UmikSN,IncAngle);

%%
h=specn(:,2) ./ specn(:,1);
figure(1);
semilogx(fn, 20*log10(abs(h)));