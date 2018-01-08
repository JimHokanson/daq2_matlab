classdef basic_stimulator < handle
    %
    %   Class:
    %   daq2.basic_stimulator
    %
    %   TODO: Describe the stimulator interface ...
    %
    %   This stimulator has the following functionality:
    %   1) dynamic population of stimulus based on amplitude and rate
    %   2) A fixed amplitude and rate with buildup period ...
    
    properties
        fs
        
        min_queue_samples
        %The # of samples we try and have queued at all points in time
        
        default_sample_growth
        %How many samples to add when we add more samples ...
        
        default_time_growth
        %Same as above, but as time
        
        waveform
        %Stimulus waveform
        
        default_rate
        default_amp
        rate
        pulse_dt
        amp
        
        %Pulse Generation State
        %---------------------------------
        hanging_stim_array
        %We could get rid of this if we adjust the # of samples to add
        %based on whether or not this would get created
        %
        %i.e. if would be created, expand output slightly
        %otherwise, don't expand the output
        
        last_pulse_start_sample = 0
        n_writes = 0
        n_samples_written = 0
    end
    
    methods (Static)
        function waveform = getBiphasicWaveform(fs,pulse_width_us)
            %
            %   waveform = daq2.basic_stimulator.getBiphasicWaveform(fs,pulse_width_us)
            %
            %   Example
            %   -------
            %   fs = 10000;
            %   pulse_width_us = 200;
            %   waveform = daq2.basic_stimulator.getBiphasicWaveform(fs,pulse_width_us)
            %   waveform = [-1 -1 1 1];
            
            pulse_width_s = pulse_width_us/1e6;
            pulse_width_samples = pulse_width_s*fs;
            temp = ceil(pulse_width_samples);
            if (temp ~= pulse_width_samples)
                error('Warning adjustment not yet handled')
            end
            
            n = pulse_width_samples;
            waveform = [-1*ones(1,n) ones(1,n)];
        end
    end
    methods
        function obj = basic_stimulator(fs,min_queue_samples,s)
            %
            %   s
            %       .default_time_growth
            %       .params (Contents are stimulator specific)
            %           .waveform
            %           .amp
            %           .rate
            %
            %   The idea with this design of s is that all stimulators
            %   need 'default_time_growth' but that a field 'params'
            %   is specific to the stimulator
            %
            
            obj.fs = fs;
            obj.min_queue_samples = min_queue_samples;
            obj.default_time_growth = s.default_time_growth;
            obj.default_sample_growth = round(obj.default_time_growth*fs);
            
            params = s.params;
            obj.waveform = params.waveform;
            h__setRate(obj,params.rate)
            obj.amp = params.amp;
            obj.default_rate = params.rate;
            obj.default_amp = params.amp;
            
            obj.init();
        end
        function data = init(obj)
            obj.n_writes = 0;
            obj.n_samples_written = 0;
            obj.last_pulse_start_sample = 0;
            obj.hanging_stim_array = [];
            
            h__setRate(obj,obj.default_rate)
            obj.amp = obj.default_amp;
            
            n_samples_init = obj.min_queue_samples + obj.default_sample_growth;
            data = zeros(n_samples_init,1);
        end
        function output = getData(obj,n_seconds_add)
            %
            %   This code is responsible for updating the ongoing
            %   stimuluation based on the specified amp and rate.
            
            if nargin == 1
                n_samples_add = obj.default_sample_growth;
            else
                n_samples_add = round(n_seconds_add*obj.fs);
            end
            
            first_sample_global = obj.n_samples_written + 1;
            next_p_global = obj.last_pulse_start_sample + obj.pulse_dt;
            next_p_local = next_p_global - first_sample_global + 1;
            
            if next_p_local < 1
                %We might have adjusted the rate to make this the case'
                next_p_local = obj.pulse_dt;
            end
            
            output = zeros(n_samples_add,1);
            obj.n_samples_written = obj.n_samples_written + n_samples_add;
            obj.n_writes = obj.n_writes + 1;
            
            %1) Handling any hanging values from last run
            %----------------------------------------------------------
            if ~isempty(obj.hanging_stim_array)
                n_hanging = length(obj.hanging_stim_array);
                %TODO: This might not always be long enough ...
                %   - long waveform, short n_samples_add
                output(1:n_hanging) = obj.hanging_stim_array;
                obj.hanging_stim_array = [];
            end
            
            %2) Now we generate starts for this section
            %----------------------------------------------------------
            pulse_start_I = next_p_local:obj.pulse_dt:n_samples_add;
            
            if isempty(pulse_start_I)
                return
            end
            
            %3) Filling in the waveform at each point
            %-------------------------------------------------
            wave_local = obj.amp.*obj.waveform;
            n_samples_waveform = length(wave_local);
            
            %Note, we will never exceed the array
            %except on the last pulse as this would require
            %the waveform to be larger than the pulse_dt
            for i = 1:(length(pulse_start_I)-1)
                start_I = pulse_start_I(i);
                end_I = start_I + n_samples_waveform - 1;
                output(start_I:end_I) = wave_local;
            end
            
            %4) Handling of the last pulse
            %--------------------------------------------------------------
            last_pulse_start_I = pulse_start_I(end);
            last_pulse_end_I = last_pulse_start_I + n_samples_waveform - 1;
            if last_pulse_end_I > length(output)
                n_keep = length(output) - last_pulse_start_I + 1;
                output(last_pulse_start_I:end) = wave_local(1:n_keep);
                obj.hanging_stim_array = wave_local(n_keep+1:end);
            else
                output(last_pulse_start_I:last_pulse_end_I) = wave_local;
            end
            
            if ~isempty(pulse_start_I)
                obj.last_pulse_start_sample = last_pulse_start_I + first_sample_global - 1;
            end
        end
        function data = updateParams(obj,is_running,s)
            %
            %   Cases to handle:
            %   1) Update rate & amp
            %   2) Generate fixed stimulus
            %
            %   Inputs
            %   -------
            %    s : struct
            %        Contents are stimulator specific.
            %
            %       .mode == 1
            %           .rate
            %           .amp
            %       .mode == 2 (this will be run immediately)
            %           .duration
            %           .rate
            %           .amp
            %           .ramp_time
            %           .terminal_amp
            %           .terminal_rate
            %
            %           IMPORTANT: RESET rate to 1 and amp to 0 after mode2
            
            %TODO: Expose this to the user ...
            START_AMP_PCT_FOR_RAMP = 0.33;
            
            data = [];
            if s.mode == 1
                obj.amp = s.amp;
                h__setRate(obj,s.rate)
            elseif s.mode == 2
                %TODO: We may wish to make this dynamic ...
                %i.e. populate a buffer and populate it out over time
                %- this would allow for interuppting the buffer
                
                %Gen pulse times (& amps for ramp up)
                %---------------------------------------------
                dt = 1/s.rate;
                if s.ramp_time ~= 0
                    total_duration = s.ramp_time + s.duration;
                    pulse_times = dt:dt:total_duration;
                    I = find(pulse_times > s.ramp_time,1);
                    
                    start_amp = START_AMP_PCT_FOR_RAMP*s.amp;
                    amps = linspace(start_amp,s.amp,I);
                else
                    I = 0;
                    pulse_times = 0:dt:s.duration;
                end
                
                
                %Distribute pulses to the output data
                %---------------------------------------------
                norm_wave_local = obj.waveform;
                std_wave_local = s.amp*norm_wave_local;
                n_samples_waveform = length(norm_wave_local);
                
                pulse_samples = round(pulse_times*obj.fs);
                n_samples_total = pulse_samples(end) + n_samples_waveform - 1;
                data = zeros(n_samples_total,1);
                
                for i = 1:I
                    start_I = pulse_samples(i);
                    end_I = start_I + n_samples_waveform - 1;
                    data(start_I:end_I) = amps(i)*norm_wave_local;
                end
                
                for i = (I+1):length(pulse_samples)
                    start_I = pulse_samples(i);
                    end_I = start_I + n_samples_waveform - 1;
                    data(start_I:end_I) = std_wave_local;
                end
                
                %Update state
                %------------------------------------------------------
                obj.n_samples_written = obj.n_samples_written + 1;
                obj.n_writes = obj.n_writes + 1;
                obj.last_pulse_start_sample = obj.n_samples_written - n_samples_waveform + 1;
                
                %Behavior following stim
                %-------------------------------------------------------
                if isfield(s,'terminal_amp')
                    obj.amp = s.terminal_amp;
                end
                
                if isfield(s,'terminal_rate')
                    obj.rate = s.terminal_rate;
                end
                
            else
                error('Stim mode not recognized')
            end
        end
    end
end

function h__setRate(obj,new_rate)
%TODO: Rate can't run into pulse_width
dt = 1./new_rate;
samples_per_dt = dt*obj.fs;
samples_rounded = round(samples_per_dt);
obj.pulse_dt = samples_rounded;
obj.rate = new_rate;
end

