function []=Matlab2LTspice(fr,ComplexResp,LT_filename,Rtype,varargin)

% Matlab2LTspice(fr,ComplexResp,LT_filename,Rtype,d,GenType);
%
% Takes a measurement complex response and produces a text file that is 
% readable by LTspice. See the reference LTspice schematic
% 'Loudspeaker_with_measurement_files.asc' for usage.
%
% This allows including measurement results in the schematic.
%
% A complete simulation will require including two files per loudspeaker
% unit in the LTspice schematic: Input impedance and transfer function.
%
% Input:
%    -fr:             Vector of frequencies, Hz.
%    -ComplexResp:    Vector of complex values of the same length as fr,
%                     e.g., the result of a measurement of input impedance
%                     or transfer function of a loudspeaker.
%    -LT_filename:    String with the name for the output text file. Do not
%                     include extension.
%    -Rtype:          If 1, the data is a transfer function.
%                     If 0, the data is an input impedance.
%    -d:              Measurement distance for phase unwrapping, m 
%                     (If ommitted, d = 0 m). Do not unwrap input impedances.
%    -GenType:        If 1, a Bi/Bv arbitrary source is used in LTspice
%                     (default if omitted).
%                     If 0, a G/H controlled source is used in LTspice.
%                     Both options should work the same in LTspice.
%
% Output: 
% A text file LT_filename.txt is created that can be included in a LTspice
% schematic as a controlled/arbitrary source. You may need to change the
% file name if you combine several units in a system. You will also need to
% change the names of the LTspice labels Pout and Vspkr in the first line
% of the file to match the different label names in the system's circuit.
%
% Note: If the file already exists, it is overwritten.
% 

% 31220 Electroacoustic Transducers, final project.
% Vicente Cutanda Henriquez, Sebastian Tengvall, 10-2018
% Revised VCH 10-2020

d=0;
GenType=1;
if nargin>=5
    d=varargin{1};
    if nargin==6
        GenType=varargin{2};
    end
end

if ~isvector(ComplexResp) || ~isvector(fr) || ~ischar(LT_filename)
    error('Data inputs must be vectors and the filename must be a string')
end


% Check that inputs are column vectors
if isrow(ComplexResp) == 1
    ComplexResp = ComplexResp.';
end
if isrow(fr) == 1
    fr = fr.';
end

if length(fr)~=length(ComplexResp)
    error('The input vectors must be the same length')
end

Nf=size(ComplexResp,1);

% The input impedance is inverted. It must represent input current for 1 V
% excitation in LTspice
if ~Rtype 
    ComplexResp = 1./ComplexResp;
    d=0;    % There is no distance compensation for input impedance
    disp(['Writing input impedance response to data file: ''' LT_filename '.txt'''])
    disp(['Distance compensation is d = 0 m'])
else
    disp(['Writing transfer function response to data file: ''' LT_filename '.txt'''])
    disp(['Distance compensation is d = ' num2str(d) ' m'])
end

% Obtain magnitude in dB and phase in degrees. 
phi_CR_deg = phaseunwrap(angle(ComplexResp)*180/pi,d,fr);grid
CR_f_dB_deg = [fr mag2db(abs(ComplexResp)) phi_CR_deg];

% Create files and add data in proper format.
fidCR = fopen([LT_filename '.txt'],'w');
if Rtype
    if GenType
        fprintf(fidCR,'%s\n','BvTF Pout 0  V=V(Vspkr,0) DB FREQ=  ');
    else
        fprintf(fidCR,'%s\n','ETF Pout 0  FREQ {V(Vspkr,0)}= DB  ');
    end
else
    if GenType
        fprintf(fidCR,'%s\n','BiZin Vspkr 0  I=V(Vspkr,0) DB FREQ= ');
    else
        fprintf(fidCR,'%s\n','GZin Vspkr 0  FREQ {V(Vspkr,0)}= DB ');
    end
end


for nn=1:Nf
    fprintf(fidCR,'+(%4.10E,%4.10E,%4.10E)\n',CR_f_dB_deg(nn,1),CR_f_dB_deg(nn,2),CR_f_dB_deg(nn,3));
end
fclose(fidCR);


figure(10);
subplot(2,1,1)
semilogx(CR_f_dB_deg(:,1),CR_f_dB_deg(:,2),'-k');grid
xlabel('Frequency, Hz');ylabel('dB')
title('Output magnitude');
subplot(2,1,2)
semilogx(CR_f_dB_deg(:,1),CR_f_dB_deg(:,3),'-b');grid
xlabel('Frequency, Hz');ylabel('Phase, deg.')
title('Output phase');

end
