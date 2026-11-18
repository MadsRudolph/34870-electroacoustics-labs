function build_system_simulink
% Full System D: MiniDSP biquads -> physical passive filters -> measured TF FIRs.
% Run prepare_system_data.py first. All coefficients are embedded in the .slx.
here=fileparts(mfilename('fullpath')); cd(here); set(groot,'defaultFigureVisible','off');
D=jsondecode(fileread('system_data.json')); f=D.f(:); w=2*pi*f; fs=D.fs;
for tag={'woof','mid','tw'}
 u=tag{1}; D.(['tf_' u])=D.(['tf_' u '_re'])+1j*D.(['tf_' u '_im']);
end
ref=D.ref_sum_re+1j*D.ref_sum_im;
passive=build_passive_simscape(D);
[A,B,C,E]=linmod(passive); H=zeros(numel(f),3);
for k=1:numel(f), H(k,:)=(C*((1j*w(k)*eye(size(A))-A)\B)+E).'; end
% Verify physical circuit against independently evaluated passive ladder equations.
Zmid=loadZ(f,[4.6 .0001699 .0004073 8.974 5 .01197 1.759 .000264]);
Ztw=loadZ(f,[3.4 1.942e-5 2.364e-5 1.577 3 .0005024 2.897 2.495e-5]);
Zmp=1./(1./Zmid+1j*w*D.Cmid); Zmi=1j*w*D.Lmid+Zmp; Tm=Zmp./Zmi;
Ztp=1./(1./Ztw+1/D.Rp); Zlp=1./(1./(D.Rs+Ztp)+1./(1j*w*D.Ltw)); Zti=1./(1j*w*D.Ctw)+Zlp;
Tt=Zlp./Zti.*Ztp./(D.Rs+Ztp); Zi=1./(1./Zmi+1./Zti);
errors=[max(abs(H(:,1)./Tm-1)),max(abs(H(:,2)./Tt-1)),max(abs(H(:,3).*Zi-1))];
fprintf('Passive Simscape relative complex errors [mid tw input]: %s\n',mat2str(errors,5));
assert(max(errors)<1e-5,'Physical crossover wiring mismatch');
% Measured-data comparison, separately showing load-fit and FIR errors.
LP=freqz(D.b_lp,D.a_lp,w/fs).^2; HP=freqz(D.b_hp,D.a_hp,w/fs).^2;
TF=zeros(numel(f),3); TFfir=TF;
tags={'woof','mid','tw'};
for k=1:3
 u=tags{k}; TF(:,k)=D.(['tf_' u]);
 TFfir(:,k)=freqz(D.(['fir_' u]),1,w/fs).*exp(1j*w*D.delay_samples/fs);
