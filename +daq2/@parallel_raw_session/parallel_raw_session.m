classdef parallel_raw_session
    %
    %   Class:
    %   daq2.parallel_raw_session
    
    properties
        d0 = '------- Internal Props -------'
        perf_mon
        command_window
        options
        pool
        feval_future
        q_send
    end
    
    properties
        d1 = '--------- DAQ2 Props -------'
    end
    
    properties
        d2 = '--------- DAQ Props --------'
    end
    
    methods
        function obj = parallel_raw_session(type,perf_mon,command_window)
            %Max amount of time to wait for the parallel process
            %to launch and to send a queue back to this process
            MAX_WAIT_PARALLEL_STARTUP = 5; %seconds
            
            obj.perf_mon = perf_mon;
            obj.command_window = command_window;
            
            %Requires parallel pool toolbox
            %------------------------------
            obj.pool = gcp('nocreate');
            if isempty(obj.pool)
                obj.command_window.logMessage('Staring parallel pool for daq session')
                obj.pool = gcp;
                obj.command_window.logMessage('Parallel pool initialized')
            end
            
            q_receive = parallel.pool.PollableDataQueue;
            
            %Launch the parallel daq session
            %------------------------------------------------
            fh = @daq2.parallel_session_worker;
            obj.feval_future = parfeval(gcp,fh,0,type,q_receive);
            
            %now obtain the q
            %----------------------------
            %- we need to wait for the worker to start and for it to send
            %data back to us
            t = tic;
            while (toc(t) < MAX_WAIT_PARALLEL_STARTUP && q_receive.QueueLength == 0)
                pause(0.1);
            end
            
            if q_receive.QueueLength == 0
                %TODO: Output to command window
                %Since we can fail in the constructor, we should have the
                %constructor wrapped in a static creation method
                error('Unable to receive queue back from parallel function');
            else
                obj.q_send = q_receive.poll();
                if ~isa(obj.q_send,'parallel.pool.PollableDataQueue')
                    error('Received data not of expected type')
                end
            end
            
            afterEach(q_receive, @(data) obj.receiveEvent(data));
        end
        function receiveEvent(obj,data)
            %
            %   Commands
            %   --------
            %   See Also:
            %   daq2.parallel_session_worker
            
            afterEach(q, @(data) plot(data));
        end
    end
end

function h__updateProp(obj,name,value)

end
function h__getProp(obj,name,value)

end

