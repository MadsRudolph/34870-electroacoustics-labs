clear; clc; close all
load('all.mat')

f  = double(fn(:));     % frequency vector [Hz]
H1 = H_21_m1(:);        % Mic 1 transfer function
H2 = H_21_m2(:);        % Mic 2 transfer function

[H0_1, fs1, Q1] = fitResonance(f, H1);
[H0_2, fs2, Q2] = fitResonance(f, H2);

fprintf('Mic 1: fs = %.1f Hz,  Q = %.3f\n', fs1, Q1);
fprintf('Mic 2: fs = %.1f Hz,  Q = %.3f\n', fs2, Q2);

% --- Plot measured vs. fitted model to check the fit ---
w = 2*pi*f;
Hfit1 = H0_1 ./ (1 + 1i*w/(Q1*2*pi*fs1) - (w/(2*pi*fs1)).^2);
Hfit2 = H0_2 ./ (1 + 1i*w/(Q2*2*pi*fs2) - (w/(2*pi*fs2)).^2);

figure
subplot(2,1,1)
semilogx(f, 20*log10(abs(H1)), 'ro', f, 20*log10(abs(Hfit1)), 'r-', ...
         f, 20*log10(abs(H2)), 'bo', f, 20*log10(abs(Hfit2)), 'b-')
grid on; ylabel('|H_{21}| [dB]')
legend('Mic1 meas','Mic1 fit','Mic2 meas','Mic2 fit','Location','southwest')

subplot(2,1,2)
semilogx(f, unwrap(angle(H1))*180/pi, 'ro', f, unwrap(angle(Hfit1))*180/pi, 'r-', ...
         f, unwrap(angle(H2))*180/pi, 'bo', f, unwrap(angle(Hfit2))*180/pi, 'b-')
grid on; xlabel('Frequency [Hz]'); ylabel('Phase [deg]')
yline(-90,':k');

% ------------------------------------------------------------------
function [H0, fs, Q] = fitResonance(f, H)
% Fits H(jw) = H0 / (1 + j*w/(Q*ws) - (w/ws)^2) to measured complex data
w = 2*pi*f;

[~, ipk] = max(abs(H));
fs0 = f(ipk);                 % initial guess: peak location
H0_0 = mean(abs(H(1:5)));     % initial guess: low-freq plateau
Q0  = 2;

p0 = [H0_0, fs0, Q0];

modelResid = @(p) complexResidual(p, w, H);
opts = optimset('Display','off','MaxFunEvals',1e4,'MaxIter',1e4);
p = fminsearch(modelResid, p0, opts);

H0 = p(1); fs = abs(p(2)); Q = abs(p(3));
end

function cost = complexResidual(p, w, H)
H0 = p(1); ws = 2*pi*abs(p(2)); Q = abs(p(3));
Hmodel = H0 ./ (1 + 1i*w/(Q*ws) - (w/ws).^2);
err = Hmodel - H;
cost = sum(real(err).^2 + imag(err).^2);
end