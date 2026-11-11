function mdl=build_passive_simscape(D)
% Physical crossover and passive RLC equivalents of the measured driver loads.
% Zi equivalents use the group's Lab-D fitted DALI parameters. They are
% approximations of Zi, so the measured-table comparison is reported separately.
mdl='System_D_passive_simscape';
if bdIsLoaded(mdl), close_system(mdl,0); end
new_system(mdl); load_system('fl_lib'); load_system('nesl_utility');
E='fl_lib/Electrical/Electrical Elements/';
libs=struct('R',[E 'Resistor'],'L',[E 'Inductor'],'C',[E 'Capacitor'],'G',[E 'Electrical Reference'], ...
 'V',sprintf('fl_lib/Electrical/Electrical Sources/Controlled Voltage\nSource'), ...
 'VS','fl_lib/Electrical/Electrical Sensors/Voltage Sensor','IS','fl_lib/Electrical/Electrical Sensors/Current Sensor', ...
 'SP',sprintf('nesl_utility/Simulink-PS\nConverter'),'PS',sprintf('nesl_utility/PS-Simulink\nConverter'), ...
 'SOL',sprintf('nesl_utility/Solver\nConfiguration'));
B=@(n,k,pos,varargin)add_block(libs.(k),[mdl '/' n],'Position',pos,varargin{:});
p=@(n)get_param([mdl '/' n],'PortHandles');
wire=@(a,b)add_line(mdl,a,b,'autorouting','smart');
add_block('simulink/Sources/In1',[mdl '/Vhp'],'Position',[20 200 50 220]);
B('S-PS','SP',[80 200 110 220],'Unit','V');
B('Amplifier','V',[150 180 200 240]); B('Ground','G',[160 500 190 530]);
B('Solver','SOL',[30 490 80 520]); B('Iamp','IS',[230 70 280 100]);
wire(p('Vhp').Outport,p('S-PS').Inport); wire(p('S-PS').RConn,p('Amplifier').RConn(1));
wire(p('Amplifier').LConn,p('Iamp').LConn); g=p('Ground').LConn;
wire(p('Amplifier').RConn(2),g); wire(p('Solver').RConn,g); input=p('Iamp').RConn(2);
% Midrange LP2
B('Lmid 0.82mH','L',[340 70 410 100],'l',num2str(D.Lmid),'r','0','g','0');
B('Cmid 6.8uF','C',[470 130 500 190],'c',num2str(D.Cmid),'r','0','g','0','Orientation','down');
wire(input,p('Lmid 0.82mH').LConn); mid=p('Lmid 0.82mH').RConn;
wire(mid,p('Cmid 6.8uF').LConn); wire(p('Cmid 6.8uF').RConn,g);
% Tweeter HP2 and L-pad
B('Ctw 5.6uF','C',[340 300 410 330],'c',num2str(D.Ctw),'r','0','g','0');
B('Ltw 0.22mH','L',[470 360 500 420],'l',num2str(D.Ltw),'r','0','g','0','Orientation','down');
B('Rs 4.7ohm','R',[540 300 610 330],'R',num2str(D.Rs));
B('Rp 3.3ohm','R',[650 360 680 420],'R',num2str(D.Rp),'Orientation','down');
wire(input,p('Ctw 5.6uF').LConn); t=p('Ctw 5.6uF').RConn;
wire(t,p('Ltw 0.22mH').LConn); wire(p('Ltw 0.22mH').RConn,g);
wire(t,p('Rs 4.7ohm').LConn); tw=p('Rs 4.7ohm').RConn;
wire(tw,p('Rp 3.3ohm').LConn); wire(p('Rp 3.3ohm').RConn,g);
% Physical speaker impedance: Re + sLe + (sL2 || R2) + (Rmot || sLmot || 1/sCmot).
% Motional parallel RLC equals Bl^2/(Rms+sMmd+1/(sCms)).
pars=[4.6 .0001699 .0004073 8.974 5 .01197 1.759 .000264; ...
      3.4 1.942e-5 2.364e-5 1.577 3 .0005024 2.897 2.495e-5];
nodes=[mid tw];
for k=1:2
 if k==1, tag='Mid'; y=60; else, tag='Tweeter'; y=290; end
 q=pars(k,:); x=800;
 B([tag ' Re'],'R',[x y x+60 y+30],'R',num2str(q(1)));
 B([tag ' Le'],'L',[x+100 y x+160 y+30],'l',num2str(q(2)),'r','0','g','0');
 B([tag ' Leddy'],'L',[x+200 y-20 x+260 y+10],'l',num2str(q(3)),'r','0','g','0');
 B([tag ' Reddy'],'R',[x+200 y+65 x+260 y+95],'R',num2str(q(4)));
 B([tag ' Rmot'],'R',[x+320 y x+350 y+60],'R',num2str(q(5)^2/q(7),16),'Orientation','down');
 B([tag ' Lmot'],'L',[x+410 y x+440 y+60],'l',num2str(q(5)^2*q(8),16),'r','0','g','0','Orientation','down');
 B([tag ' Cmot'],'C',[x+500 y x+530 y+60],'c',num2str(q(6)/q(5)^2,16),'r','0','g','0','Orientation','down');
 wire(nodes(k),p([tag ' Re']).LConn); wire(p([tag ' Re']).RConn,p([tag ' Le']).LConn);
 a=p([tag ' Le']).RConn; b=p([tag ' Leddy']).RConn;
 wire(a,p([tag ' Leddy']).LConn); wire(a,p([tag ' Reddy']).LConn); wire(b,p([tag ' Reddy']).RConn);
 for part={'Rmot','Lmot','Cmot'}
  wire(b,p([tag ' ' part{1}]).LConn); wire(p([tag ' ' part{1}]).RConn,g);
 end
 B([tag ' voltage'],'VS',[760 y+80 800 y+125]);
 % Voltage Sensor uses LConn=+, RConn1=physical voltage output, RConn2=-.
 wire(nodes(k),p([tag ' voltage']).LConn(1)); wire(g,p([tag ' voltage']).RConn(2));
 B([tag ' PS-S'],'PS',[1390 y+90 1430 y+110],'Unit','V');
 wire(p([tag ' voltage']).RConn(1),p([tag ' PS-S']).LConn);
 add_block('simulink/Sinks/Out1',[mdl '/' tag '_voltage'],'Position',[1490 y+90 1520 y+110],'Port',num2str(k));
 wire(p([tag ' PS-S']).Outport,p([tag '_voltage']).Inport);
end
B('Iamp PS-S','PS',[1390 490 1430 510],'Unit','A'); wire(p('Iamp').RConn(1),p('Iamp PS-S').LConn);
add_block('simulink/Sinks/Out1',[mdl '/Amplifier_current'],'Position',[1490 490 1520 510],'Port','3');
wire(p('Iamp PS-S').Outport,p('Amplifier_current').Inport);
a=Simulink.Annotation(mdl,'PASSIVE CROSSOVER + FITTED LAB D LOADS   |   blue lines are physical electrical connections'); a.Position=[250 10];
a=Simulink.Annotation(mdl,'Each driver: Re + Le + (Leddy || Reddy) + (Rmot || Lmot || Cmot). Double-click parts to inspect values.'); a.Position=[770 470];
set_param(mdl,'Solver','ode23t','StopTime','0.02'); save_system(mdl);
end
