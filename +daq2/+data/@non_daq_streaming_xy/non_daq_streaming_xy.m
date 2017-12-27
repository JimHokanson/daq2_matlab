classdef non_daq_streaming_xy < handle
    %
    %   Class:
    %   daq2.data.non_daq_streaming_xy
    
    properties
        name
        fs
        y_data
        x_data
        array_length
        n_samples_valid = 0
    end
    
    properties (Dependent)
        x_max
    end
    
    methods
        function value = get.x_max(obj)
            if obj.n_samples_valid == 0
                value = NaN;
            else
                value = obj.x_data(obj.n_samples_valid);
            end
        end
    end
    
    methods
        function [x,y] = getRawData(obj)
            n_valid = obj.n_samples_valid;
            x = obj.x_data(1:n_valid); 
            y = obj.y_data(1:n_valid);
        end
        function obj = non_daq_streaming_xy(name)
            %
            %   obj = daq2.data.non_daq_streaming_xy(name)
            
            obj.name = name;
            n_samples_init = 1e6;
            obj.y_data = zeros(1,n_samples_init);
            obj.x_data = zeros(1,n_samples_init);
            obj.array_length = n_samples_init;
        end
        function addSamples(obj,new_y_data,new_x_data)
            n_samples_new = length(new_y_data); 
            n_samples_total = n_samples_new + obj.n_samples_valid;
            if  n_samples_total > obj.array_length
                %resize
                n_samples_grow = round(obj.array_length*0.5);
                new_length = n_samples_grow + obj.array_length;
                if new_length < n_samples_total
                    n_samples_grow = n_samples_total;
                end
                obj.y_data = [obj.y_data zeros(1,n_samples_grow)];
                obj.x_data = [obj.x_data zeros(1,n_samples_grow)];
                obj.array_length = length(obj.data); 
            end
            
            start_I = obj.n_samples_valid + 1;
            end_I = obj.n_samples_valid + n_samples_new;
            obj.y_data(start_I:end_I) = new_y_data;
            obj.x_data(start_I:end_I) = new_x_data;
            obj.n_samples_valid = end_I;
        end
    end
end

