f1=20; 
f2=60000; 
Amax=1; 
n_oct=6; 
Nav=4; 
fb=200; 
fres=1;

%[fn,specn,f,spec,ch]=meas_mag_spec2(f1,f2,Amax,n_oct,Nav,fb,fres);
figure;
%H_21_m1 = specn(:,2)./specn(:,1);
%H_21_pv = H_21_m1./H_21_ref;
subplot(1)
semilogx(fn,db(abs(H_21_m1)))
legend('H_21_m1')
title('Transferfunction - micro sensitivity')
subplot(2)
semilogx(fn,db(abs(H_21_m2)))
legend('H_21_m2')
title('Transferfunction - micro sensitivity')