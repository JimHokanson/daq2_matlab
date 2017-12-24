classdef analog_output
    %
    %   Class:
    %   daq2.channel.spec.analog_output
    %
    %   See Also
    %   ---------
    %   daq2.channel.spec.analog_input
    
    properties
        short_name
        name
        daq_port
        device_id
        measurement_type = ''
    end
    
    methods
        function obj = analog_output(short_name,daq_port)
            
         	obj.short_name = short_name;
            obj.daq_port = daq_port;
            
            %We may change this later ...
            obj.name = short_name; 
        end
        function chan = addToDAQ(obj,raw_session,available_devices)
            if isempty(obj.device_id)
                device_id_local = available_devices(1).ID;
            else
                device_id_local = obj.device_id;
            end
            
            if isempty(obj.measurement_type)
                meas_type_local = 'Voltage';
            else
                meas_type_local = obj.measurement_type;
            end
            
            [ch,idx] = addAnalogOutputChannel(...
                raw_session.h,...
                device_id_local,...
                obj.daq_port,...
                meas_type_local);
            
            chan = daq2.channel.analog_output_channel(ch,idx,obj);
            
        end
    end
end

