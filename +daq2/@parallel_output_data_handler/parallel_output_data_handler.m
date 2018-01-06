classdef parallel_output_data_handler < handle
    %
    %
    
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
    end
end

