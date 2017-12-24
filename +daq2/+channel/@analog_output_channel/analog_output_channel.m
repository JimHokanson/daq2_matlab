classdef analog_output_channel
    %
    %   Class:
    %   daq2.channel.analog_output_channel
    
    properties
        h
        short_name
        name
        fs
        decimation_rate
        daq_index
        spec
    end
    
    methods
        function obj = analog_output_channel(h,daq_index,spec)
            obj.h = h;
            obj.daq_index = daq_index;
            obj.spec = spec;
            obj.short_name = spec.short_name;
            obj.name = spec.name;
        end
    end
end

