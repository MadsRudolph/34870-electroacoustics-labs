f1=20;
f2=60000;
Amax=1;
n_oct=6;
Nav=4;
fb=1;
fres=1;

[fn,specn,f,spec,ch]= meas_mag_spec2(f1,f2,Amax,n_oct,Nav,fb,fres);

figure;
H_21_ref = specn(:,2)./specn(:,1);
semilogx(fn,db(abs(H_21_ref)))
legend('H21ref')
title('Transferfunction - magnitude spectrum')

