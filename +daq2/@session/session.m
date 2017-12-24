classdef session < handle
    %
    %   Class:
    %   daq2.session
    
    events
        
    end
    
    properties
        raw_session
        perf_monitor
        input_data_handler
        output_data_handler
        options
        recorded_data
        
        %TODO: Provide example in this package
        cmd_window
        %
        %Interface:
        %logMessage(string,formatting_varargin)
        %logError(string,formmatting_varargin)
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
            obj.raw_session = daq2.raw_session(type,obj.cmd_window);
            obj.perf_monitor = daq2.perf_monitor(obj.cmd_window);
            
            
            %Input/Output Handlers
            %------------------------------------------------------
            obj.input_data_handler = daq2.input_data_handler(...
                obj.raw_session,obj.perf_monitor,obj.cmd_window,options);
            obj.output_data_handler = daq2.output_data_handler(...
                obj.raw_session,obj.perf_monitor,obj.cmd_window);
            
            
            
            %Listeners
            %------------------------------------
            h = obj.raw_session.h;
            %- Writing handled in output_data_handler
            %- Reading in input_data_handler
            h.addlistener('ErrorOccurred',@obj.errorHandlerCallback);
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
        function startBackground(obj,varargin)
            
            in.trial_id = [];
            in.save_suffix = '';
            in.save_prefix = '';
            in = sl.in.processVarargin(in,varargin);
            
            obj.input_data_handler.initForStart(in.trial_id,in.save_prefix,in.save_suffix);
            obj.output_data_handler.initForStart();
            obj.raw_session.startBackground();
        end
        function stop(obj)
            obj.raw_session.stop();
            obj.output_data_handler.stop();
            obj.input_data_handler.stop();
        end
        function abort(obj)
            obj.raw_session.stop();
            obj.output_data_handler.stop();
            obj.input_data_handler.abort();
        end
        function addChannelsBySpec(obj,chan_specs)
            obj.raw_session.addChannelsBySpec(chan_specs);
        end
        function errorHandlerCallback(obj,source,event)
            obj.abort();
            %TODO: Do we want to add data to any file ... 
            obj.cmd_window.logError(event.Error.message);
        end
    end
end