end
V=[D.pol_woof*D.g_woof*LP,D.pol_mid*HP.*H(:,1),D.pol_tw*HP.*H(:,2)];
P=V.*TFfir; summed=sum(P,2); fitted=sum(V.*TF,2);
band=f>=150 & f<=15000;
db=@(x)20*log10(max(abs(x),1e-15));
fprintf('Total vs measured-table reference: median %.3f dB, worst %.3f dB (150 Hz-15 kHz)\n',median(abs(db(summed(band)./ref(band)))),max(abs(db(summed(band)./ref(band)))));
fprintf('FIR-only total error: median %.3f dB, worst %.3f dB\n',median(abs(db(summed(band)./fitted(band)))),max(abs(db(summed(band)./fitted(band)))));
[modes,poles]=eig(A); poles=diag(poles);
residues=max(abs((C*modes).*(modes\B).'),[],1).';
active=residues>1e-8*max(residues);
fprintf('Observable/excitable physical poles: %s\n',mat2str(poles(active),4));
assert(all(isfinite(summed)) && all(real(poles(active))<0),'Nonfinite or unstable input-output model');
% Build runnable mixed discrete/continuous model. Physical network remains editable.
mdl='System_D_simulink'; if bdIsLoaded(mdl), close_system(mdl,0); end; new_system(mdl);
ws=get_param(mdl,'ModelWorkspace'); names=fieldnames(D);
for k=1:numel(names)
    value=D.(names{k});
    if startsWith(names{k},{'b_','a_','fir_'}), value=value(:).'; end
    assignin(ws,names{k},value);
end
add_block('simulink/Sources/Sine Wave',[mdl '/Input 1V 1kHz'],'Position',[30 170 100 220], ...
 'Amplitude','1','Frequency','2*pi*1000','SampleTime','1/fs');
wire=@(a,b)add_line(mdl,a,b,'autorouting','on');
for branch={'lp','hp'}
 b=branch{1}; if strcmp(b,'lp'), y=70; else,y=270; end
 for n=1:2
  name=sprintf('%s BW2 section %d',upper(b),n);
  add_block('simulink/Discrete/Discrete Filter',[mdl '/' name],'Position',[170+(n-1)*170 y 290+(n-1)*170 y+60], ...
   'Numerator',['b_' b],'Denominator',['a_' b],'SampleTime','1/fs');
 end
 wire('Input 1V 1kHz/1',[upper(b) ' BW2 section 1/1']);
 wire([upper(b) ' BW2 section 1/1'],[upper(b) ' BW2 section 2/1']);
end
add_block('simulink/Math Operations/Gain',[mdl '/Woofer minus4.5dB'],'Position',[520 80 590 120],'Gain','g_woof');
wire('LP BW2 section 2/1','Woofer minus4.5dB/1');
sub=[mdl '/Passive crossover - open me']; add_block('built-in/Subsystem',sub,'Position',[520 250 760 390]);
Simulink.BlockDiagram.copyContentsToSubsystem(passive,sub);
wire('HP BW2 section 2/1','Passive crossover - open me/1');
add_block('simulink/Sinks/Terminator',[mdl '/Current unused'],'Position',[790 365 810 385]);
wire('Passive crossover - open me/3','Current unused/1');
for k=1:3
 u=tags{k}; y=70+(k-1)*180;
 add_block('simulink/Discrete/Zero-Order Hold',[mdl '/Sample ' u],'Position',[810 y+10 870 y+50],'SampleTime','1/fs');
 add_block('simulink/Discrete/Discrete Filter',[mdl '/Measured TF ' u],'Position',[930 y 1110 y+60], ...
 'Numerator',['fir_' u],'Denominator','1','SampleTime','1/fs');
 add_block('simulink/Math Operations/Gain',[mdl '/Polarity ' u],'Position',[1160 y+10 1210 y+50],'Gain',['pol_' u]);
 wire(['Sample ' u '/1'],['Measured TF ' u '/1']); wire(['Measured TF ' u '/1'],['Polarity ' u '/1']);
end
wire('Woofer minus4.5dB/1','Sample woof/1');
wire('Passive crossover - open me/1','Sample mid/1'); wire('Passive crossover - open me/2','Sample tw/1');
add_block('simulink/Math Operations/Sum',[mdl '/Acoustic sum'],'Position',[1290 230 1320 300],'Inputs','+++');
for k=1:3, wire(['Polarity ' tags{k} '/1'],sprintf('Acoustic sum/%d',k)); end
add_block('simulink/Sinks/Scope',[mdl '/Pressure at microphone'],'Position',[1390 210 1460 260]); wire('Acoustic sum/1','Pressure at microphone/1');
add_block('simulink/Sinks/To Workspace',[mdl '/Save pressure'],'Position',[1380 300 1490 340],'VariableName','pressure','SaveFormat','Timeseries'); wire('Acoustic sum/1','Save pressure/1');
a=Simulink.Annotation(mdl,'SYSTEM D | 96 kHz LR4 crossover at 325 Hz | double-click passive crossover to see the electrical circuit'); a.Position=[170 10];
a=Simulink.Annotation(mdl,sprintf('Measured TF blocks = Lab E data converted to FIR filters.\nAll three have the SAME added %.2f ms delay.\nSpeaker impedances are fitted passive RLC approximations of Lab D.',1000*D.delay_samples/fs)); a.Position=[900 555];
set_param(mdl,'Solver','ode23t','MaxStep','1/(2*fs)','RelTol','1e-5','StopTime','0.45');
save_system(mdl);
if ~isfolder(fullfile(here,'figures')), mkdir(fullfile(here,'figures')); end
fig=figure('Position',[0 0 1150 850]); fig.Theme='light'; tiledlayout(3,1,'TileSpacing','compact');
nexttile; semilogx(f,db(P),'LineWidth',1); hold on; semilogx(f,db(summed),'k','LineWidth',1.8); semilogx(f,db(ref),'--','Color',[.5 .5 .5]); grid on; xlim([100 20000]); ylim([-40 10]); ylabel('Pressure (dB re 1 Pa)'); legend('woofer','midrange','tweeter','Simulink prediction','LTspice table reference','Location','southwest'); title('System D: fitted Zi loads and measured-response FIRs');
nexttile; semilogx(f,db(summed./ref),'k',f,db(fitted./ref),'--',f,db(summed./fitted),':','LineWidth',1.2); grid on; xlim([150 15000]); ylabel('Difference (dB)'); legend('combined','Zi fit only','FIR only');
nexttile; semilogx(f,abs(Zmid),f,abs(D.zi_mid_re+1j*D.zi_mid_im),'--',f,abs(Ztw),f,abs(D.zi_tw_re+1j*D.zi_tw_im),'--'); grid on; xlim([100 20000]); xlabel('Frequency (Hz)'); ylabel('|Zi| (ohm)'); legend('mid fit','mid Lab D','tweeter fit','tweeter Lab D');
exportgraphics(fig,'figures/system_simulink_response.png','Resolution',150);
print(['-s' mdl],'-dpng','-r110','figures/system_simulink_model.png');
print(['-s' passive],'-dpng','-r110','figures/passive_simscape_model.png');
save('system_validation.mat','f','H','P','summed','ref','errors','A','B','C','E');
% An actual time-domain run verifies the FIR/sampling/physical-network integration.
out=sim(mdl); ts=out.pressure; sel=ts.Time>=0.4;
X=[sin(2*pi*1000*ts.Time(sel)) cos(2*pi*1000*ts.Time(sel)) ones(nnz(sel),1)]; coef=X\ts.Data(sel); amp=hypot(coef(1),coef(2));
expected=abs(interp1(f,summed,1000)); fprintf('1 kHz simulated steady pressure %.6f Pa, predicted %.6f Pa, difference %.4f dB\n',amp,expected,20*log10(amp/expected));
assert(abs(20*log10(amp/expected))<.1,'Time simulation does not match frequency prediction');
save('system_time_validation.mat','ts','amp','expected');
close_system(mdl,0); close_system(passive,0);
disp('Built and verified System_D_simulink.slx and System_D_passive_simscape.slx');
end
function Z=loadZ(f,p)
s=2j*pi*f; Z=p(1)+s*p(2)+1./(1./(s*p(3))+1/p(4))+p(5)^2./(p(7)+s*p(6)+1./(s*p(8)));
end
