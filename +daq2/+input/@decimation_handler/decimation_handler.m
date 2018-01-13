classdef decimation_handler < handle
    %
    %   Class:
    %   daq2.input.decimation_handler
    
    %{
        
        decimation_rates = [1 10 100]
        
        N = 1e6;
        d1 = (1:N)';
        data = [d1,d1,d1];
    
        profile on
        tic
        for k = 1:100
            d = daq2.input.decimation_handler(decimation_rates);
            I = unique(round((rand(1,5))*N));

            if I(1) == 1
                I(1) = 2;
            end

            I(end) = N;


            dec_data1 = cell(1,3);
            end_I = 0;
            for i = 1:length(I)
                start_I = end_I + 1;
                end_I = I(i);
                temp = d.getDecimatedData(data(start_I:end_I,:));    
                for j = 1:3
                    dec_data1{j} = vertcat(dec_data1{j},temp{j});
                end
            end

            dec_data2 = d.getDecimatedData(data); 

            if ~isequal(dec_data1,dec_data2)
                error('Not equal')
            end
        end
        toc
        profile off
        profile viewer
    
    %}
    
    properties
        samples_per_read
        
        decimation_rates
        %fs1 = 5000
        %fs2 = 10
        %
        %=> decimation rate = 500
        %=> So  we need 500 samples to get 1 sample ...
        %
        %A decimation rate is always how many samples we need to get before
        %we have a whole sample
        
        
        %State
        %--------------
        partial_buffers
        n_partial
        
        n_chans
    end
    
    methods
        function obj = decimation_handler(samples_per_read,decimation_rates)
            %
            %   obj = daq2.input.decimation_handler(decimation_rates);
                        
            obj.decimation_rates = decimation_rates;
            
            obj.n_chans = length(obj.decimation_rates);
            
            obj.n_partial = zeros(1,obj.n_chans);
            obj.partial_buffers = cell(1,obj.n_chans);
            for i = 1:obj.n_chans
                obj.partial_buffers{i} = zeros(1,obj.decimation_rates(i));
            end
        end
        
    end
    
    methods
        function dec_data = getDecimatedData(obj,input_data)
            %
            %   Inputs
            %   ------
            %   input_data : [samples x channels]
            %   
                        

            %TODO: This currently fails if we aren't reading in complete
            %values ...
            %i.e. if we are sampling at 1 Hz, and the daq rate is 1000
            %and we read new data every 0.2 seconds, we need to wait until
            %we have 1 seconds worth of data (5 reads) before
            %we can output 1 sample.
            
            dec_data = cell(1,obj.n_chans);
            dec_rates = obj.decimation_rates;
            I = obj.n_partial;
            
            n_new = size(input_data,1);
            for i = 1:obj.n_chans
                n_per_sample = dec_rates(i);
                if n_per_sample == 1
                    dec_data{i} = input_data(:,i);
                    continue
                end
                
                n_old = I(i);
                
                first_sample = [];
                
                %start_I = 1;
                if n_old == 0
                    start_I = 1;
                else
                    %Either we add more samples or we have enough
                    %
                    %I(i) - how many we currently have
                    %n_samples - how many new we have
                    %cur_dec_rate - how many to get 1 sample
                    if n_old + n_new >= n_per_sample
                        n_grab = n_per_sample - n_old;
                        
                        obj.partial_buffers{i}(n_old+1:end) = input_data(1:n_grab,i);
                        
                        first_sample = mean(obj.partial_buffers{i});
                        I(i) = 0;
                        
                        start_I = n_grab + 1;
                    else
                        %We don't have enough for a full sample. Store the 
                        %data and continue
                        obj.partial_buffers{i}(n_old+1:n_old+n_grab) = input_data(1:n_grab,i);
                        continue
                    end
                end
                
                n_full_samples = floor((n_new-start_I+1)/n_per_sample);
                
                next_I = start_I + n_full_samples*n_per_sample;
                
                temp_data = input_data(start_I:next_I-1,i);
                temp_data = reshape(temp_data,[n_per_sample n_full_samples]);
                
                if isempty(first_sample)
                    dec_data{i} = mean(temp_data,1)';
                else
                    dec_data{i} = [first_sample; mean(temp_data,1)'];
                end
                            
                if next_I <= n_new
                    %Then we have extras to store ...
                    n_extra = n_new-next_I + 1;
                    obj.buffers{i}(1:n_extra) = input_data(next_I:end,i);
                    I(i) = n_extra;
                end
                
%                 
%                 
%                 n_samples_out = n_new/n_per_sample;
%                 temp_data = reshape(input_data(:,i),[n_per_sample n_samples_out]);
%                 
%                 %Store as column vectors
%                 dec_data{i} = mean(temp_data,1)';
            end
            
            obj.n_partial = I;

        end
    end
end

