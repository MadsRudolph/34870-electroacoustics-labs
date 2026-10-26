function [biquad_DSP,LaplaceTXT_E1,LaplaceTXT_E2]=DigitalCrossover(f0,type,n)

% [biquad_DSP,LaplaceTXT_E1,LaplaceTXT_E2]=DigitalCrossover(f0,type,n);
%
% Calculates coefficients for a digital crossover to be implemented in the
% MiniDSP card. Obtains the equivalent analog coefficients formatted for use
% in LTspice.
%
% Input:
%   -f0:              Cut-off frequency
%   -type:            'HPF' (high-pass) or 'LPF' (low-pass)
%   -n:               Order of the filter. n=2: one biquad stage, n=4: two
%                     biquad stages 
% Output:
%   -biquad_DSP:      String with the coefficients to be copied to the
%                     MiniDSP software. Open the MiniDSP software plugin and
%                     connect to the MiniDSP card. Only the combinations
%                     Input1>Output1 and Input1>Output2 should be active.
%                     All options except Xover must be in 'bypass'. Choose
%                     a configuration, go to Outputs > Output1 > Xover >
%                     Advanced > Paste the contents of the 'biquad_DSP' text.
%                     The configuration should be now in the card. Repeat
%                     for Output2. 
%   -LaplaceTXT_E1:   configuration string for the LTspice controlled
%                     sources representing the biquad filter(s). There are
%                     one or two filters (for n=2 and n=4 resp.).
%   -LaplaceTXT_E2:   Second string, only used if n=4.
% 

% Vicente Cutanda Henríquez, 10-2020
% Vicente Cutanda Henríquez, create output text files, 11-2024

clc;
% close all;
% % Filter specs (test)
% f0 = 500;
% type = 'HPF'; 
% n = 4;
fs = 96e3; % Sampling frequency

if type=='HPF' | type=='LPF'
    
    if n==2 | n==4
        
        [Q,biquad_DSP] = cascade_BW(f0,type,n);
        
        % The Q (Quality factor) obtained above is used here to find the
        % coefficients again.
        [b0_A,b1_A,b2_A,a1_A,a2_A] = BQ(f0,fs,Q(1),type);
        
        % The biquad2ltspice function produces a string, to be used in the configuration
        % of a controlled source in LTspice. The input are the filter coefficients.
        LaplaceTXT_E1 = biquad2ltspice(b0_A,b1_A,b2_A,a1_A,a2_A,fs);
        
        if n==4
        % Second LTspice string for a second controlled source.
        % Uses the second Q value produced initially.
        [b0_B,b1_B,b2_B,a1_B,a2_B] = BQ(f0,fs,Q(2),type);
        LaplaceTXT_E2 = biquad2ltspice(b0_B,b1_B,b2_B,a1_B,a2_B,fs);
        else
            LaplaceTXT_E2 = '';
        end
    else
        error('Invalid n value. Should be either 2 or 4')
    end
else
    error('Invalid filter type. Should be either ''HPF'' or ''LPF''')
end

% Create files with filter strings

% Digital filter (MiniDSP):
DSPfilename = ['DSPCoef_f0_' num2str(round(abs(f0)),'%u') '_' type '_n_' num2str(n)];
fidDSP = fopen([DSPfilename '.txt'],'w');
fprintf(fidDSP,'%s',biquad_DSP);
fclose(fidDSP);

% Analog filter (LTspice controlled sources):
LTfilename = ['LTCoef_f0_' num2str(round(abs(f0)),'%u') '_' type '_n_' num2str(n)];
fidLT = fopen([LTfilename '.txt'],'w');
fprintf(fidLT,'%s\n',LaplaceTXT_E1);
if ~isempty(LaplaceTXT_E2)
    fprintf(fidLT,'%s\n','');
    fprintf(fidLT,'%s\n',LaplaceTXT_E2);
end
fclose(fidLT);

end





function LaplaceTXT = biquad2ltspice(b0,b1,b2,a1,a2,fs)

