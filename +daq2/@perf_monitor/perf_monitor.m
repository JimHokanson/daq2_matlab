classdef perf_monitor
    %
    %   Class:
    %   daq2.perf_monitor
    
    properties
        cmd_window
        
        %All Trial Based Properties?
        trial_duration
        
        %Trial Based Properties
    end
    
    methods
        function obj = perf_monitor(cmd_window)
            obj.cmd_window = cmd_window;
        end
    end
end

