classdef data_writer < handle
    %
    %   Class:
    %   daq2.input.data_writer
    %
    %   This class handles saving data to disk. To reduce blocking of
    %   other code we call a parallel process for saving data.
    %
    %   This class is created just prior to running a trial.
    %
    %   See Also
    %   --------
    %   daq2.input.parallel_data_writer_worker
    
    properties
        perf_mon    %daq2.perf_monitor
        command_window  %Default: daq2.command_window
        options         %daq2.session.session_options
        
        %Save Info
        base_save_path
        
        %Parallel
        %--------
        pool    %'parallel.Pool'
        q_send  %
        feval_future %Handle to parallel worker
        
        %If an error comes from the parallel worker
        %we throw an error locally. This ensures we only throw it once.
        process_error_thrown = false;
        %-----------------------------------------------
        
        h %matlab.io.MatFile
        %Handle to the file where the data are saved
        
        
        %DAQ specific writing
        %-------------------------------------
        daq_chan_names
        n_daq_chans
        total_samples_written %[1 x n_daq_chans]
        
        
        %   Buffering working for writing
        %   ------------------------------
        chan_buffers %{1 x n_daq_chans}
        buffer_samples
        %For each channel, how may samples are in the buffer.
        
        min_write_data_time
        %Grabbed from daq2.session.session_options
        
        always_write_data = false
        %This becomes true if we are acquiring data at a slower
        %rate than the minimum time between writes above
        
        n_acqs_since_last_save
        n_acqs_needed
        
        n_flushes
        %At a minimum this is 1 ...
        
        %I don't think these are used:
        %         t_log   %aua17.time_logger.time_logger_entry
        %         add_time
        %         add_size
        %         add_I
        %         last_write_time
        
        %Writing of other data
        %--------------------------------------
        extra_chan_log %containers.Map
        %key : channel name
        %value : # of samples written
    end
    
    %Constructor
    %----------------------------------------------------------------------
    methods
        function obj = data_writer(raw_session,perf_mon,command_window,...
                options,trial_id,save_prefix,save_suffix)
            %
            %   w = daq2.input.data_writer(
            %           raw_session,
            %           perf_mon,
            %           command_window,...
            %           options,
            %           trial_id,
            %           save_prefix,
            %           save_suffix)
            %
            %   Inputs
            %   ------
            %   command_window : daq2.command_window
            %   options : daq2.session.session_options
            %   perf_mon : daq2.perf_monitor
            %   raw_session
            %   save_prefix
            %   save_suffix
            %   trial_id
            %       What is the default value?
            %
            %   See Also
            %   --------
            %   daq2.input_data_handler.initForStart
            
            
            
            %Max amount of time to wait for the parallel process
            %to launch and to send a queue back to this process
            MAX_WAIT_PARALLEL_STARTUP = 5; %seconds
            
            obj.perf_mon = perf_mon;
            obj.command_window = command_window;
            obj.options = options;
            obj.min_write_data_time = options.min_write_data_time;
            
            %Requires parallel pool toolbox
            %------------------------------
            obj.pool = gcp('nocreate');
            if isempty(obj.pool)
                obj.command_window.logMessage('Staring parallel pool for logging data')
                obj.pool = gcp;
                obj.command_window.logMessage('Parallel pool initialized')
            end
            
            q_receive = parallel.pool.PollableDataQueue;
            
            %I'm not sure if this should be in the getFilePath function
            %- These are always called together
            obj.resolveBasePath();
            
            file_path = getFilePath(obj,trial_id,save_prefix,save_suffix);
            
            %TODO: Why isn't this opened remotely?
            %h_matfile = matlab.io.MatFile(file_path);
            
            
            %Launch the parallel data writer
            %------------------------------------------------
            fh = @daq2.input.parallel_data_writer_worker;
            %obj.feval_future = parfeval(gcp,fh,0,q_receive,h_matfile);
            obj.feval_future = parfeval(gcp,fh,0,q_receive,file_path);
            
            
            %now obtain the q
            %----------------------------
            %- we need to wait for the worker to start and for it to send
            %data back to us
            t = tic;
            while (toc(t) < MAX_WAIT_PARALLEL_STARTUP && q_receive.QueueLength == 0)
                pause(0.1);
            end
            
            if q_receive.QueueLength == 0
                %TODO: Output to command window
                %Since we can fail in the constructor, we should have the
                %constructor wrapped in a static creation method
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
            obj.n_daq_chans = length(obj.daq_chan_names);
            obj.total_samples_written = zeros(1,obj.n_daq_chans);
            
            %Buffer work ...
            %----------------------------
            all_fs = [ai_chans.fs];
            
            write_cb_time = raw_session.write_cb_time;
            
            if write_cb_time > obj.min_write_data_time
                n_acqs_before_save = 1;
            else
                %ASSUMPTION: This assumes that Matlab returns the
                %appropriate # of samples for each time, rather than what
                %it has in the buffer at the time. In other words if we
                %sample 10000x a second, and the callback is every second,
                %I would expect to get the following # of samples for
                %a series of callbacks:
                %10000, 10000, 10000, 10000 rather than
                %10234, 10503, 13503, 10001 <= random numbers above 10000
                n_acqs_before_save = ceil(obj.min_write_data_time/write_cb_time);
                %Padding (the + 1) may not be necessary but it is easier to
                %keep in for now. It just increases memory requirements.
                n_acqs_buffer = n_acqs_before_save + 1;
                obj.chan_buffers = cell(1,obj.n_daq_chans);
                obj.buffer_samples = zeros(1,obj.n_daq_chans);
                for i = 1:obj.n_daq_chans
                    n_samples_buffer = all_fs(i)*n_acqs_buffer;
                    %Note, this must be a column vector
                    obj.chan_buffers{i} = zeros(n_samples_buffer,1);
                end
            end
            
            obj.extra_chan_log = containers.Map;
            
            %This should get overridden on closing
            obj.saveData('trial_status','incomplete');
            
            obj.n_acqs_since_last_save = 0;
            obj.n_acqs_needed = n_acqs_before_save;
        end
        function resolveBasePath(obj)
            %
            %   Resolves folder for saving data. Updates property:
            %       'base_save_path'
            %
            %   Use bath path from options if present:
            %       options.base_save_path
            %
            %   If not present, save in daq2 package based on date:
            %       daq2_repo_root/data/<yymmdd>/
            %
            obj.base_save_path = obj.options.base_save_path;
            if isempty(obj.base_save_path)
                temp = daq2.sl.stack.getPackageRoot();
                id = datestr(now,'yymmdd');
                obj.base_save_path = fullfile(temp,'data',id);
            end
            daq2.sl.dir.createFolderIfNoExist(obj.base_save_path);
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
            %disp('I ran2')
            obj.flushBuffers();
            h__send(obj,[]);
            for i = 1:40
                if strcmp(obj.feval_future.State,'running')
                    fprintf('Waiting for writer: %d\n',i)
                    pause(1)
                end
            end
        end
        function closeWriter(obj)
            obj.saveData('trial_status','success');
            %keyboard
            obj.flushBuffers();
            h__send(obj,[]);
            %disp('I ran')
            %TODO: Wait for write confirmation?????
            for i = 1:40
                if strcmp(obj.feval_future.State,'running')
                    fprintf('Waiting for writer: %d\n',i)
                    pause(1)
                end
            end
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
        function flushBuffers(obj)
            obj.n_acqs_since_last_save = 0;
            obj.n_flushes = obj.n_flushes + 1;
            
            %TODO: I think I need to still flush the buffer index
            %to get this to work
            
            %              obj.buffer_samples(i) = end_I;
            %                     obj.chan_buffers{i}(start_I:end_I) = temp_data;
            
            c = obj.daq_chan_names;
            n_written = obj.total_samples_written;
            for i = 1:obj.n_daq_chans
                end_I = obj.buffer_samples(i);
                if end_I > 0
                    %New flushing
                    obj.buffer_samples(i) = 0;

                    temp_data = obj.chan_buffers{i}(1:end_I);
                    cur_chan_name = c{i};

                    n_samples_new = length(temp_data);
                    end_I = n_written(i) + n_samples_new;
                    start_I = n_written(i)+1;

                    %Send data to worker for logging
                    %---------------------------------------

                    s = struct(...
                        'cmd','add_samples',...
                        'name',cur_chan_name,...
                        'data',temp_data,...
                        'start_I',start_I,...
                        'end_I',end_I);

                    h__send(obj,s)
                    n_written(i) = end_I;
                end
            end
            obj.total_samples_written = n_written;
            
            
        end
    end
    
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
            
            %The actual writing to disk uses ~20% CPU
            %
            %saving all channels every 1/3 second
            %
            %If we save every 3 seconds, do we get a corresponding
            %reduction in CPU usage?
            
            %If we ever run into saving problems we could create a
            %secondary buffer which writes less frequently. The program
            %seems to be working fine as is
            
