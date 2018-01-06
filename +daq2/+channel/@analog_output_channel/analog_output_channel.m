classdef analog_output_channel
    %
    %   Class:
    %   daq2.channel.analog_output_channel
    %
    %   See Also
    %   --------
    %   
    
    properties
        h       %daq.ni.AnalogOutputVoltageChannel
        short_name
        name
%         fs
%         decimation_rate
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
        function s = struct(obj)
            s.short_name = obj.short_name;
            s.name = obj.name;
            %s.fs = obj.fs;
            %s.decimation_rate = obj.decimation_rate;
            s.daq_index = obj.daq_index;
        end
    end
end

