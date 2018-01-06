classdef parallel_output_data_handler < handle
    %
    %
    %   Placehold for session code. This doesn't currently
    %   do anything except swallow method calls.
    
    properties
      	raw_session
        perf_mon
        cmd_window
    end
    
    methods
        function obj = parallel_output_data_handler(raw_session,perf_mon,cmd_window)
            %
            %   obj = daq2.parallel_output_data_handler(raw_session,perf_mon)
            
            obj.raw_session = raw_session;
            obj.perf_mon = perf_mon;
            obj.cmd_window = cmd_window;
        end
        function initForStart(obj)
        end
        function stop(obj)
            
        end
       	function addStimulator(obj,stim_fcn,params)
%             fs = obj.raw_session.rate;
%             min_queue_samples = obj.raw_session.write_cb_samples;
%             obj.stimulator = stim_fcn(fs,min_queue_samples,params);
            
            obj.raw_session.addStimulator(stim_fcn,params);
        end
        function queueMoreData(obj,n_seconds_add)
            obj.raw_session.queueMoreData(n_seconds_add);
        end
        function updateStimParams(obj,s)
            obj.raw_session.updateStimParams(s);
        end
    end
end

