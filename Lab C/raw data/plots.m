figure
semilogx(fn,db(abs(H_21_m1./H_21_ref)))
legend('H_21_m1')
title('Transferfunction - micro sensitivity')
figure
semilogx(fn,db(abs(H_21_m2./H_21_ref)))
legend('H_21_m2')
title('Transferfunction - micro sensitivity')