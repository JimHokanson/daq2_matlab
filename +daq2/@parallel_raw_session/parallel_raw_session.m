classdef parallel_raw_session < handle
    %
    %   Class:
    %   daq2.parallel_raw_session
    %
    %   See Also
    
    properties
        d0 = '------- Internal Props -------'
        perf_mon        %daq2.perf_monitor
        command_window  %Default: daq2.command_window
        options         %NYI - send to parallel worker
        pool
        feval_future
        q_send
        process_error_thrown = false
        data_available_cb
        error_cb
        
        h_tic_send
        h_tic_recv
        h_tic_work_send
        p_daq_struct %Gets set with struct when requested ...
        daq_props
        
     	read_mode = 'auto'
        
        %- auto
        %- time
        %- samples
        write_mode = 'auto'
        
        %Values set by the user ...
        %if mode == 'time' then these can't be empty
        user_read_time
        user_write_time
        
        %NotifyWhenDataAvailableExceeds
        %IsNotifyWhenDataAvailableExceedsAuto
        %NotifyWhenScansQueuedBelow
        %IsNotifyWhenScansQueuedBelowAuto
        
        h_start_tic
    end
    
    properties
        d1 = '--------- DAQ2 Props -------'
        chans = {}
        type
        
        %Format src,event
        read_cb
        %The user function to call 
        d2 = '--------- DAQ Parameters--------'
    end

    properties (Dependent)
        rate
        is_continuous
        read_cb_time
        read_cb_samples
        write_cb_time
        write_cb_samples
    end
    
	properties
        d3 = '--------- DAQ Read-Only Props  --------'
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
    end
    
    %Parameter Methods ========================================
    methods
        function value = get.rate(obj)
            value = obj.daq_props.Rate;
        end
        function set.rate(obj,value)
            %TODO: We should sync the channel specs to this
            %i.e. if the rate changes, update any channels which
            %have the max rate...
            h__sendParam(obj,'Rate',value)
            
            %TODO: If read or write modes are auto or time
            %we need to update params accordingly
            %- like samples ...
            %
            %   Not sure of auto behavior ...
            %   1/10 for read
            %   1/2 for write
            switch obj.read_mode
                case 'auto'
                    %Adjust our internal # for samples
                    %remote will auto adjust
                    obj.daq_props.NotifyWhenDataAvailableExceeds = round(1/10*value);
                case 'time'
                    obj.read_cb_time = obj.user_read_time;
                case 'samples'
                    %No action needed
                otherwise
                    error('Internal code error')
            end
            
            switch obj.write_mode
                case 'auto'
                    %Adjust our internal # for samples
                    %remote will auto adjust
                    obj.daq_props.NotifyWhenScansQueuedBelow = round(1/2*value);
                case 'time'
                    obj.write_cb_time = obj.user_write_time;
                case 'samples'
                    %No action needed
                otherwise
                    error('Internal code error')
            end
        end
        function value = get.is_continuous(obj)
            value = obj.daq_props.IsContinuous;
        end
        function set.is_continuous(obj,value)
            h__sendParam(obj,'IsContinuous',value)
        end
        %get() read/write methods -------------------------------------
        function value = get.read_cb_time(obj)
            %TODO: Run error check on size ...
            %Default format internally is uint64
            value = double(obj.daq_props.NotifyWhenDataAvailableExceeds)/obj.daq_props.Rate;
        end
        function value = get.read_cb_samples(obj)
            value = obj.daq_props.NotifyWhenDataAvailableExceeds;
        end
        function value = get.write_cb_time(obj)
            value = double(obj.daq_props.NotifyWhenScansQueuedBelow)/obj.daq_props.Rate;
        end
        function value = get.write_cb_samples(obj)
            value = obj.h.NotifyWhenScansQueuedBelow;
        end
        %set() read/write methods -------------------------------------
        function set.read_cb_time(obj,value)
            obj.read_mode = 'time';
            obj.user_read_time = value;
            samples = round(value*obj.daq_props.Rate);
            h__sendParam(obj,'NotifyWhenDataAvailableExceeds',samples);
        end
        function set.read_cb_samples(obj,value)
            obj.read_mode = 'samples';
            h__sendParam(obj,'NotifyWhenDataAvailableExceeds',value);
        end
        function set.write_cb_time(obj,value)
            obj.write_mode = 'time';
            obj.user_write_time = value;
            samples = round(value*obj.daq_props.Rate);
            h__sendParam(obj,'NotifyWhenScansQueuedBelow',samples);
        end
        function set.write_cb_samples(obj,value)
            obj.write_mode = 'samples';
            h__sendParam(obj,'NotifyWhenScansQueuedBelow',value);
        end
    end
    
    %Status Methods ===============================================
    methods
      	%Status ==================================
        function value = get.is_running(obj)
            value = obj.daq_props.IsRunning;
        end
        function value = get.n_scans_acquired(obj)
            value = -1;
            %value = obj.h.ScansAcquired;
        end
        function value = get.n_scans_queued(obj)
            value = -1;
            %value = obj.h.ScansQueued;
        end
        function value = get.n_scans_output(obj)
            value = -1;
            %value = obj.h.ScansOutputByHardware;
        end
        function value = get.summary(obj)
            %
            %   By default the Matlab daq object shows a summary, whereas
            %   by default I show the properties. This property exposes
            %   that summary text.
            %
            
            value = 'NYI';
            %This will show properties, but the link won't work
            %value = evalc('obj.h');
            
            %value = evalc('disp(obj.h)');
        end 
    end
    

    
    methods
        function obj = parallel_raw_session(type,perf_mon,command_window)
            %Max amount of time to wait for the parallel process
            %to launch and to send a queue back to this process
            MAX_WAIT_PARALLEL_STARTUP = 5; %seconds
            
            obj.daq_props = struct;
            obj.perf_mon = perf_mon;
            obj.command_window = command_window;
            
            %Requires parallel pool toolbox
            %------------------------------
            obj.pool = gcp;
            
            q_receive = parallel.pool.DataQueue;
            L1 = afterEach(q_receive, @(data) obj.initQSend(data));
            
            %Launch the parallel daq session
            %------------------------------------------------
            fh = @daq2.parallel_session_worker;
            obj.feval_future = parfeval(gcp,fh,0,type,q_receive);
            
            %now obtain the q
            %----------------------------
            %- we need to wait for the worker to start and for it to send
            %data back to us
            h_tic = tic;
            while (toc(h_tic) < MAX_WAIT_PARALLEL_STARTUP && isempty(obj.q_send))
                pause(0.1);
            end
            
            if isempty(obj.q_send)
                %TODO: Output to command window
                %Since we can fail in the constructor, we should have the
                %constructor wrapped in a static creation method
                error('Unable to receive queue back from parallel function');
            elseif ~isa(obj.q_send,'parallel.pool.PollableDataQueue')
                error('Received data not of expected type')
            end
            
            delete(L1);
            afterEach(q_receive, @(data) obj.receiveEvent(data));
            
            %Syncing DAQ Props
            %----------------------------------------------
            h__sendCmd(obj,'struct');
            
            h_tic = tic;
            while (toc(h_tic) < MAX_WAIT_PARALLEL_STARTUP && isempty(obj.p_daq_struct))
                pause(0.1);
            end
            
            if isempty(obj.p_daq_struct)
                error('Unable to receive session struct back from parallel function');
            end
            
            obj.daq_props = obj.p_daq_struct;
        end
        function initQSend(obj,data)
            %Callback only for receiving q_send which allows
            %us to send messages to the worker
            obj.q_send = data;
        end
        %==================================================================
        %   Receiving events
        %==================================================================
        function receiveEvent(obj,s)
            %
            %   Commands
            %   --------
            %   'data_available' - data available
            %       .src = []
            %       .data = Modified data
            %   	TriggerTime: 7.3705e+05
            %              Data: [1000×10 double]
            %        TimeStamps: [1000×1 double]
            %            Source: []
            %         EventName: 'DataAvailable'
            %   'daq_error' - error from the DAQ
            %       .src = []
            %       .data = Modified Data
            %           Error: [1×1 MException]
            %          Source: []
            %       EventName: 'ErrorOccurred'
            %   'struct'
            %       .data - session as a struct
            %   'error' - error in the parallel code caught by try/catch
            %       .data - ME
            %
            %   See Also:
            %   daq2.parallel_session_worker
            
            obj.h_tic_recv = tic;
            obj.h_tic_work_send = s.send_time;
            
            switch s.cmd
                case 'data_available'
                    if ~isempty(obj.data_available_cb)
                        obj.data_available_cb(s.src,s.data);
                    end
                case 'daq_error'
                    %TODO: Add on to command window that we have a problem
                    %from the daq
                    obj.daq_props.IsRunning = false;
                    if ~isempty(obj.error_cb)
                        try
                            ME = s.data.Error;
                            obj.error_cb(ME);
                            assignin('base','last_ME_from_cb1',ME);
                        catch ME
                        	assignin('base','last_ME_from_cb2',ME);
                            fprintf(2,'An error occurred, see "last_ME_from_cb2" in the base workspace\n');
                        end
                    else
                        error('DAQ ERROR occurred')
                    end
                case 'error'
                    %TODO: Add on to command window that we have a problem
                    %from the parallel code ...
                    obj.daq_props.IsRunning = false;
                    if ~isempty(obj.error_cb)
                        try
                            ME = s.data;
                            obj.error_cb(s.data);
                            assignin('base','last_ME_from_cb1',ME);
                        catch ME
                            assignin('base','last_ME_from_cb2',ME);
                            fprintf(2,'An error occurred, see "last_ME_from_cb2" in the base workspace\n');
                        end
                    else
                        error('Parallel code error occurred')
                    end
                    %?? throw otherwise?????    
                case 'struct'
                    obj.p_daq_struct = s.data;
                otherwise
                    errro('Internal code error, missing command: %s',s.cmd);
            end
        end
        %==================================================================
        function s = struct(obj)
            s = struct;
            s.VERSION  = 1;
            s.STRUCT_DATE = now;
            s.TYPE = 'daq2.parallel_raw_session';
        end
        function delete(obj)
            if ~isempty(obj.feval_future) && isvalid(obj.feval_future)
                cancel(obj.feval_future);
            end
        end
    end
    
    %Setup ================================================================
    methods
        function [ch,idx] = addAnalogInput(obj,dev_id,daq_port,meas_type,other)
            
            ch = [];
            idx = [];
            
            s = struct;
            s.cmd = 'add_analog_input';
            s.id = dev_id;
            s.port = daq_port;
            s.type = meas_type;
            s.other = other;
            
            h__send(obj,s)
        end
        function [ch,idx] = addAnalogOutput(obj,dev_id,daq_port,meas_type)
            ch = [];
            idx = [];
            
            s = struct;
            s.cmd = 'add_analog_output';
            s.id = dev_id;
            s.port = daq_port;
            s.type = meas_type;
            
            h__send(obj,s)
        end
        function addListener(obj,name,function_handle)
            %
            
            switch name
                case 'DataAvailable'
                    obj.data_available_cb = function_handle;
                case 'ErrorOccurred'
                    obj.error_cb = function_handle;
                case 'DataRequired'
                    %If so, shouldn't use parallel session
                    error('Data required callback not supported')
                otherwise
                    error('Unrecognized listener type')
            end
            
            %No need to modify the session, we just need to handle
            %these when we receive ...
            %obj.h.addlistener(name,function_handle);
        end
    end
    
    %Control Methods ============================================
    methods
       	function startBackground(obj)
            h__sendCmd(obj,'start')
            obj.daq_props.IsRunning = true;
            obj.h_start_tic = tic;
        end
        function stop(obj)
            h__sendCmd(obj,'stop')
            obj.daq_props.IsRunning = false;
        end
       	function output = getElapsedSessonTime(obj)
           %This is currently not very accurate ... 
           output = toc(obj.h_start_tic);
        end
    end
    
 	%Setup ================================================================
    methods
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
            %Note this is not specific to the session
            %and thus we don't need to ask the parallel worker
            devices = daq.getDevices();
        end
    end
    
    %Parallel Writing Specific ===========================
    methods
        function addStimulator(obj,stim_fcn,params)
            s = struct;
            s.cmd = 'construct_stim';
            s.stim_fcn = stim_fcn;
            s.data = params;
            h__send(obj,s);
        end
        function queueMoreData(obj,n_seconds_add)
            s = struct;
            s.cmd = 'q_data';
            s.data = n_seconds_add;
            h__send(obj,s);
        end
        function updateStimParams(obj,s)
         	s2 = struct;
            s2.cmd = 'update_stim';
            s2.data = s;
            h__send(obj,s2);
        end
    end
    
    %Debugging ===============
    methods
        function requestSessionStruct(obj)
            h__sendCmd(obj,'struct');
        end
    end
end

function h__sendParam(obj,param,value)
    s = struct;
    s.cmd = 'update_prop';
    s.name = param;
    s.value = value;
    h__send(obj,s);
    obj.daq_props.(param) = value;
    
end

function h__sendCmd(obj,cmd)
    s = struct;
    s.cmd = cmd;
    h__send(obj,s)
end

function h__send(obj,s)
obj.h_tic_send = tic;
if isempty(obj.feval_future.Error)
    obj.q_send.send(s);
elseif ~obj.process_error_thrown
    obj.command_window.logErrorMessage(...
        'Parallel writing process failed with the following message: %s',...
        obj.feval_future.Error.message);
    obj.process_error_thrown = true;
end
end

function h__updateProp(obj,name,value)

end
function h__getProp(obj,name,value)

end

