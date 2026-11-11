function open_models
% Open the woofer circuit and the frequency-sweep demonstration.
here=fileparts(mfilename('fullpath')); cd(here); addpath(here);
open_system('Woofer_Vented_L160_simscape.slx');
set_param('Woofer_Vented_L160_simscape','ZoomFactor','FitSystem');
if isfile('System_D_frequency_sweep.slx')
    mdl='System_D_frequency_sweep';
else
    mdl='System_D_simulink';
end
open_system([mdl '.slx']); set_param(mdl,'ZoomFactor','FitSystem');
end
