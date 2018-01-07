classdef session < handle
    %
    %   Class:
    %   daq2.session
    %
    %   This is the main class for the daq2 package
    
    properties
        raw_session             %daq2.raw_session OR daq2.parallel_raw_session
        perf_monitor            %daq2.perf_monitor
        input_data_handler      %daq2.input_data_handler
        output_data_handler     %daq2.output_data_handler OR daq2.parallel_output_data_handler
        options                 %daq2.session.session_options
        
        parallel_session_enabled %logical
        
        cmd_window  %Default: daq2.command_window
        %Interface:
        %   logMessage(string,formatting_varargin)
        %   logError(string,formmatting_varargin)
        iplot %interactive_plot
        
        %TODO: Expose via set method
        error_cb
        %This can be set by the user. It gets called when
        %a daq error occurs ...
    end
    
    properties (Dependent)
        is_running
        rate
    end
    
    methods
        function value = get.rate(obj)
            value = obj.raw_session.rate;
        end
        function value = get.is_running(obj)
            value = obj.raw_session.is_running;
        end
    end
    
    methods
        function obj = session(type,varargin)
            %
            %   obj = daq2.session(type)
            %
            %   s = daq2.session('ni');
            %
            %   Optional Inputs
            %   ---------------
            %   command_window : like daq2.command_window
            %       See daq2.command_window for the necessary method
            %       interfaces.
            
            MAX_HW_STARTUP_TIME = 15;
            
            in = daq2.session.session_options();
            in = sl.in.processVarargin(in,varargin);
            options = in;
            obj.options = options;
            
            %Shared data ...
            %---------------------------------------------
            if isempty(in.command_window)
                obj.cmd_window = daq2.command_window();
            else
                obj.cmd_window = in.command_window();
            end
            
            obj.perf_monitor = daq2.perf_monitor(obj.cmd_window);
            
            obj.parallel_session_enabled = options.use_parallel;
            
            h__initParallelPool(obj,MAX_HW_STARTUP_TIME)
            
            if obj.parallel_session_enabled
                obj.raw_session = daq2.parallel_raw_session(...
                    type,obj.perf_monitor,obj.cmd_window);
            else
                obj.raw_session = daq2.raw_session(...
                    type,obj.perf_monitor,obj.cmd_window);
            end
            
            %Input/Output Handlers
            %------------------------------------------------------
            obj.input_data_handler = daq2.input_data_handler(...
                obj.parallel_session_enabled,obj.raw_session,...
                obj.perf_monitor,obj.cmd_window,options);
            
            if options.use_parallel
                obj.output_data_handler = daq2.parallel_output_data_handler(...
                    obj.raw_session,obj.perf_monitor,obj.cmd_window);
            else
                obj.output_data_handler = daq2.output_data_handler(...
                    obj.raw_session,obj.perf_monitor,obj.cmd_window);
            end
            
            %Listeners
            %-----------------------------------------------------
            obj.raw_session.addListener('ErrorOccurred',@obj.errorHandlerCallback);
        end
    end
    
    %Setup Methods  =======================================================
    methods
        function addChannelsBySpec(obj,chan_specs)
            %
            %   Inputs
            %   ------
            obj.raw_session.addChannelsBySpec(chan_specs);
        end
        function addStimulator(obj,stim_fcn,s)
            %
            %
            %   Examples
            %   --------
            %   fs = 10000;
            %   pulse_width_us = 200;
            %   waveform = daq2.basic_stimulator.getBiphasicWaveform(fs,pulse_width_us)
            %   stim_fcn = @daq2.basic_stimulator
            %   s = struct;
            %   %Add 0.5 seconds of data every time we run
            %   s.default_time_growth = 0.5;
            %   s.params = struct;
            %   s.params.waveform = waveform;
            %   s.params.amp = 0;
            %   s.params.rate = 1;
            %   session.addStimulator(stim_fcn,s);
            
            obj.output_data_handler.addStimulator(stim_fcn,s)
        end
        function updateStimParams(obj,s)
            obj.output_data_handler.updateStimParams(s);
        end
        function queueMoreData(obj,n_seconds_add)
            obj.output_data_handler.queueMoreData(n_seconds_add);
        end
    end
    
    %Control Methods ======================================================
    methods
        function startBackground(obj,varargin)
            %
            %   Start DAQ in the background
            %
            %   Optional Inputs
            %   ---------------
            %   trial_id :
            %   save_suffix :
            %   save_prefix :
            
            in.trial_id = [];
            in.save_suffix = '';
            in.save_prefix = '';
            in = sl.in.processVarargin(in,varargin);
            
            obj.input_data_handler.initForStart(in.trial_id,in.save_prefix,in.save_suffix);
            obj.output_data_handler.initForStart();
            s = obj.raw_session.struct();
            obj.input_data_handler.saveData('daq2_raw_session',s);
            obj.raw_session.startBackground();
        end
        function stop(obj)
            %TODO: Ignore if not running ...
            %- if we abort, then stop, don't run stop
            obj.iplot = [];
            obj.raw_session.stop();
            obj.output_data_handler.stop();
            obj.input_data_handler.stop();
        end
        function abort(obj,ME)
            obj.iplot = [];
            obj.cmd_window.logErrorMessage(ME.message);
            %I don't think we need to stop the DAQ if the DAQ is throwing
            %the error.
            %
            %I keep getting the following error:
            %
            %    identifier: 'daq:Session:stopDidNotComplete'
            %       message: 'Internal Error: The hardware did not report that it stopped before the timeout elapsed.'
            %obj.raw_session.stop();
            
            obj.output_data_handler.stop();
            
            %Note that we are aborting, not just stopping
            obj.input_data_handler.abort(ME);
        end
    end
    
    %Methods while running ================================================
    methods
        function loadCalibrations(obj,file_paths,varargin)
            %
            %
            %   Optional Inputs
            %   ---------------
            %   None Yet
            %
            %   See Also
            %   --------
            %   interactive_plot>loadCalibrations
            
            if isempty(obj.iplot)
                obj.cmd_window.logErrorMessage(...
                    'Unable to load an calibration when no plot is present');
            end
            obj.iplot.loadCalibrations(file_paths,varargin)
        end
        function iplot = plotDAQData(obj,varargin)
            %
            %   Launch Interactive Plot
            %
            %   See Also
            %   --------
            %   daq2.input.acquired_data>plotDAQData
            
            iplot = obj.input_data_handler.plotDAQData(varargin{:});
            obj.iplot = iplot;
        end
        function xy_data = getXYData(obj,name)
            xy_data = obj.input_data_handler.getXYData(name);
        end
        function saveData(obj,name,data)
            %
            %   Save data to the current data file.
            obj.input_data_handler.saveData(name,data);
        end
        %         function addNonDaqData(obj,name,data)
        %             %
        %             %   Does 2 things:
        %             %   1) Saves the data to disk
        %             %   2) Keeps it in memory for later use and retrieval
        %
        %             error('not yet implemented')
        %
        %             obj.input_data_handler.addNonDaqData(name,data);
        %         end
        function addNonDaqXYData(obj,name,y_data,x_data)
            %
            %   Does 2 things:
            %   1) Saves the data to disk
            %   2) Keeps it in memory for later use and retrieval
            obj.input_data_handler.addNonDaqXYData(name,y_data,x_data);
        end
        function queueOutputData(obj,data)
            %??? - how do we distinguish between analog and digital?
            
            r = obj.raw_session;
            
            if nargin == 1
                n_output_chans = r.n_analog_outputs;
                n_samples = r.write_cb_samples*2;
                data = zeros(n_samples,n_output_chans);
            end
            obj.raw_session.queueOutputData(data);
        end
    end
    
    methods
        function errorHandlerCallback(obj,ME)
            %
            %   Modified error listener format, ME Only
            
            %TODO: Do we want to add data to any file???
            %=> if so, handle in input_data_handler.abort ....
            obj.cmd_window.logErrorMessage(ME.message);
            
            %Call user first before we clean up non-DAQ calls ...
            if ~isempty(obj.error_cb)
                obj.error_cb(ME);
            end
            
            obj.abort(ME);
        end
    end
    
    
