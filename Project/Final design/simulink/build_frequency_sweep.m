function build_frequency_sweep
% Create a Run-button frequency-response demo from the working physical model.
here=fileparts(mfilename('fullpath')); cd(here);
src='System_D_simulink'; mdl='System_D_frequency_sweep';
if bdIsLoaded(mdl), close_system(mdl,0); end
copyfile([src '.slx'],[mdl '.slx']); load_system(mdl);
set_param([mdl '/Pressure at microphone'],'Name','Optional time waveform');
ws=get_param(mdl,'ModelWorkspace'); fs=evalin(ws,'fs'); delay=evalin(ws,'delay_samples');
T=1; tail=.45; t=(0:round((T+tail)*fs))'/fs;
f0=40; f1=22000; rate=log(f1/f0)/T; signal=zeros(size(t)); k=t<T;
x=t(k); env=min(1,x/.015).*min(1,(T-x)/.015);
signal(k)=env.*sin(2*pi*f0/rate*expm1(rate*x));
assignin(ws,'sweep_input',[t signal]);
old=[mdl '/Input 1V 1kHz']; lines=get_param(old,'LineHandles'); delete_line(lines.Outport); delete_block(old);
add_block('simulink/Sources/From Workspace',[mdl '/Sweep 40Hz to 22kHz'],'Position',[25 170 130 220], ...
 'VariableName','sweep_input','SampleTime','1/fs','Interpolate','off','OutputAfterFinalValue','Setting to zero');
add_line(mdl,'Sweep 40Hz to 22kHz/1','LP BW2 section 1/1','autorouting','on');
add_line(mdl,'Sweep 40Hz to 22kHz/1','HP BW2 section 1/1','autorouting','on');
% Log input and all three pressures on the same 96 kHz clock.
add_block('simulink/Signal Routing/Mux',[mdl '/Response channels'],'Position',[1540 70 1545 480],'Inputs','5');
channels={'Sweep 40Hz to 22kHz/1','Polarity woof/1','Polarity mid/1','Polarity tw/1','Acoustic sum/1'};
for k=1:5, add_line(mdl,channels{k},sprintf('Response channels/%d',k),'autorouting','on'); end
add_block('simulink/Sinks/To Workspace',[mdl '/Frequency response data'],'Position',[1610 240 1780 290], ...
 'VariableName','system_d_sweep_log','SaveFormat','Timeseries','MaxDataPoints','inf','Decimation','1','SampleTime','1/fs');
add_line(mdl,'Response channels/1','Frequency response data/1');
% StopFcn can access To Workspace output when Single Simulation Output is off.
set_param(mdl,'ReturnWorkspaceOutputs','off','StopTime',num2str(T+tail), ...
 'InitFcn',"evalin('base','clear system_d_sweep_log system_d_frequency_response'); close(findall(groot,'Type','figure','Tag','SystemDFrequencyResponse'));", ...
 'StopFcn',"plot_frequency_sweep(bdroot);", ...
 'PostLoadFcn',"addpath(fileparts(get_param(bdroot,'FileName')));");
a=Simulink.Annotation(mdl,sprintf('PRESS RUN: a 1 s logarithmic sweep, then %.2f s for the response tail.\nMagnitude and phase open automatically when the simulation finishes.\nThe small Scope is optional: it shows the time waveform only.',tail));
a.Position=[160 600]; a.FontSize=12;
save_system(mdl); close_system(mdl,0);
fprintf('Created %s.slx: %.2f s of simulation, common FIR delay %.3f ms\n',mdl,T+tail,1000*delay/fs);
end
