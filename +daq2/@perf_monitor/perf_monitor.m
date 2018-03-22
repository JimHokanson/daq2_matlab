classdef perf_monitor < handle
    %
    %   Class:
    %   daq2.perf_monitor
    
    properties
        cmd_window
        
        %All Trial Based Properties?
        trial_duration
        
        %Trial Based Properties
        
        %daq2.input_data_handler.readDataCallback
        %--------------------------------------------
        n_read_calls
        read_I
        h_read_tic
        
        elapsed_read_internal_time
        elapsed_read_external_time
        
        %--------------------------------------------
        log_size %How much data to log before rolling over
        
        raw_session %daq2.raw_session OR daq2.parallel_raw_session
    end
    
    methods
        function obj = perf_monitor(cmd_window)
            LOG_SIZE = 1000;
            obj.cmd_window = cmd_window;
            
            obj.elapsed_read_internal_time = zeros(1,LOG_SIZE);
            obj.elapsed_read_external_time = zeros(1,LOG_SIZE);
            
            obj.log_size = LOG_SIZE;
        end
        function linkObjects(obj,raw_session)
            obj.raw_session = raw_session;
        end
    end
    
    %Read handling
    %----------------------------
    methods
        function resetRead(obj)
            obj.read_I = 0;
            obj.n_read_calls = 0;
            obj.elapsed_read_internal_time(:) = 0;
            obj.elapsed_read_external_time(:) = 0;
        end
        function logReadStart(obj)
            obj.n_read_calls = obj.n_read_calls + 1;
            if obj.read_I >= obj.log_size
                obj.read_I = 1;
            else
                obj.read_I = obj.read_I + 1;
            end
            obj.h_read_tic = tic;
        end
        function logReadInternalEnd(obj) 
            obj.elapsed_read_internal_time(obj.read_I) = toc(obj.h_read_tic);
        end
        function logReadExternalEnd(obj) 
            obj.elapsed_read_external_time(obj.read_I) = ...
                toc(obj.h_read_tic) - obj.elapsed_read_internal_time(obj.read_I);
        end
    end
end

