classdef parallel_output_data_handler < handle
    %
    %   Class:
    %   daq2.parallel_output_data_handler
    %
    %   See Also
    %   --------
    %   daq2.parallel_raw_session
    
    properties
      	raw_session   %daq2.parallel_raw_session
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
            %Nothing needed
        end
        function stop(obj)
            %Nothing needed
        end
    end
    %Stim control methods =================================================
    methods
        %These calls only work with the parallel_raw_session, not the 
        %standard raw_session class
       	function addStimulator(obj,stim_fcn,params)
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