% Write the expression of a biquad digital filter for use in LTspice
% It uses bilinear transformation to get H(s)
% Copy and paste to a voltage controlled voltage generator "value" field.

% Vicente Cutanda Henriquez, 11-2018

format long e

T=1/fs;

z1=['exp(s*' num2str(T,15) ')'];
z2=['exp(2*s*' num2str(T,15) ')'];

zm1=['exp(-s*' num2str(T,15) ')'];
zm2=['exp(-2*s*' num2str(T,15) ')'];

z1b=['(1+s*' num2str(T,15) '/2)/(1-s*' num2str(T,15) '/2)'];
z2b=['(1+2*s*' num2str(T,15) '/2)/(1-2*s*' num2str(T,15) '/2)'];

zm1b=['(1-s*' num2str(T,15) '/2)/(1+s*' num2str(T,15) '/2)'];
zm2b=['(1-2*s*' num2str(T,15) '/2)/(1+2*s*' num2str(T,15) '/2)'];


% Several equivalent expressions can produced:
% LaplaceTXT = sprintf(['Laplace=(' num2str(b0,15) '*' z2 '+' num2str(b1,15) '*' z1 '+' num2str(b2,15) ')/(' z2 '+' num2str(a1,15) '*' z1 '+' num2str(a2,15) ')']);
LaplaceTXT = sprintf(['Laplace=(' num2str(b0,15) '+' num2str(b1,15) '*' zm1 '+' num2str(b2,15) '*' zm2 ')/(1+' num2str(a1,15) '*' zm1 '+' num2str(a2,15) '*' zm2 ')']);
% LaplaceTXT = sprintf(['Laplace=(' num2str(b0,15) '*' z2b '+' num2str(b1,15) '*' z1b '+' num2str(b2,15) ')/(' z2b '+' num2str(a1,15) '*' z1b '+' num2str(a2,15) ')']);
% LaplaceTXT = sprintf(['Laplace=(' num2str(b0,15) '+' num2str(b1,15) '*' zm1b '+' num2str(b2,15) '*' zm2b ')/(1+' num2str(a1,15) '*' zm1b '+' num2str(a2,15) '*' zm2b ')']);

end


function [Q,biquad] = cascade_BW(f0,type,var,dbGain,fs)
% [Q,biquad] = cascade_BW(f0,type,var,dbGain,fs)
%
% cascade_BW finds biquad coefficients for an even order butterworth
% filter type (Q=0.707). Uses the function BQ to calculate coefficients.
% Can also be used to find coefficients for a biquad peaking filter.
%
% f0        = significant frequency
% type      = 'HPF', 'LPF' or 'PEQ'
% var       = Order for 'HPF' and 'LPF', and Q for 'PEQ'
% dbGain    = Gain when 'PEQ' is used.
% fs        = Sampling frequency. If not specified, fs = 96kHz
%
% Example 1: 2nd order LPF at 1kHz 
%   [Q,biquad] = cascade_BW(1000,'LPF',2)
%
% Example 2: PEQ of 10 dB at 100 Hz with Q of 5
%   [Q,biquad] = cascade_BW(100,'PEQ',5,10)




% Run demo
if nargin == 0
    type = 'LPF';
    f0 = 1000;
    n = 4;
    fs = 96e3;
    
% Check input arguements for correct inputs and set correct values.    
elseif nargin > 0
    if strcmp(type,'PEQ')
        if ~exist('dbGain','var')
            error('dbGain not specified!')
        end
        if ~exist('var','var')
            error('Q of peaking filter is not specified!')
        else
            Q = var;
        end
    elseif strcmp(type,'HPF') || strcmp(type,'LPF')
        if ~exist('var','var')
            error('Order n of filter is not specified!')
        elseif mod(var,2)
            error('Order n must be an even number')
        elseif var > 16
            error('Filter order cannot be greater than 16!')
        else 
            n = var;
        end
        if exist('dbGain','var')
            fs = dbGain;
            clear dbGain;
        end
    else
        error('Filter type specifier is typed wrong!')
    end
end

if ~exist('fs','var')
    fs = 96e3;
