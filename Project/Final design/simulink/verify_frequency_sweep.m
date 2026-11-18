function verify_frequency_sweep
% Compare actual FFT measurement to the exact sampled physical network.
here=fileparts(mfilename('fullpath')); cd(here);
load('frequency_sweep_validation.mat','result'); v=load('system_validation.mat');
D=jsondecode(fileread('system_data.json')); f=result.f; w=2*pi*f; fs=D.fs;
% Exact zero-order-hold conversion using expm (no Control System Toolbox needed).
n=size(v.A,1); ab=expm([v.A v.B;zeros(1,n+1)]/fs); Ad=ab(1:n,1:n); Bd=ab(1:n,end);
Hd=zeros(numel(f),3); Hc=Hd;
for k=1:numel(f)
 Hd(k,:)=(v.C*((exp(1j*w(k)/fs)*eye(n)-Ad)\Bd)+v.E).';
 Hc(k,:)=(v.C*((1j*w(k)*eye(n)-v.A)\v.B)+v.E).';
end
LP=freqz(D.b_lp,D.a_lp,w/fs).^2; HP=freqz(D.b_hp,D.a_hp,w/fs).^2;
TF=zeros(numel(f),3); tags={'woof','mid','tw'};
for k=1:3, TF(:,k)=freqz(D.(['fir_' tags{k}]),1,w/fs).*exp(1j*w*D.delay_samples/fs); end
P=[D.g_woof*D.pol_woof*LP D.pol_mid*HP.*Hd(:,1) D.pol_tw*HP.*Hd(:,2)].*TF;
Pc=[D.g_woof*D.pol_woof*LP D.pol_mid*HP.*Hc(:,1) D.pol_tw*HP.*Hc(:,2)].*TF;
k=f>=150 & f<=15000; ref=sum(P,2); err=20*log10(abs(result.H(:,4)./ref));
e=abs(err(k)); [worst,j]=max(e); ff=f(k);
fprintf('Actual sweep vs exact sampled-network prediction: median %.4f dB, worst %.4f dB at %.1f Hz\n',median(e),worst,ff(j));
e_cont=abs(20*log10(abs(result.H(k,4)./sum(Pc(k,:),2))));
fprintf('Actual sweep vs continuous-input prediction at the SAME frequencies: median %.4f dB, worst %.4f dB\n',median(e_cont),max(e_cont));
assert(max(abs(result.H(:,4)-sum(result.H(:,1:3),2)))<1e-8,'Driver responses do not sum');
assert(median(e)<.1 && worst<.4,'Sweep mismatch requires investigation');
save('frequency_sweep_comparison.mat','f','P','Pc','err');
fprintf('SWEEP_TEST_PASSED\n');
end
