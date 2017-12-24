classdef input_data_handler < handle
    %
    %   Class:
    %   daq2.input_data_handler
    %
    %   See Also
    %   daq2.output_data_handler
    
    events
        
    end
    
    properties
        raw_session
        perf_monitor
        cmd_window
        options
        
        %Objects for processing acquired data
        decimation_handler
        acquired_data
        data_writer
        read_cb
    end
    
    methods
        function obj = input_data_handler(raw_session,perf_monitor,cmd_window,options)
            %
            %   obj = daq2.input_data_handler(raw_session,perf_monitor,cmd_window)
            
            obj.raw_session = raw_session;
            obj.perf_monitor = perf_monitor;
            obj.cmd_window = cmd_window;
            obj.options = options;
            
            raw_session.h.addlistener('DataAvailable',@obj.readDataCallback);
            
        end
        function initForStart(obj,trial_id,save_prefix,save_suffix)
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
            %TODO: Do we want to save any daq properties?????
            %=> perhaps convert the chan settings to a struct and save???
        end
        function abort(obj)
            
        end
        function stop(obj)
            
        end
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
            
            obj.data_writer.addDAQSamples(decimated_data);
            
            if ~isempty(obj.read_cb)
               obj.read_cb(source,event); 
            end
        end
    end
end