end


% Calculating coefficients

biquad = sprintf('');
k = 1;
if strcmp(type,'HPF') || strcmp(type,'LPF')
    theta = pi/n;
    c = zeros(ceil(n/2),5);
    i = 1;
    while i < n
        Q(k) = 1/(2*cos(i*theta/2));
        
        [c(k,1),c(k,2),c(k,3),c(k,4),c(k,5)] = BQ(f0,fs,Q(k),type);
        
        new = sprintf('\n biquad%i, \n b0 = %.15f, \n b1 = %.15f, \n b2 = %.15f, \n a1 = %.15f, \n a2 = %.15f, ',k,c(k,1), c(k,2), c(k,3), -c(k,4), -c(k,5));
        biquad = strcat(biquad,new);
        
        i = i+2;
        k = k+1;
    end
elseif strcmp(type,'PEQ')
    [b0,b1,b2,a1,a2] = BQ(f0,fs,Q(k),type,dbGain);
    new = sprintf('\n biquad%i, \n b0 = %.15f, \n b1 = %.15f, \n b2 = %.15f, \n a1 = %.15f, \n a2 = %.15f, ',k,b0,b1,b2,-a1,-a2);
    biquad = strcat(biquad,new);
end
%     i = 0;
%     k = 1;
%     while k <= n
%         if strcmp(type,'HPF') || strcmp(type,'LPF')
%             Q(i+1) = 1/(2*cos(i*theta));
%         end
%
%         [c(i+1,1),c(i+1,2),c(i+1,3),c(i+1,4),c(i+1,5)] = BQ(f0,fs,Q(i+1),type);
%
%         new = sprintf('\n biquad%i, \n b0 = %.15f, \n b1 = %.15f, \n b2 = %.15f, \n a1 = %.15f, \n a2 = %.15f, ',i,c(i+1,1), c(i+1,2), c(i+1,3), -c(i+1,4), -c(i+1,5));
%         biquad = strcat(biquad,new);
%
%         i = i+1;
%         k = k+2;
%     end
end



function [b0,b1,b2,a1,a2] = BQ(f0,fs,Q,type,dbGain)
%BQ calculates the biquad coefficients for PEQ, LPF or HPF filter
%   f0 = Significant frequency
%   fs = Sampling frequency of the DSP (miniDSP uses 96kHz)
%   Q = Quality factor of filter
%   type = Filter type, in string as "LPF", "HPF" or "PEQ".
%   dbGain = only for PEQ filter. Default value = 1
%   Ex. [b0,b1,b2,a0,a1,a2] = biquad_calc(500,48000,0.707,'LPF')

if nargin < 5
    dbGain = 1;
end

omega0 = 2*pi*f0/fs;
alpha = (sin(omega0))/(2*Q);

if type == 'LPF'
    a0 = 1+alpha;
    b0 = ((1-cos(omega0))/2)/a0;
    b1 = (1-cos(omega0))/a0;
    b2 = b0;
    a1 = (-2*cos(omega0))/a0;
    a2 = (1-alpha)/a0;
elseif type == 'HPF'
    a0 = 1+alpha;
    b0 = ((1+cos(omega0))/2)/a0;
    b1 = (-(1+cos(omega0)))/a0;
    b2 = b0;
    a1 = (-2*cos(omega0))/a0;
    a2 = (1-alpha)/a0;
elseif type == 'PEQ'
    A = 10^(dbGain/40);
    a0 = 1+alpha/A;
    b0 = (1+alpha*A)/a0;
    b1 = (-2*cos(omega0))/a0;
    b2 = (1-alpha*A)/a0;
    a1 = (-2*cos(omega0))/a0;
    a2 = (1- alpha/A)/a0;
end
if nargout < 1
    biquad = sprintf('\n biquad%i, \n b0 = %.15f, \n b1 = %.15f, \n b2 = %.15f, \n a1 = %.15f, \n a2 = %.15f, \n ',1,b0, b1, b2, -a1, -a2);
    fprintf(biquad);
end
end


