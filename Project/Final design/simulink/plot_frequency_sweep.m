function result=plot_frequency_sweep(mdl,result)
% StopFcn: derive H(f)=FFT(output)/FFT(input) from the actual Simulink run.
% A supplied second argument redraws a previously recorded sweep when opening the demo.
% Every completed Run computes a fresh response from its logged input and outputs.
if nargin<1, mdl='System_D_frequency_sweep'; end
if nargin<2
if ~evalin('base',"exist('system_d_sweep_log','var')")
    warning('Sweep data are not available yet. Let the simulation finish.'); result=[]; return
end
ts=evalin('base','system_d_sweep_log');
ws=get_param(mdl,'ModelWorkspace'); fs=evalin(ws,'fs'); delay=evalin(ws,'delay_samples');
t=ts.Time(:); y=squeeze(ts.Data);
assert(size(y,1)==numel(t) && size(y,2)==5,'Unexpected response log dimensions');
if t(end)<1.4
    warning('Sweep stopped early: wait for the complete sweep and decay tail.'); result=[]; return
end
assert(max(abs(diff(t)-1/fs))<1e-8,'Sweep log must be uniformly sampled');
nfft=2^nextpow2(size(y,1)); spec=fft(y,nfft); ff=(0:nfft/2)'*fs/nfft;
spec=spec(1:numel(ff),:); f=logspace(log10(100),log10(19714),1100)';
k=ff>=90 & ff<=21000;
assert(min(abs(spec(k,1)))>1e-6*max(abs(spec(k,1))),'Insufficient sweep excitation');
transfer=spec(:,2:5)./spec(:,1);
transfer=transfer.*exp(2j*pi*ff*delay/fs); % only remove the common artificial FIR delay
H=interp1(ff,transfer,f,'linear');
assert(all(isfinite(H(:))),'Nonfinite frequency response');
result=struct('f',f,'H',H,'fs',fs,'delay_removed',delay/fs,'duration',t(end));
end
f=result.f; H=result.H; fs=result.fs; delay=result.delay_removed*fs;
assignin('base','system_d_frequency_response',result);
fig=findall(groot,'Type','figure','Tag','SystemDFrequencyResponse');
if isempty(fig), fig=figure('Name','System D - frequency response','NumberTitle','off','Tag','SystemDFrequencyResponse'); else, fig=fig(1); clf(fig); end
fig.Visible='on'; fig.Theme='light'; fig.Position=[100 100 1200 780];
lay=tiledlayout(fig,2,1,'TileSpacing','compact'); colors=[.12 .47 .71;.95 .48 .13;.2 .63 .27;0 0 0];
names={'Woofer','Midrange','Tweeter','Combined'};
a=nexttile(lay); hold(a,'on');
for u=1:4, semilogx(a,f,20*log10(max(abs(H(:,u)),1e-12)),'Color',colors(u,:),'LineWidth',1.2+(u==4)); end
set(a,'XScale','log'); xlim(a,[100 20000]); ylim(a,[-45 10]); grid(a,'on');
xline(a,325,':','325 Hz'); xline(a,3760,':','~3.76 kHz');
ylabel(a,'|p / V_{in}| (dB re 1 Pa/V)'); legend(a,names,'Location','southwest');
title(a,'Actual Simulink sweep: each driver and their complex sum');
a=nexttile(lay); hold(a,'on');
for u=1:4
 ph=angle(H(:,u))*180/pi;
 if u<4, ph(abs(H(:,u))<abs(H(:,4))*10^(-25/20))=nan; end
 jumps=[false;abs(diff(ph))>180]; ph(jumps)=nan;
 semilogx(a,f,ph,'Color',colors(u,:),'LineWidth',1.2+(u==4));
end
set(a,'XScale','log'); xlim(a,[100 20000]); ylim(a,[-185 185]); yticks(a,-180:90:180); grid(a,'on');
xlabel(a,'Frequency (Hz)'); ylabel(a,'Phase (degrees)');
title(a,sprintf('Common %.2f ms FIR delay removed; weak driver phases hidden (>25 dB below sum)',1000*delay/fs));
subtitle(lay,'Time-domain sweep includes sample-and-hold effects. Use 150 Hz-15 kHz for comparisons.');
here=fileparts(get_param(mdl,'FileName')); exportgraphics(fig,fullfile(here,'figures','system_frequency_sweep.png'),'Resolution',150);
save(fullfile(here,'frequency_sweep_validation.mat'),'result');
fprintf('Frequency response plotted from %.2f s of simulated data.\n',result.duration);
end
