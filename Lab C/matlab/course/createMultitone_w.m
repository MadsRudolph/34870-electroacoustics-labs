function [t,outputSignal,freqN] = createMultitone(fs,startFreq,endFreq,octSteps,freqRes,amp,fb)
% Creates a logaritmic or linear multitone signal and aligns the
%frequencies at a specified frequency resolution. Add extra time for transient respons
% [t,outputSignal,freqIndex] =
% createMultitone(fs,freqStart,freqEnd,octSteps,freqRes,amp,fb)
% fs: Sample frequency
% startFreq: First frequency
% endFreq: Last freqency
% decSteps: Number of frequencies per octave
% freqRes: Frequency resolution in the FFT (Hz/bin). The time is 1/freqRes
% amp: max signal value
% fb : frequency below which a 20 dB /dec boost is applied

T = 1/freqRes;
t = 0:1/fs:T-1/fs;

fc=200;  % frequency below which amplitude is increase with 20 dB/dec


decSteps=octSteps/log10(2);

numFreqlow = ceil(log10(1000/startFreq)*decSteps); % up to 1000 Hz
numFreqhigh = ceil(log10(endFreq/1000)*decSteps); % above 1000 Hz

startFreq_x=1000/10^(numFreqlow/decSteps)

% Find the frequencies
%fspace_unfit = logspace(log10(startFreq),log10(endFreq),numFreq);

% up to  1000 Hz
fspace_low_unfit=1000*logspace(-log10(1000/startFreq_x),0,numFreqlow+1)
% above 1000
fspace_high_unfit=1000*logspace(0,log10(endFreq/1000),numFreqhigh+1);

fspace_unfit=[fspace_low_unfit fspace_high_unfit];

% Find the frequencies and then make sure they align with the FFT
fspace = round(fspace_unfit/freqRes)*freqRes;
freqN = fspace(1);
for n = 2:length(fspace)
    if fspace(n) ~= fspace(n-1)
        if fspace(n)<endFreq 
            freqN = [freqN fspace(n)];
        end
    end
end
freqN
Nf=length(freqN)

% Multisine with random phase
multiSine = 0;
for k = 1:Nf
    randPhase = (2*rand-1)*pi;
    %Making sure that the frequency aligns with the FFT
    a=(freqN(k)+fc)/freqN(k);
    multiSine = multiSine + a*sin(2*pi*freqN(k)*t+randPhase); %Log-step increasing multitone
end

%outputSignal = sqrt(2/Nf)*amp*multiSine;
outputSignal = amp*multiSine/max(abs(multiSine));
    
end

