classdef output_data_handler < handle
    %
    %   Class:
    %   daq2.output_data_handler
    
    properties
        raw_session
        perf_mon
        cmd_window
        h_timer
        
        %Local properties on behavior
        write_cb
        
        %Assume we've initialized elsewhere ...
        n_writes = 1;
    end
    
    methods
        function obj = output_data_handler(raw_session,perf_mon,cmd_window)
            %
            %   obj = daq2.output_data_handler(raw_session,perf_mon)
            
            obj.raw_session = raw_session;
            obj.perf_mon = perf_mon;
            obj.cmd_window = cmd_window;
        end
        function initForStart(obj)
            
            %Called just before starting the DAQ
            
            
            
            TIMER_TAG = 'daq_output_timer';
            
            %Killing of any timers that may have escaped 
            old_timers = timerfindall('Tag',TIMER_TAG);
            if ~isempty(old_timers)
                for i = 1:length(old_timers)
                    try %#ok<TRYNC>
                        stop(old_timers(i));
                    end
                    try %#ok<TRYNC>
                        delete(old_timers(i));
                    end
                end
            end
            
            if obj.raw_session.n_analog_outputs > 0
                
                %Is this ever ok????
                if isempty(obj.raw_session.write_cb)
                    error('No function specified to repopulate output')
                end
                
                
                %TODO: Period should be based on the refill rate
                %Hardcoding low here
                obj.h_timer = timer('ExecutionMode','fixedRate','Period',0.05,...
                    'TimerFcn',@(~,~)obj.writeDataTimerCallback);
                
                set(obj.h_timer,'tag',TIMER_TAG);
                
                start(obj.h_timer);
                
                obj.write_cb = obj.raw_session.write_cb;
            end
        end
        function stop(obj)
            obj.killTimer();
        end
        function killTimer(obj)
            try %#ok<TRYNC>
                stop(obj.h_timer);
            end
            try %#ok<TRYNC>
                delete(obj.h_timer);
            end
        end
        function writeDataTimerCallback(obj)
            %
            %   The idea here is that the timer will be more agressive
            %   than just a listener in interuptting things to maintain
            %   the output buffer. Eventually I want this on a separate
            %   thread.
            
            try
                r = obj.raw_session;
                if r.is_running && (r.n_scans_queued <= r.write_cb_samples)
                    
                    obj.n_writes = obj.n_writes + 1;
                    
                    %TODO: Add in performance logging ...
                    feval(obj.write_cb,obj.raw_session.h,struct);
                end
            catch ME
                assignin('base','last_ME_from_timer',ME);
                %TODO: Can we display this like it would normally be???
                
                fprintf(2,'An error occurred, see "last_ME_from_timer" in the base workspace\n');
                killTimer(obj);
            end
        end
        function delete(obj)
            killTimer(obj);
        end
    end
end

