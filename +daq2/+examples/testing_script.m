function session = testing_script
%
%   session = daq2.examples.testing_script

%{
session = daq2.examples.testing_script
session.stop()

%}

%options = daq2.session.session_options

%Currently a bug for false
USE_PARALLEL = true;
RATE = 10000;

session = daq2.session('ni','use_parallel',USE_PARALLEL);

%-----------------------------------------------------
c1 = @h__createAnalogChan;
c2 = @h__createAnalogOutputChan;

s = struct;

%Inputs
%-------------------------------------------------------
s.stim_mon = c1('stim_mon','stimulus monitor','ai0',-1);
s.stim_select = c1('stim_select','stimulus select','ai1',-1);
s.pres1 = c1('p_blad','bladder pressure','ai2',1000);
s.pres2 = c1('p_prox','proximal urethra pressure','ai3',1000);
s.pres3 = c1('p_mid','mid_urethra_pres','ai4',1000);
s.pres4 = c1('p_dist','distal_urethra_pres','ai5',1000);
s.pres5 = c1('p_vag','vaginal_pres','ai6',1000);

%Post construction setting of property
s.void = c1('void','voided_volume','ai7',1000);
s.void.range = 1;


%Outputs
%--------------------------------------------------------
s.stim_out = c2('stim_out','stimulus output','ao0');


specs = {s.stim_mon s.stim_select s.pres1 s.pres2 s.pres3 ...
            s.pres4 s.pres5 s.void s.stim_out};

% session : daq2.session
raw_session = session.raw_session;
raw_session.rate = RATE;
raw_session.is_continuous = true;
%Specifies at what point to put in more output samples ...
raw_session.write_cb_time = 0.2;
raw_session.write_cb = @(~,~)session.queueOutputData;
%Update rate?????
        
session.addChannelsBySpec(specs);
        
%Stimulator initialization
%-------------------------------------------------------------
%I'd like to simplify this
pulse_width_us = 200;
waveform = daq2.basic_stimulator.getBiphasicWaveform(RATE,pulse_width_us); 
stim_fcn = @daq2.basic_stimulator;

s = struct;
s.default_time_growth = 0.5;
s.params = struct;
s.params.waveform = waveform;
s.params.amp = 0;
DEFAULT_RATE = 10;
s.params.rate = DEFAULT_RATE;
session.addStimulator(stim_fcn,s);


%session.queueOutputData();
session.startBackground();

end

function ai = h__createAnalogChan(short_name,name,port,fs)
ai = daq2.channel.spec.analog_input(short_name,port);
ai.fs = fs;
ai.name = name;
end

function ao = h__createAnalogOutputChan(short_name,name,port)
ao = daq2.channel.spec.analog_output(short_name,port);
ao.name = name;
end