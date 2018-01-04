classdef data_writer < handle
    %
    %   Class:
    %   daq2.input.data_writer
    %
    %   This class handles saving data to disk. To reduce blocking of
    %   other code we call a parallel process for saving data.
    %
    %   See Also
    %   --------
    %   daq2.input.parallel_data_writer_worker
    
    properties
        perf_mon
        command_window
        options         %daq2.session.session_options
        
        %Save Info
        base_save_path
        
        %Parallel
        %--------
        pool %'parallel.Pool'
        q_send
        feval_future
        
        process_error_thrown = false;
        
        
        h %matlab.io.MatFile
        
        %         session %aua17.daq_session
        %         %just in case ...
        
        
        %DAQ specific writing
        %-------------------------------------
        daq_chan_names
        n_chans
        samples_written %1 x n_chans
        
        
        
        
        t_log   %aua17.time_logger.time_logger_entry
        add_time
        add_size
        add_I
        last_write_time
        extra_chan_log
    end
    
    %Constructor
    %----------------------------------------------------------------------
    methods
        function obj = data_writer(raw_session,perf_mon,command_window,...
                options,trial_id,save_prefix,save_suffix)
            %
            %   w = daq2.input.data_writer(perf_mon,command_window)
            %
            %   Inputs
            %   ------
            %   file_manager : aua17.file_manager
            %   cmd_win :
            %   chan_names :
            
            %Max amount of time to wait for the parallel process (thread?)
            %to launch and to send a queue back to this process
            MAX_WAIT_PARALLEL_STARTUP = 5; %seconds
            
            obj.perf_mon = perf_mon;
            obj.command_window = command_window;
            obj.options = options;
            
            %Requires parallel pool toolbox
            %------------------------------
            obj.pool = gcp('nocreate');
            if isempty(obj.pool)
                obj.command_window.logMessage('Staring parallel pool for logging data')
                obj.pool = gcp;
                obj.command_window.logMessage('Parallel pool initialized')
            end
            
            q_receive = parallel.pool.PollableDataQueue;
            
            obj.resolveBasePath();
            
            file_path = getFilePath(obj,trial_id,save_prefix,save_suffix);
            h_matfile = matlab.io.MatFile(file_path);
            
            
            %Launch the parallel data writer
            %------------------------------------------------
            fh = @daq2.input.parallel_data_writer_worker;
            obj.feval_future = parfeval(gcp,fh,0,q_receive,h_matfile);
            
            %now obtain the q
            %----------------------------
            %- we need to wait for the worker to start and for it to send
            %data back to us
            t = tic;
            while (toc(t) < MAX_WAIT_PARALLEL_STARTUP && q_receive.QueueLength == 0)
                pause(0.1);
            end
            
            if q_receive.QueueLength == 0
                error('Unable to receive queue back from parallel function');
            else
                obj.q_send = q_receive.poll();
                if ~isa(obj.q_send,'parallel.pool.PollableDataQueue')
                    error('Received data not of expected type')
                end
            end
            
            ai_chans = raw_session.getAnalogInputChans();
            obj.daq_chan_names = {ai_chans.short_name};
            %Add DAQ prefix to reduce name conflicts ...
            obj.daq_chan_names = cellfun(@(x) ['daq__' x],obj.daq_chan_names,'un',0);
            obj.n_chans = length(obj.daq_chan_names);
            obj.samples_written = zeros(1,obj.n_chans);
            
            obj.extra_chan_log = containers.Map;
            
            %This should get overridden on closing
            obj.saveData('trial_status','incomplete');
        end
        function resolveBasePath(obj)
            
            obj.base_save_path = obj.options.base_save_path;
            if isempty(obj.base_save_path)
                temp = sl.stack.getPackageRoot();
                id = datestr(now,'yymmdd');
                obj.base_save_path = fullfile(temp,'data',id);
            end
            sl.dir.createFolderIfNoExist(obj.base_save_path);
        end
        function file_path = getFilePath(obj,trial_id,prefix,suffix)
            %
            %   file_types:
            %   - DAQ
            
            if isempty(trial_id)
                %TODO: Make this smarter
                trial_id = 0;
            end
            
            if ~isempty(prefix)
                prefix = [prefix '_'];
            else
                prefix = '';
            end
            
            if ~isempty(suffix)
                suffix = ['__' suffix];
            else
                suffix = '';
            end
            
            %<prefix>_<trial_id>_<date_str>_<suffix>
            date_string = datestr(now,'yymmdd__HH_MM_SS');
            trial_string = sprintf('%03d',trial_id);
            
            file_name = sprintf('%s%s__%s%s.mat',...
                prefix,trial_string,date_string,suffix);
            
            file_path = fullfile(obj.base_save_path,file_name);
            
        end
        function closerWriterWithError(obj,ME)
            %NYI
            %error sources:
            %- DAQ
            %- others???
            %error_id - negative
            obj.saveData('error_value',ME);
            obj.saveData('trial_status','error');
            h__send(obj,[]);
        end
        function closeWriter(obj)
            obj.saveData('trial_status','success');
            h__send(obj,[]);
        end
        function delete(obj)
            %TODO: Have q receive # of values written
            %Wait until this has cleared ...
            %
            %   i.. they match
            if ~isempty(obj.feval_future) && isvalid(obj.feval_future)
                cancel(obj.feval_future);
            end
        end
    end
    
    %Writing Methods
    %----------------------------------------------------------------------
    methods
        function addDAQSamples(obj,decimated_data)
            %
            %   Inputs
            %   ------
            %   decimated_data
            %
            %   See Also
            %   --------
            %   aua17.data.decimation_handler
            
            
            %If we ever run into saving problems we could create a
            %secondary buffer which writes less frequently. The program
            %seems to be working fine as is
            
            c = obj.daq_chan_names;
            n_written = obj.samples_written;
            for i = 1:obj.n_chans
                temp_data = decimated_data{i};
                cur_chan_name = c{i};
                
                n_samples_new = length(temp_data);
                end_I = n_written(i) + n_samples_new;
                start_I = n_written(i)+1;
                
                %Send data to worker for logging
                %---------------------------------------
