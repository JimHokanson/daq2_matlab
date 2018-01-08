classdef analog_input_channel
    %
    %   Class:
    %   daq2.channel.analog_input_channel
    %
    %   See Also
    %   --------
    %   daq2.raw_session
    %   daq2.channel.spec.analog_input
    %   daq2.channel.analog_output_channel
    
    %{
                  h: [1×1 daq.ni.AnalogInputVoltageChannel]
         short_name: 'stim_mon'
               name: 'stimulus monitor'
                 fs: 10000
    decimation_rate: 1
          daq_index: 1
               spec: [1×1 daq2.channel.spec.analog_input]
    %}
    
    properties
        h       %daq.ni.AnalogInputVoltageChannel OR NULL
        short_name
        name
        fs
        decimation_rate
        daq_index
        spec
    end
    
    methods
        function obj = analog_input_channel(h,daq_index,fs,dec_rate,spec)
            obj.fs = fs;
            obj.decimation_rate = dec_rate;
            obj.h = h;
            obj.daq_index = daq_index;
            obj.spec = spec;
            obj.short_name = spec.short_name;
            obj.name = spec.name;
        end
        function s = struct(obj)
            %Won't save h
            s.short_name = obj.short_name;
            s.name = obj.name;
            s.fs = obj.fs;
            s.decimation_rate = obj.decimation_rate;
            s.daq_index = obj.daq_index;
            %specc not yet implemented
        end
    end
end

