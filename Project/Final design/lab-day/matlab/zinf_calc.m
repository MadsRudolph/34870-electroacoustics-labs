function r = zinf_calc(specn, ch, kind, R, NexusVperPa, k)
% ZINF_CALC  Impedance or near-field response from one Lab D-style recording.
%
%   r = zinf_calc(specn, ch, kind, R, NexusVperPa, k)
%
%   specn  [V_AI0  V_AI1] at the tone frequencies (course routine output)
%   ch     averaged time signals, same two channels
%   kind   'nearfield' -> AI1 = Nexus output (series resistor shorted)
%          anything else -> AI1 = load voltage behind the series resistor R
%   k      true V_amp = k * AI0. 'auto' (default) picks 2 when AI0 sits on a
%          DC offset above 2 V: that is what happened in Lab D on 6-Oct
%          (AI0 read half the amplifier voltage on ~9.4 V DC; with k = 2 the
%          woofer landed on R_E and the free-air peak on the data sheet).
%
%   r.Z or r.H, r.k, r.dc_AI0, r.clip (fraction of AI0/AI1 samples within
%   0.2 V of the +-10 V input range).

if nargin < 6 || isempty(k), k = 'auto'; end
r.dc_AI0 = mean(ch(:,1));
r.clip = mean(abs(ch) >= 9.8, 1);
if ischar(k)
    k = 1 + (abs(r.dc_AI0) > 2);
end
r.k = k;
if strcmp(kind, 'nearfield')
    r.H = (specn(:,2) / NexusVperPa) ./ (k * specn(:,1));   % Pa per volt at the terminals
else
    G = specn(:,2) ./ (k * specn(:,1));
    r.Z = R * G ./ (1 - G);
end
end
