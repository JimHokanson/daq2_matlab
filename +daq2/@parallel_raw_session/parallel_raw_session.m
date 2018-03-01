classdef parallel_raw_session < handle
    %
    %   Class:
    %   daq2.parallel_raw_session
    %
    %   This class is a wrapper around the DAQ session. It however
    %   does not hold an instance of the session, but rather communicates
    %   with a parallel worker that holds the session.
    %
    %   The parallel worker allows for updating outputs independently
    %   of the client.
    %
    %   See Also
    %   --------
    %   daq2.raw_session
    %   daq2.parallel_session_worker
    
    properties
        d0 = '------- Internal Props - Don''t Modify -------'
        session_type
        perf_mon        %daq2.perf_monitor
        command_window  %Default: daq2.command_window
        options         %NYI - send to parallel worker
        feval_future
        q_send
        process_error_thrown = false
        data_available_cb
        error_cb
        
        h_tic_send
        h_tic_recv
        h_tic_work_send
        
        p_daq_struct %Gets set with struct when requested ...
        %See requestSessionStruct()
        
        p_perf %structure that gets populated with performance information
        %when requested.
        %See summarizePerfomance()
        
        daq_props %struct
        %This is our local copy of all the daq props ...
        
        %Read/Write Rate Settings
        %--------------------------------------------------
        %These properties allow us to specify read and write
        %times as either samples (default) or as times (somthing I think
        %is more useful). This however requires keeping track of what
        %we're doing so that if the rate changes we can update 
        %the wait times appropriately.
        %
        %Example of previous bug:
        %- User: Set read to every 0.5 seconds
        %- Internally set read to approprate # of samples based on rate
        %- User: Change rate
        %- Internally, # of samples no longer reflects 0.5 seconds
        %
        %See: https://github.com/JimHokanson/daq2_matlab/issues/1
        
     	read_mode = 'auto'
        %This should not be updated
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
        %--------------------------------------------------
        
        n_errors_thrown = 0 %NOT YET IMPLEMENTED
        %This is a work in progress. I had downloaded a corrupt mex file
        %and I couldn't quit. I think what we want is:
        %1) Display error info for the first error
        %2) After so many errors (like 100, just stop the session)
        %       The # should be an optional input
        %
        %https://github.com/JimHokanson/daq2_matlab/issues/7
        
        h_start_tic
        %Used to monitor elapsed time. Gets set when the background process
        %starts. This time is currently only approximate to the start time.
    end
    
    properties
        d1 = '--------- DAQ2 Props -------'
        chans = {}
        %Added channels
        
        chan_types
        
        %Format src,event  - this may be out of date
        read_cb
        
        write_cb
        %The user function to call 
        d2 = '----- Modifiable DAQ Parameters ------'
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
            
            %Change the actual rate
            h__sendParam(obj,'Rate',value)
            
            %Update the notification times based upon our rules
            %------------------------------------------------------
            switch obj.read_mode
                case 'auto'
                    %Adjust our internal # for samples remote will auto adjust
                    %
                    %   Default = 0.1 seconds
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
                    %Adjust our internal # for samples remote will auto adjust
                    %
                    %   Default = 0.5 seconds
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
            value = double(obj.daq_props.NotifyWhenScansQueuedBelow);
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
        
        %TODO: Implement these (Low priority)
        %These are going to be difficult to get and will always
        %have some noticeable delay
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
    
    %Constructor ==========================================================
    methods
        function obj = parallel_raw_session(type,perf_mon,command_window)
            %Max amount of time to wait for the parallel process
            %to launch and to send a queue back to this process
            MAX_WAIT_PARALLEL_STARTUP = 5; %seconds
            
            obj.session_type = type;
            obj.daq_props = struct;
            obj.perf_mon = perf_mon;
            obj.command_window = command_window;
            
            q_receive = parallel.pool.DataQueue;
            L1 = afterEach(q_receive, @(data) obj.initQSend(data));
            
            %Launch the parallel daq session
            %------------------------------------------------
            fh = @daq2.parallel_session_worker;
            obj.feval_future = parfeval(gcp,fh,0,type,q_receive);
            
            %Now obtain the queue
            %-------------------------------------------------
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
            
            %Move the callback to the main callback now that we have the 
            delete(L1);
            afterEach(q_receive, @(data) obj.receiveEvent(data));
            
            %Syncing DAQ Props
            %--------------------------------------------------------------
            h__sendCmd(obj,'struct');
            
            h_tic = tic;
            while (toc(h_tic) < MAX_WAIT_PARALLEL_STARTUP && isempty(obj.p_daq_struct))
                pause(0.1);
            end
            
            if isempty(obj.p_daq_struct)
                %We used to get a long wait due to slow daq enumeration ...
                %elapsed_time = toc(obj.h_tic_send) - toc(obj.h_tic_recv)
                error('Unable to receive session struct back from parallel function');
            end
            
            obj.daq_props = obj.p_daq_struct;
        end
    end
    
    %Core Methods =========================================================
    methods
        function initQSend(obj,data)
            %Callback only for receiving q_send which allows
            %us to send messages to the worker
            obj.q_send = data;
        end
        %==================================================================
        %                       Receiving events
        %==================================================================
        function receiveEvent(obj,s)
            %
            %   Commands from the parallel worker
            %   ------------------------------------------------------
            %   'data_available' - data available
            %
            %           This will likely change ...
            %       .src = []
            %       .data = Modified data
            %   	TriggerTime: 7.3705e+05
            %              Data: [1000×10 double]
            %        TimeStamps: [1000×1 double]
            %            Source: []
            %         EventName: 'DataAvailable'
            %
            %
            %   'daq_error' - error from the DAQ
            %       .src = []
            %       .data = Modified Data
            %           Error: [1×1 MException]
            %          Source: []
            %       EventName: 'ErrorOccurred'
            %
            %   'struct'
            %       .data - session as a struct
            %   
            %   'error' - error in the parallel code caught by try/catch
            %       .data - ME
            %
            %   See Also:
            %   daq2.parallel_session_worker
            %
            %   IMPORTANT: Any errors thrown here or in the callers via
            %   error() are transformed into warnings and become really
            %   hard to debug. This is why some commands have been
            %   wrapped with try/catch blocks ...
            
            obj.h_tic_recv = tic;
            obj.h_tic_work_send = s.send_time;
            
            switch s.cmd
                case 'data_available'
                    %   Data received from the DAQ
                    %
                    %   .data - struct
                    try
                        %   TriggerTime would be useful for ascertaining t = 0
                        if ~isempty(obj.data_available_cb)
                            src = [];
                            obj.data_available_cb(src,s.data);
                        end
                    catch ME
                        assignin('base','last_ME_from_cb3',ME);
                        %TODO: This needs to be improved
                        %See issue #7
                        %disp(ME)
                        fprintf(2,'An error occurred, see "last_ME_from_cb3" in the base workspace\n');
                        obj.command_window.logErrorMessage('Code error in daq2.parallel_raw_session');
                    end
                case {'daq_error' 'parallel_error'}
                    %.ME - MException
                    
                    if strcmp(s.cmd,'error')
                        m1 = 'Received code error from parallel session worker';
                    else
                        m1 = 'Received DAQ error from parallel session worker';
                    end
                    
                    ME = s.ME;
                    obj.daq_props.IsRunning = false;
                    if ~isempty(obj.error_cb)
                        try
                            obj.command_window.logErrorMessage(m1);                            
                            obj.error_cb(ME);
                            assignin('base','last_ME_from_cb1',ME);
                            fprintf(2,'An error occurred, see "last_ME_from_cb1" in the base workspace\n');
                        catch ME
                        	assignin('base','last_ME_from_cb2',ME);
                            fprintf(2,'An error occurred, see "last_ME_from_cb2" in the base workspace\n');
                            obj.command_window.logErrorMessage('Code error in daq2.parallel_raw_session');
                        end
                    else
                        obj.command_window.logErrorMessage(ME.message);
                    end
                case 'perf'
                    %.data - struct
                    obj.p_perf = s.data;
                case 'struct'
                    obj.p_daq_struct = s.data;
                otherwise
                    error('Internal code error, missing command: %s',s.cmd);
            end
        end
        %==================================================================
        function s = struct(obj)
            s = struct;
            s.VERSION  = 1;
            s.STRUCT_DATE = now;
            s.TYPE = 'daq2.parallel_raw_session';
            
            %From raw_session ...
            s.chans = cellfun(@struct,obj.chans,'un',0);
            s.chan_types = obj.chan_types;
            s.rate = obj.rate;
            s.read_cb_time = obj.read_cb_time;
            s.read_cb_samples = obj.read_cb_samples;
            s.write_cb_time = obj.write_cb_time;
            s.write_cb_samples = obj.write_cb_samples;
            
            %Not yet implemented locally
