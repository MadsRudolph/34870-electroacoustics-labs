%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ventbox function%
% Authur: Niels Iversen %
% Institutuion: Technical Univesity of Denmark %
% This function takes the resonance frequency fs, the total Q factor Qts,
% the equivalent volume Vas and QL and returns a proposed alignment. 
% The box quality factor QL, related to the leakage losses, must be an
% integer between 5-20.

function [alpha,q,h,fb,Vab,fl] = ventbox(fs,Qts,Vas,QL)
    
    % Values in Qts_arr has been calculated in butterworth_sandbox.m
    Qts_arr = [0.414400254736171 0.408753996066360 0.404814247463614 0.401908917889607 0.399677888615746 0.397910820210423 0.396476617156541 0.395289321905426 0.394290227567675 0.393437872028687 0.392702139200172 0.392060626505485 0.391496323953853 0.390996083661586 0.390549582616910 0.390148602685496;];
    
    if Qts > Qts_arr(QL-4)
       [alpha,q,h,fb,Vab,fl] = cheby2(fs,Qts,Vas,QL); 
    end
    
    if Qts < Qts_arr(QL-4)
       [alpha,q,h,fb,Vab,fl] = QB3(fs,Qts,Vas,QL);
    end