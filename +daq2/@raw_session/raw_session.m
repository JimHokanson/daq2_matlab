classdef raw_session < handle
    %
    %   daq2.raw_session
    
    properties (Hidden)
        chans = {}
        type
        %1 - analog input
        %2 - analog output
        %...
    end
    
    properties
        h
        cmd_window
    end
    
    properties
        d1 = '---------   Parameters --------------'
    end
    %https://www.mathworks.com/help/daq/ref/daq.createsession.html#outputarg_session
    properties (Dependent)
        %Parameters ==================================
        rate
        is_continuous
        
        %TODO: Eventually these should be listeners
    end
    properties
        %Format src,event
        read_cb
        
        %Nothing currently ...
        write_cb
    end
    
    properties (Dependent)
        read_cb_time
        read_cb_samples
        write_cb_time
        write_cb_samples
    end
    
    properties
        d2 = '-----  Status Properties, Read Only   --------'
        n_analog_inputs = 0
        n_analog_outputs = 0
        n_digital_inputs = 0
        n_digital_outputs = 0
    end
    
    properties (Dependent)
        
        %Status =================================
        is_running
        
        %Input -----------------------
        n_scans_acquired
        
        %Output ----------------------
        n_scans_queued
        n_scans_output
        
        summary
        
        %Read Only =======================================
        
        %                          AutoSyncDSA: false
        %                        NumberOfScans: 1000
        %                    DurationInSeconds: 1
        % IsNotifyWhenDataAvailableExceedsAuto: true
        %     IsNotifyWhenScansQueuedBelowAuto: true
        %               ExternalTriggerTimeout: 10
        %                       TriggersPerRun: 1
        %                             UserData: ''
        %                               Vendor: National Instruments
        %                             Channels: ''
        %                          Connections: ''
        %                            IsRunning: false
        %                            IsLogging: false
        %                               IsDone: false
        %          IsWaitingForExternalTrigger: false
        %                    TriggersRemaining: 1
        %                            RateLimit: ''
    end
    
    methods
        %Parameters ============================
        function value = get.rate(obj)
            value = obj.h.Rate;
        end
        function set.rate(obj,value)
            %TODO: We should sync the channel specs to this
            %i.e. if the rate changes, update any channels which have the
            %max rate...
            obj.h.Rate = value;
        end
        function value = get.is_continuous(obj)
            value = obj.h.IsContinuous;
        end
        function set.is_continuous(obj,value)
            obj.h.IsContinuous = value;
        end
        function value = get.read_cb_time(obj)
            %TODO: Run error check on size ...
            %Default format internally is uint64
            value = double(obj.h.NotifyWhenDataAvailableExceeds)/obj.h.Rate;
        end
        function set.read_cb_time(obj,value)
            samples = round(value*obj.h.Rate);
            obj.h.NotifyWhenDataAvailableExceeds = samples;
        end
        function value = get.write_cb_time(obj)
            value = double(obj.h.NotifyWhenScansQueuedBelow)/obj.h.Rate;
        end
        function set.write_cb_time(obj,value)
            samples = round(value*obj.h.Rate);
            obj.h.NotifyWhenScansQueuedBelow = samples;
        end
        
        function value = get.read_cb_samples(obj)
            value = obj.h.NotifyWhenDataAvailableExceeds;
        end
        function set.read_cb_samples(obj,value)
            obj.h.NotifyWhenDataAvailableExceeds = value;
        end
        function value = get.write_cb_samples(obj)
            value = obj.h.NotifyWhenScansQueuedBelow;
        end
        function set.write_cb_samples(obj,value)
            obj.h.NotifyWhenScansQueuedBelow = value;
        end
        
        
        
        
        
        
        
        
        
        %Status ==================================
        function value = get.is_running(obj)
            value = obj.h.IsRunning;
        end
        function value = get.n_scans_acquired(obj)
            value = obj.h.ScansAcquired;
        end
        function value = get.n_scans_queued(obj)
            value = obj.h.ScansQueued;
        end
        function value = get.n_scans_output(obj)
            value = obj.h.ScansOutputByHardware;
        end
        function value = get.summary(obj)
            %This will show properties, but the link won't work
            %value = evalc('obj.h');
            value = evalc('disp(obj.h)');
        end
    end
    
    %Constructor ==========================================================
    methods
        function obj = raw_session(type,cmd_window)
            %
            %   This should not be called directly. Call daq2.session
            %   instead
            %
            %   obj = daq2.raw_session(type)
            %
            %   obj = daq2.raw_session('ni')
            
            %TODO: This might all be in parallel at some point
            
            obj.h = daq.createSession(type);
            obj.cmd_window = cmd_window;
        end
    end
    methods
        function startBackground(obj)
            obj.h.startBackground();
        end
        function stop(obj)
            obj.h.stop();
        end
        function queueOutputData(obj,data)
            obj.h.queueOutputData(data);
        end
        function addChannelsBySpec(obj,chan_specs)
            %
            %   Form:
            %   - array
            %   - cell
            
            if ~iscell(chan_specs)
                chan_specs = num2cell(chan_specs);
            end
            
            available_devices = obj.getAvailableDevices;
            
            for i = 1:length(chan_specs)
                chan_spec = chan_specs{i};
                chan = chan_spec.addToDAQ(obj,available_devices);
                switch class(chan)
                    case 'daq2.channel.analog_input_channel'
                        obj.n_analog_inputs = obj.n_analog_inputs + 1;
                        l_type = 1;
                    case 'daq2.channel.analog_output_channel'
                        obj.n_analog_outputs = obj.n_analog_outputs + 1;
                        l_type = 2;
                    otherwise
                        error('Unrecognized class')
                end
                
                obj.chans{end+1} = chan;
                obj.type(end+1) = l_type;
            end
        end
        function ai_chans = getAnalogInputChans(obj)
            temp = obj.chans(obj.type == 1);
            ai_chans = [temp{:}];
        end
        function devices = getAvailableDevices(obj)
            devices = daq.getDevices();
        end
        function delete(obj)
            try %#ok<TRYNC>
                obj.h.stop();
            end
            try %#ok<TRYNC>
                %disp('wtf1')
                release(obj.h);
                %disp('wtf2')
            end
        end
        %TODO: Expose the other adding functions to the user ...
    end
end