%             persistent wtf
%             
%             if isempty(wtf)
%                 wtf = 1;
%             else
%                 wtf = wtf  +1;
%             end
            
            
            
            %daq2.input.parallel_data_writer_worker
            
            if obj.n_acqs_needed == 1
                c = obj.daq_chan_names;
                n_written = obj.total_samples_written;
                for i = 1:obj.n_daq_chans
                    temp_data = decimated_data{i};
                    cur_chan_name = c{i};
                    
                    n_samples_new = length(temp_data);
                    end_I = n_written(i) + n_samples_new;
                    start_I = n_written(i)+1;
                    
                    %Send data to worker for logging
                    %---------------------------------------
                    
                    s = struct(...
                        'cmd','add_samples',...
                        'name',cur_chan_name,...
                        'data',temp_data,...
                        'start_I',start_I,...
                        'end_I',end_I);
                    
                    h__send(obj,s)
                    n_written(i) = end_I;
                end
                obj.total_samples_written = n_written;
                
%               	if mod(wtf,10) == 0
%                     disp(mat2str(n_written))
%                 end
                
                
            else
                %Chunked saving
                
                
                obj.n_acqs_since_last_save = obj.n_acqs_since_last_save + 1;
                
                for i = 1:obj.n_daq_chans
                    temp_data = decimated_data{i};
                    start_I = obj.buffer_samples(i)+1;
                    end_I = start_I + length(temp_data) - 1;
                    obj.buffer_samples(i) = end_I;
                    obj.chan_buffers{i}(start_I:end_I) = temp_data;
                end
                
                if obj.n_acqs_since_last_save >= obj.n_acqs_needed
                    obj.flushBuffers();
                end
                
%                 if mod(wtf,10) == 0
%                     disp(wtf*10000)
%                 end
                
            end
            
        end
        function saveData(obj,name,data)
            %
            %   This method saves data as a field to the file. This is
            %   equivalent to:
            %       h.(name) = data
            %   Where h is the matfile handle.
            %
            %   This is as opposed to the other saving methods which index
            %   into the field.
            
            s = struct(...
                'cmd','save',...
                'name',name,...
                'data',[]);
            
            %Avoid struct expansion from cell data
            s.data = data;
            
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
    obj.command_window.logErrorMessage(...
        'Parallel writing process failed with the following message: %s',...
        obj.feval_future.Error.message);
    obj.process_error_thrown = true;
end
end

