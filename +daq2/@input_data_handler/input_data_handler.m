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
        raw_session
        perf_monitor
        cmd_window
        options
        
        %Objects for processing acquired data
        decimation_handler
        acquired_data    %daq2.input.acquired_data
        data_writer      %daq2.input.data_writer   
        read_cb
        iplot
        
        iplot_listen    %Event listener
        %Listens for the session to be updated and saves any changes to
        %disk
    end
    
    methods
        function obj = input_data_handler(raw_session,perf_monitor,cmd_window,options)
            %
            %   obj = daq2.input_data_handler(raw_session,perf_monitor,cmd_window)
            
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
            %
            %
            
            %Initialize
            %- data writing
            %- decimation handling
            obj.decimation_handler = daq2.input.decimation_handler(...
                obj.raw_session,obj.perf_monitor);
            obj.acquired_data = daq2.input.acquired_data(...
                obj.raw_session,obj.perf_monitor,obj.cmd_window,obj.options);
            obj.data_writer = daq2.input.data_writer(...
                obj.raw_session,obj.perf_monitor,obj.cmd_window,obj.options,...
                trial_id,save_prefix,save_suffix);
            
            obj.read_cb = obj.raw_session.read_cb;
        end
        function iplot = plotDAQData(obj,varargin)
            %
            %
            %   iplot = plotDAQData(obj,varargin)
            %
            %   See Also
            %   --------
            %   daq2.input.acquired_data>plotDAQData
            
            if isempty(obj.acquired_data)
                obj.cmd_window.logErrorMessage(...
                    'Unable to add non-daq data when not recording')
                iplot = [];
                return
            end
            iplot = obj.acquired_data.plotDAQData(varargin{:});
            obj.iplot = iplot;
            
            %When the session updates (like comments being added)
            %then save the session data to disk
            obj.iplot_listen = addlistener(iplot.eventz,'session_updated',@obj.sessionUpdated);
        end
        function sessionUpdated(obj,source,event_data)  %#ok<INUSD>
            %
            
            s = obj.iplot.getSessionData;
            obj.saveData('iplot_session_data',s);
        end
        function saveData(obj,name,data)
            %
            %   saveData(obj,name,data)
            
            %This logic is not obvious - should be => if ~obj.recording ...
          	if isempty(obj.acquired_data)
                obj.cmd_window.logErrorMessage(...
                    'Unable to add non-daq data when not recording')
                return
            end
            obj.data_writer.saveData(name,data);
        end
% %         function addNonDaqData(obj,name,data) %#ok<INUSD>
% %             if isempty(obj.acquired_data)
% %                 obj.cmd_window.logErrorMessage(...
% %                     'Unable to add non-daq data when not recording')
% %                 return
% %             end
% %             error('Not yet implemented')
% %         end
        function xy_data = getXYData(obj,name)
            if isempty(obj.acquired_data)
                obj.cmd_window.logErrorMessage(...
                    'Unable to add non-daq xy data when not recording')
                return
            end
            xy_data = obj.acquired_data.getXYData(name);
        end
        function addNonDaqXYData(obj,name,y_data,x_data)
            if isempty(obj.acquired_data)
                obj.cmd_window.logErrorMessage(...
                    'Unable to add non-daq xy data when not recording')
                return
            end
            obj.acquired_data.addNonDaqXYData(name,y_data,x_data);
            
            %This would be better as a 2 column variable ...
            %- need to update data writer ...
            obj.data_writer.addSamples(sprintf('%s__x',name),x_data);
            obj.data_writer.addSamples(sprintf('%s__y',name),y_data);
        end
    end
    methods
        function abort(obj,ME)
            %???? Do we want to close the plotting figure?????
            delete(obj.iplot_listen);
            obj.iplot = [];
            obj.data_writer.closerWriterWithError(ME);
            obj.acquired_data = [];
            obj.data_writer = [];
        end
        function stop(obj)
            %%???? Do we want to close the plotting figure?????
            delete(obj.iplot_listen);
            obj.iplot = [];
            obj.data_writer.closeWriter();
            obj.acquired_data = [];
            obj.data_writer = [];
        end
    end
    methods
        function readDataCallback(obj,source,event)
            %
            %   source: Matlab daq session
            %   event: 
            %       TriggerTime: 7.3705e+05
            %            Data: [1000×10 double]
            %      TimeStamps: [1000×1 double]
            %          Source: [1×1 daq.ni.Session]
            %       EventName: 'DataAvailable'
            %  
            
            %TODO: Log perormance
            
            %Format
            %- matrix [n_samples_acquired x n_channels]
            input_data = event.Data;
            
            decimated_data = obj.decimation_handler.getDecimatedData(input_data);
            
            obj.acquired_data.addDAQData(decimated_data);
            obj.data_writer.addDAQSamples(decimated_data);
            
            if ~isempty(obj.iplot)
                obj.iplot.dataAdded(obj.acquired_data.daq_tmax);
            end
            
            if ~isempty(obj.read_cb)
               obj.read_cb(source,event); 
            end
        end
    end
end

