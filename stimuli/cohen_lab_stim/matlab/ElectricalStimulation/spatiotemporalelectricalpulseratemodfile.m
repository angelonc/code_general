%
%
%function []=spatiotemporalelectricalpulseratemodfile(FileHeader,LambdaMax,fm,Trefractory,PW,PulseType,ChArray,Fs,M,MaxAmp,MaxdB,AmpDist,NB,seed)
%
%       FILE NAME       : SPATIO TEMPORAL ELECTRICAL PULSE RATE MOD
%       DESCRIPTION     : Spatio temporal electrical stimulation pattern
%                         across 16 channels. Uses poisson pulse rate
%                         modulated impulse train for each channel. Saves
%                         pulse train sequence into sequential files.
%
%       FileHeader      : File name header (No extension)
%       LambdaMax       : Maximum pulese rate (Hz)
%       fm              : Maximum modulation rate (Hz)
%       Trefractory     : Refractory interval for pulse train (msec)
%       PW              : Pulse width (micro sec)
%       PulseType       : Pulse type, MonoPhasic (1) or ByPhasic (2)
%       ChArray         : Array containing the electrode channels to
%                         provide stimulation. "0" designates no
%                         stimulation while "1" designates stimulation is
%                         on.
%       Fs              : Sampling Frequency for electrical stimulation
%                         signal (Hz)
%       M               : Number of time samples
%       MaxAmp          : Maximum voltage amplitude in Volts
%       MaxdB           : Used for 'Log' amp distribution. Peak to peak
%                         range in dB
%       AmpDist         : Pulse amplitude distribution 
%                        'Lin' - Linear uniformly distributed 
%                        'Log' - Log uniformly distributed (i.e., in dB)
%                        (Default == 'Log')
%       NB              : Buffer size. Used to segment the files for double
%                         buffering on the TDT system (IZ2-32)
%                         (Default = 524288)
%       seed            : Seed for random number generator
%                         (Default = 0)
%
%RETURNED VARIABLES
%
%       No returned values. Saves data to file.
%
% (C) Monty A. Escabi, June 2011
%
function []=spatiotemporalelectricalpulseratemodfile(FileHeader,LambdaMax,fm,Trefractory,PW,PulseType,ChArray,Fs,M,MaxAmp,MaxdB,AmpDist,NB,seed)

%Input arguments
if nargin<11
    MaxdB=40;    %Not really used when nargin<6
end
if nargin<12
    AmpDist='Log';
end
if nargin<13
    NB=524288;
end
if nargin<14
    seed=0;
end

%Generating Pulse
PW=PW*1E-6;
NP=round(PW*Fs);
if PulseType==1
    P=[ones(1,NP)];                 %Monophasic
else
    P=[ones(1,NP) -ones(1,NP)];     %Byphasic
end

%Force the stimulus length to be an integer multiple of the buffer
M=ceil(M/NB)*NB;

%Generating Electrical Stimulation Signal
for k=1:length(ChArray)
   
    if ChArray(k)==1
        
        %Generating spatiotemporal envelope
        T=M/Fs;
        Et=noiseunifh(0,fm,Fs,M,seed+k+length(ChArray));
 
        %Choosing amplitude distribution
        if strcmp(AmpDist,'Lin')
            Et=Et*LambdaMax;
        elseif strcmp(AmpDist,'Log')
            Et=10.^((MaxdB.*Et-MaxdB)/20)*LambdaMax;
        end

        %Pulse rate modulation
        spet=poissongen(Et,Fs,Fs,Trefractory,seed+k);
        St=spet2impulse(spet,Fs,Fs,T)/Fs*MaxAmp;

        %Adding Pulse
        St=conv(St,P);
        St=St(1:M);
        
    else
        %Channel is off
        St=zeros(1,M);
        Et=zeros(1,M);
    end
    
    %Saving to temporary files
    f=['save TEMPFILEChan' num2str(k) ' St Et' ];
    eval(f)
      
end

%Stimulus Parameters
ParamList.LambdaMax=LambdaMax;
ParamList.fm=fm;
ParamList.Trefractory=Trefractory;
ParamList.ChArray=ChArray;
ParamList.Fs=Fs;
ParamList.M=M;
ParamList.MaxAmp=MaxAmp;
ParamList.MaxdB=MaxdB;
ParamList.AmpDist=AmpDist;
ParamList.NB=NB;
ParamList.seed=seed;

%Segmenting into stimulus blocks half the buffer size
N=NB/2;         %Half the buffer size
L=M/N;          %Number of buffer segments
for l=1:L
   
    for k=1:length(ChArray)
        
        %Loading channel array
        f=['load TEMPFILEChan' num2str(k)];
        eval(f)
        
        %Segenting stimulus into buffer blocks
        S(k,:)=St(N*(l-1)+(1:N));
        E(k,:)=Et(N*(l-1)+(1:N));
        
    end
    
    %Saving data for each block
    S=sparse(S);
    f=['save ' FileHeader '_Block' int2strconvert(l,4) ' S E ParamList' ];
    eval(f)
end

%Removing Temporary Files
if isunix
    !rm TEMPFILE*.mat
else
    !del TEMPFILE*.mat
end