classdef basic_stimulator < handle
    %
    %   Class:
    %   daq2.basic_stimulator
    
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
            if ~isempty(obj.hanging_stim_array)
                n_hanging = length(obj.hanging_stim_array);
                %TODO: This might not always be long enough ...
                %   - long waveform, short n_samples_add
                output(1:n_hanging) = obj.hanging_stim_array;
                obj.hanging_stim_array = [];
            end
            
            %2) Now we generate starts for this section
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
            try
            for i = 1:(length(pulse_start_I)-1)
                start_I = pulse_start_I(i);
                end_I = start_I + n_samples_waveform - 1;
                output(start_I:end_I) = wave_local;
            end
            catch ME
                error('s %d   e %d   i %d len %d, len2 %d',...
                    start_I,end_I,i,length(pulse_start_I),length(output));
            end
            
            %Handling of the last pulse -----------------------------------
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
            %   This is stimulator specific ...
            %
            %   Cases to handle:
            %   1) Update rate & amp
            %   2) Generate fixed stimulus
            %
            %
            %   s : struct (Specific to this class)
            %       .mode == 1
            %           .rate
            %           .amp
            %       .mode == 2 (this will be run immediately)
            %           .duration
            %           .rate
            %           .amp
            %           .build_time
            %           IMPORTANT: RESET rate to 1 and amp to 0 after mode2
            
            data = [];
            if s.mode == 1
                obj.amp = s.amp;
                h__setRate(obj,s.rate)
            else
                error('Not yet implemented')
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