%             s.summary = obj.summary;
        end
        function delete(obj)
            if ~isempty(obj.feval_future) && isvalid(obj.feval_future)
                cancel(obj.feval_future);
            end
        end
    end
    
    %Setup ================================================================
    methods
       	function addChannelsBySpec(obj,chan_specs)
            %
            %   Inputs
            %   ------
            %   chan_specs : array or cell array of: 
            %       - daq2.channel.spec.analog_input
            %       - daq2.channel.spec.analog_output
            %
            %   See Also
            %   --------
            %   addAnalogInput
            %   addAnalogOutput
            
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
                obj.chan_types(end+1) = l_type;
            end
        end
        function addListener(obj,name,function_handle)
            %
            %
            %   Listeners:
            %   - 'DataAvailable'
            %   - 'ErrorOccurred'
            %   - 'DataRequired' - This can't be called because it is
            %   directly linked inside the parallel worker. We could 
            %   technically expose this to the user but it wouldn't
            %   work all the well and isn't high priority.
            %
            %   Note: Currently we don't really have listener support, they
            %   are really just callbacks, so only one function gets to
            %   "listen"
            
            switch name
                case 'DataAvailable'
                    obj.data_available_cb = function_handle;
                case 'ErrorOccurred'
                    obj.error_cb = function_handle;
                case 'DataRequired'
                    error('Data required callback not supported')
                otherwise
                    error('Unrecognized listener type')
            end
            
            %No need to modify the session, we just need to handle
            %these when we receive the appropriate signals from the worker
        end
    end
    
    %Meant to be accessed via: addChannelsBySpec -=========================
    methods (Hidden)
        function [ch,idx] = addAnalogInput(obj,dev_id,daq_port,meas_type,other,dec_rate)
            %
            %
            %   Outputs are not currently populated.
            %   
            %   Outputs
            %   -------
            %   ch : []
            %   idx : []
            %
            %   See Also
            %   --------
            %   daq2.channel.spec.analog_input
            
            ch = [];
            idx = [];
            
            s = struct;
            s.cmd = 'add_analog_input';
            s.id = dev_id;
            s.port = daq_port;
            s.type = meas_type;
            s.other = other;
            s.dec_rate = dec_rate;
            
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
    end
    
    %Control Methods ======================================================
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
    end
    
 	%Queries ==============================================================
    methods
        function output = getElapsedSessonTime(obj)
           %This is currently not very accurate ... 
           %
           %    I think it could be if we link the start of the DAQ to
           %    the processor time
           %
           %    
           output = toc(obj.h_start_tic);
        end
        function ai_chans = getAnalogInputChans(obj)
            temp = obj.chans(obj.chan_types == 1);
            ai_chans = [temp{:}];
        end
        function devices = getAvailableDevices(obj) %#ok<MANU>
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
            s.n_seconds_add = n_seconds_add;
            h__send(obj,s);
        end
        function updateStimParams(obj,s)
         	s2 = struct;
            s2.cmd = 'update_stim';
            s2.data = s;
            h__send(obj,s2);
        end
    end
    
    %Debugging ===========================================
    methods
        function requestSessionStruct(obj)
            h__sendCmd(obj,'struct');
        end
        function requestPerformanceStruct(obj)
            h__sendCmd(obj,'perf');
        end
        function summarizePerfomance(obj)
           obj.p_perf = [];
           obj.requestPerformanceStruct();
           pause(3);
           if isempty(obj.p_perf)
               error('Code not yet implemented to handle long delay in struct retrieval')
           end
           p = obj.p_perf;
           figure
           I = p.loop_I;
           ax(1) = subplot(4,1,1);
           plot(p.loop_etimes(1:I));
           title('Elapsed time in worker loop')
           ax(2) = subplot(4,1,2);
           plot(p.loop_types(1:I))
           title('Loop types: 1=queue, 2ish=cmd, 3=pause, 4=start, 5=stop')
           ax(3) = subplot(4,1,3);
           plot(p.read_data_process_times(1:p.read_data_process_I));
           ax(4) = subplot(4,1,4);
           plot(p.read_data_process_times(1:p.read_data_send_I));
           linkaxes(ax(1:2),'x');
        end
    end
end

function h__sendParam(obj,param,value)
    s = struct;
    s.cmd = 'update_daq_prop';
    s.name = param;
    s.value = value;
    h__send(obj,s);
    
    %Log locall as well
    obj.daq_props.(param) = value;
end

function h__sendCmd(obj,cmd)
    s = struct;
    s.cmd = cmd;
    h__send(obj,s)
end

function h__send(obj,s)
%
%   All sends to the worker should come through here ...
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

