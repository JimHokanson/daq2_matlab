classdef input_data_handler < handle
    %
    %   Class:
    %   daq2.input_data_handler
    %
    %   The input data handler does mainly 2 things:
    %   1) Saves data to disk
    %   2) Logs data in memory (for plotting, currently not optional)
    %
    %   This functionality is obtained by calling two subclasses:
    %   1) data_writer   - daq2.input.data_writer
    %   2) acquired_data - daq2.input.acquired_data
    %
    %   See Also
    %   --------
    %   daq2.output_data_handler
    %   daq2.input.data_writer
    %   daq2.input.acquired_data
    
    
    
    properties
        is_parallel
        raw_session  %daq2.raw_session OR daq2.parallel_raw_session
        perf_monitor %daq2.perf_monitor
        cmd_window
        options         %daq2.session.session_options
        
        %Objects for processing acquired data
        %------------------------------------
        decimation_handler  %daq2.input.decimation_handler
        acquired_data       %daq2.input.acquired_data
        data_writer         %daq2.input.data_writer
        read_cb
        iplot       %interactive_plot
        
        iplot_listen    %Event listener
        %Listens for the session to be updated and saves any changes to
        %disk
        
        avg_data
        daq_recording = false
        
        %Calibrations
        %------------
        m
        b
    end
    
    %Constructors
    %----------------------------------------------------
    methods
        function obj = input_data_handler(is_parallel,raw_session,...
                perf_monitor,cmd_window,options)
            %
            %   obj = daq2.input_data_handler(is_parallel,raw_session,
            %           perf_monitor,cmd_window)
            %
            %   See Also
            %   --------
            %   daq2.session
            
            obj.is_parallel = is_parallel;
            obj.raw_session = raw_session;
            obj.perf_monitor = perf_monitor;
            obj.cmd_window = cmd_window;
            obj.options = options;
            
            raw_session.addListener('DataAvailable',@obj.readDataCallback)
        end
        function initForStart(obj,trial_id,save_prefix,save_suffix)
            %
            %   initForStart(obj,trial_id,save_prefix,save_suffix)
            %
            %   Called to initialize the class for another DAQ trial.
            %
            %   Full: daq2.input_data_handler.initForStart
            %
            %   Inputs
            %   -------------
            %   trial_id :
            %   save_prefix :
            %   save_suffix :
            %
            %   See Also
            %   --------
            %   daq2.input.acquired_data
            %   daq2.input.data_writer
            
            obj.perf_monitor.resetRead();
            
            if ~obj.is_parallel
                error('Not yet implemented')
                %                  obj.raw_session = raw_session;
                %             obj.perf_monitor = perf_monitor;
                %
                %             ai_chans = raw_session.getAnalogInputChans();
                
                obj.decimation_handler = daq2.input.decimation_handler(...
                    obj.raw_session,obj.perf_monitor);
            end
            
            
            obj.acquired_data = daq2.input.acquired_data(...
                obj.raw_session,obj.perf_monitor,obj.cmd_window,obj.options);
            
            obj.data_writer = daq2.input.data_writer(...
                obj.raw_session,obj.perf_monitor,obj.cmd_window,obj.options,...
                trial_id,save_prefix,save_suffix);
            
            obj.m = ones(1,obj.acquired_data.n_chans);
            obj.b = zeros(1,obj.acquired_data.n_chans);
            
            obj.read_cb = obj.raw_session.read_cb;
            obj.daq_recording = true;
        end
    end
    
    %User Interfaces
    %----------------------------------------------------------------------
    %Note, I've tried to expose all of these in the session
    methods
        function iplot = plotDAQData(obj,varargin)
            %
            %   iplot = plotDAQData(obj,varargin)
            %
            %   See Also
            %   --------
            %   daq2.input.acquired_data.plotDAQData
            
            if ~obj.daq_recording
                obj.cmd_window.logErrorMessage(...
                    'Unable to add non-daq data when not recording')
                iplot = [];
                return
            end
            
            iplot = obj.acquired_data.plotDAQData(varargin{:});
            obj.iplot = iplot;
            
            %When the session updates (like comments being added)
            %then save the session data to disk
            obj.iplot_listen = ...
                addlistener(iplot.eventz,'session_updated',@obj.sessionUpdated);
        end
        function sessionUpdated(obj,source,event_data)  %#ok<INUSD>
            %
            
            %see interactive_plot.session
            s = obj.iplot.getSessionData;
            obj.saveData('iplot_session_data',s);
        end
        function saveData(obj,name,data)
            %
            %   saveData(obj,name,data)
            
            if ~obj.daq_recording
                obj.cmd_window.logErrorMessage(...
                    'Unable to add non-daq data when not recording')
                return
            end
            
            %Just saving, bypass acquired_data and save
            obj.data_writer.saveData(name,data);
        end
        function addNonDaqData(obj,name,data) %#ok<INUSD>
            if ~obj.daq_recording
                obj.cmd_window.logErrorMessage(...
                    'Unable to add non-daq data when not recording')
                return
            end
            error('Not yet implemented')
        end
        function xy_data = getXYData(obj,name)
            %
            %   xy_data = getXYData(obj,name)
            %
            %   Output
            %   ------
            %   xy_data : daq2.data.non_daq_streaming_xy
            
            if ~obj.daq_recording
                obj.cmd_window.logErrorMessage(...
                    'Unable to get non-daq xy data when not recording')
                return
            end
            xy_data = obj.acquired_data.getXYData(name);
        end
        function addNonDaqXYData(obj,name,y_data,x_data)
            if ~obj.daq_recording
                obj.cmd_window.logErrorMessage(...
                    'Unable to add non-daq xy data when not recording')
                return
            end
            obj.acquired_data.addNonDaqXYData(name,y_data,x_data);
            
            %This would be better as a 2 column variable ...
            %- would need to update data writer ...
            
            %daq2.input.data_writer
            obj.data_writer.addSamples(sprintf('%s__x',name),x_data);
            obj.data_writer.addSamples(sprintf('%s__y',name),y_data);
        end
    end
    
    methods
        function abort(obj,ME)
            obj.daq_recording = false;
            delete(obj.iplot_listen);
            obj.iplot = [];
            obj.acquired_data = [];
            obj.data_writer.closerWriterWithError(ME);
            obj.data_writer = [];
        end
        function stop(obj)
            obj.daq_recording = false;
            delete(obj.iplot_listen);
            obj.iplot = [];
            obj.acquired_data = [];
            obj.data_writer.closeWriter();
            obj.data_writer = [];
        end
    end
    methods
        function loadCalibrations(obj,file_paths,varargin)
            %
            %   loadCalibrations(obj,file_paths,varargin)
            
            if isempty(obj.iplot) || ~isvalid(obj.iplot)
                obj.cmd_window.logErrorMessage(...
                    'Unable to load calibrations when iplot is not open')
                return
            end
            obj.iplot.loadCalibrations(file_paths,varargin{:});
            temp = obj.iplot.getCalibrationsSummary();
            obj.m = temp.m;
            obj.b = temp.b;
        end
        function data = getAverageData(obj,varargin)
            %
            %   data = getAverageData(obj,varargin)
            %
            %   Currently only returns the average from the last
            %   acquisition period.
            %
            %   Optional Inputs
            %   ---------------
            %   channel : ''
            %   as_vector : default true
            %       If false returns as a struct where fields
            %       are the channels.
            %   x_range : NYI
            %   seconds_back : NYI
            %
            %
            %   Examples
            %   ---------
            %   obj.getAverageData('channel','my_chan')
            %   obj.getAverageData('as_vector',false)
            %
            %   See Also
            %   --------
            %   daq2.session.
            
            in.seconds_back = []; %NYI
            in.x_range = []; %NYI
            in.channel = '';
            in.as_vector = true;
            in = daq2.sl.in.processVarargin(in,varargin);
            
            %This gets computed during the read callback
            avg_local = obj.avg_data;
            
            if ~isempty(in.channel)
                short_names = obj.acquired_data.short_names;
                I = find(strcmp(short_names,in.channel),1);
                if isempty(I)
                    obj.cmd_window.logErrorMessage(...
                        'Unable to find specified channel')
                    data = NaN;
                else
                    data = avg_local(I);
                end
            elseif in.as_vector
                data = avg_local;
            else
                data = struct;
                short_names = obj.acquired_data.short_names;
                for i = 1:length(short_names)
                    data.(short_names{i}) = avg_local(i);
                end
            end
            
        end
        function readDataCallback(obj,source,event)
            %
            %   JAH TODO: I don't think these inputs are accurate
            %
            %   Inputs
            %   ------
            %   Non-Parallel -------------------
            %       source: Matlab daq session
            %        event:
            %           TriggerTime: 7.3705e+05
            %                  Data: [1000×10 double]
            %            TimeStamps: [1000×1 double]
            %                Source: [1×1 daq.ni.Session]
            %             EventName: 'DataAvailable'
            %
            %   Parallel Case -------------------
            %
            %
            %   See Also
            %   --------
            %
            
            
            %Notes
            %------------
            %Who forces a redraw?
            %   when the window changes we automatically get a redraw
            
            %TODO: Log performance
            try
                
                obj.perf_monitor.logReadStart();
                
                if obj.is_parallel
                    decimated_data = event.decimated_data;
                else
                    %Format
                    %- matrix [n_samples_acquired x n_channels]
                    input_data = event.Data;
                    
                    %decimated_data is a cell array of arrays
                    decimated_data = obj.decimation_handler.getDecimatedData(input_data);
                end
                
                
                %Store average data of last collected set of data
                %--------------------------------------------------
                obj.avg_data = cellfun(@mean,decimated_data);
                %Calibrate averages
                obj.avg_data = obj.avg_data.*obj.m + obj.b;
                
                
                %Send to acquisition for memory storage
                %--------------------------------------------
                %daq2.input.acquired_data.addDAQData
                obj.acquired_data.addDAQData(decimated_data);
                
                
                %Save data to disk
                %-----------------------------------------
                %This is driving up laptop cpu usage by 20%
                %daq2.input.data_writer.addDAQSamples
                %fprintf(2,'Saving data\n');
                obj.data_writer.addDAQSamples(decimated_data);
                
                %Note, adding data doesn't force xlimits to change.
                %This needs to be done separately.
                
%                 %TODO: On figure close send out notify event
                try
                    if ~isempty(obj.iplot) && isvalid(obj.iplot)
                        obj.iplot.dataAdded(obj.acquired_data.daq_tmax,obj.avg_data);
                    end
                catch ME
                   %If  MATLAB:class:InvalidHandle then ok
                   %otherwise rethrow ...
                   if ~strcmp(ME.identifier,'MATLAB:class:InvalidHandle')
                       rethrow(ME)
                   end
                end
                
                obj.perf_monitor.logReadInternalEnd();
                
                %Execute read cb if needed
                %Ideally we would do listeners ...
                if ~isempty(obj.read_cb)
                    obj.read_cb(source,event);
                end
                
                obj.perf_monitor.logReadExternalEnd();
            catch ME
                if obj.daq_recording
                    rethrow(ME)
                end
                %We expect some errors may occur due to the async
                %nature of the acquisition relative to stopping the DAQ
            end
        end
    end
end

