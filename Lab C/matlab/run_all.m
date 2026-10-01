%% Lab C - run the whole analysis
% Runs the four parts in order. Each part reads the untouched lab-PC files in
% '../raw data/' and writes only to 'results/' and '../figures/'.
%
%   part1_system_reference   NI card + Nexus on their own, H_21_ref
%   part2_sensitivity        calibrator sensitivities, corrected, statistics
%   part3_mic_responses      actuator responses, noise floor, f_s and Q
%   part4_model              backplate M_AS and R_AS, model vs measurement

part1_system_reference
part2_sensitivity
part3_mic_responses
part4_model
