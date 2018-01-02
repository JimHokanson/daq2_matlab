classdef decimation_handler < handle
    %
    %   Class:
    %   daq2.input.decimation_handler
    
    properties
        raw_session
        perf_monitor
        decimation_rates
        n_chans
        t_log
    end
    
    methods
        function obj = decimation_handler(raw_session,perf_monitor)
            %
            %   obj = daq2.input.decimation_handler(raw_session,perf_monitor);
            
            obj.raw_session = raw_session;
            obj.perf_monitor = perf_monitor;
            
            ai_chans = raw_session.getAnalogInputChans();
            
            obj.decimation_rates = [ai_chans.decimation_rate];
            
            obj.n_chans = length(obj.decimation_rates);
        end
        
    end
    
    methods
        function dec_data = getDecimatedData(obj,input_data)
            %
            %   Inputs
            %   ------
            %   input_data : [samples x channels]
            %   
                        
            
            %TODO: Add perf_mon back in ...
            %obj.t_log.start();

            %TODO: This currently fails if we aren't reading in complete
            %values ...
            %i.e. if we are sampling at 1 Hz, and the daq rate is 1000
            %and we read new data every 0.2 seconds, we need to wait until
            %we have 1 seconds worth of data (5 reads) before
            %we can output 1 sample.
            
            dec_data = cell(1,obj.n_chans);
            dec_rates = obj.decimation_rates;
            n_samples = size(input_data,1);
            for i = 1:obj.n_chans
                cur_dec_rate = dec_rates(i);
                n_samples_out = n_samples/cur_dec_rate;
                temp_data = reshape(input_data(:,i),[cur_dec_rate n_samples_out]);
                
                %Store as column vectors
                dec_data{i} = mean(temp_data,1)';
            end

            %obj.t_log.stop();
        end
    end
end

