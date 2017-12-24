classdef analog_input_channel
    %
    %   Class:
    %   daq2.channel.analog_input_channel
    
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
        function obj = analog_input_channel(fs,dec_rate,h,daq_index,spec)
            obj.fs = fs;
            obj.decimation_rate = dec_rate;
            obj.h = h;
            obj.daq_index = daq_index;
            obj.spec = spec;
            obj.short_name = spec.short_name;
            obj.name = spec.name;
        end
    end
end