%                 s = struct;
%                 s.cmd = 'add_samples';
%                 s.name = cur_chan_name;
%                 s.data = temp_data;
%                 s.start_I = start_I;
%                 s.end_I = end_I;
                
                s = struct(...
                    'cmd','add_samples',...
                    'name',cur_chan_name,...
                    'data',temp_data,...
                    'start_I',start_I,...
                    'end_I',end_I);
                
                h__send(obj,s)
                n_written(i) = end_I;
            end
            obj.samples_written = n_written;
            
        end
        function saveData(obj,name,data)
            %For saving the plotting data
            %=> comments, settings, etc
            %
            
            %This should be used when only 1 version of the data
            %should be saved, not an array of those values that accumulate
            %such as with addSamples
            
            if iscell(data)
                obj.command_window.logErrorMessage('Unable to save a cell array using saveData')
            end
            
            s = struct(...
                'cmd','add_samples',...
                'name',name,...
                'data',data,...
                'start_I',1,...
                'end_I',length(data));
            
            h__send(obj,s)
        end
        function addSamples(obj,chan_name,data)
            %
            %   This method can be used to log additional samples
            %   to any field. It is not meant to be called for saving
            %   data collected from the DAQ. Rather it should be used for
            %   extra fields.
            %
            %   Does this work for structures? => yes
            %   - although saveStruct is better for a single structure
            %   - this is really meant for a structure array, where
            %   elements are continually added
            %   
            
            if isKey(obj.extra_chan_log,chan_name)
                n_values_written = obj.extra_chan_log(chan_name);
            else
                n_values_written = 0;
            end
            
            n_samples_new = length(data);
            end_I = n_values_written + n_samples_new;
            start_I = n_values_written + 1;
            
            %Send data to worker for logging
            %---------------------------------------------
            s = struct(...
                'cmd','add_samples',...
                'name',chan_name,...
                'data',data,...
                'start_I',start_I,...
                'end_I',end_I);
            
            h__send(obj,s)
            
            obj.extra_chan_log(chan_name) = end_I;
        end
    end
end

function h__send(obj,s)
%Send data to parallel pool

%TODO: look at obj.feval_future.State 'running' or .Error (should be empty)
%- handle result accordingly ...

if isempty(obj.feval_future.Error)
    obj.q_send.send(s);
elseif ~obj.process_error_thrown
    obj.command_window.logErrorMessage('Parallel writing process failed with the following message: %s',obj.feval_future.Error);
    obj.process_error_thrown = true;
end
end