end

function h__initParallelPool(obj,MAX_HW_STARTUP_TIME)
%
%
%   TODO: Document what we need to do ...

MIN_TIME_SHOW_HW_MSG = 1; %second

if obj.parallel_session_enabled
    n_workers_needed = 2;
else
    n_workers_needed = 1;
end

%Start the parallel pool
%------------------------------------------------------
current_pool = gcp('nocreate');
if isempty(current_pool)
    obj.cmd_window.logMessage('Staring parallel pool for daq2 code')
    current_pool = gcp;
    obj.cmd_window.logMessage('Parallel pool initialized')
end

%Retrieve all DAQ HW info
%-------------------------------------------------------
%- This can be really slow
%- This is only used when we are running the DAQ session on a parallel
%worker
if obj.parallel_session_enabled
    %TODO: Ideally we would be able to choose workers ...
    %This might need to be adjusted ...
    fh = @daq2.utils.initDAQInfo;
    f = parfevalOnAll(gcp,fh,0);
    h_tic = tic;
    hw_loading_msg_shown = false;
    while (toc(h_tic) < MAX_HW_STARTUP_TIME && ~strcmp(f.State,'finished'))
        if toc(h_tic) > MIN_TIME_SHOW_HW_MSG && ~hw_loading_msg_shown
            obj.cmd_window.logMessage('Parallel processes are initializing Generic Matlab DAQ Info')
            hw_loading_msg_shown = true;
        end
        pause(0.1);
    end
    
    if hw_loading_msg_shown
        obj.cmd_window.logMessage('Done loading generic DAQ Info')
    end
end


%# of workers check
%--------------------------------------------------------------------------
if current_pool.NumWorkers < n_workers_needed
    %TODO: Provide more info
    error('Invalid # of workers in parallel pool')
end

running_futures = current_pool.FevalQueue.RunningFutures;
if ~isempty(running_futures)
    %Stop any that are related to this code ...
    %
    %Note this means we can't run two sessions at once
    fcn_handles = {running_futures.Function};
    fcn_strings = cellfun(@(x) func2str(x),fcn_handles,'un',0);
    
    mask = ismember(fcn_strings,...
        {'daq2.input.parallel_data_writer_worker',...
        'daq2.parallel_session_worker'});
    for i = 1:length(running_futures)
        if mask(i)
            cancel(running_futures(i));
        end
    end
    
    %After possibly stopping some, check if we are ok
    running_futures = current_pool.FevalQueue.RunningFutures;
    n_free = current_pool.NumWorkers - length(running_futures);
    if n_free < n_workers_needed
        error('Invalid # of FREE workers in parallel pool')
    end
end

end

