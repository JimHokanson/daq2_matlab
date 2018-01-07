classdef parallel_session_log < handle
    %
    %   Class:
    %   daq2.parallel.parallel_session_log
    %
    %   This was written to handle logging of the time it takes to process 
    %   and send the acquired data.
    
    properties
        I1
        I2
        etimes_process
        etimes_send
    end
    
    methods
        function obj = parallel_session_log()
            %
            %   obj = daq2.parallel.parallel_session_log
            
            obj.etimes_process = zeros(1,1e5);
            obj.etimes_send = zeros(1,1e5);
            obj.I1 = 0;
            obj.I2 = 0;
        end
        function addProcessTime(obj,etime)
            I = obj.I1 + 1;
            if I > 1e5
                I = 1;
            end
            obj.etimes_process(I) = etime;
            obj.I1 = I;
        end
        function addSendTime(obj,etime)
         	I = obj.I2 + 1;
            if I > 1e5
                I = 1;
            end
            obj.etimes_send(I) = etime;
            obj.I2 = I;
        end
    end
end

