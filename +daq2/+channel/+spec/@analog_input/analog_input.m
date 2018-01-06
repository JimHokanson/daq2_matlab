classdef analog_input
    %
    %   Class:
    %   daq2.channel.spec.analog_input
    %
    %   These are rather unpolished
    
    properties
        fs %-1 is max
        short_name = ''
        name = ''
        daq_port = ''
        device_id = ''
        measurement_type = ''
        
        range
        
        uncalibrated_default_ylim
        calibrated_default_ylim
    end
    
    methods
        function obj = analog_input(short_name,daq_port)

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
            
            if obj.fs == -1
                dec_rate = 1;
                fs_local = raw_session.rate;
            else
                %TODO: Verify fs not exceeded
                fs_local = obj.fs; 
                dec_rate = raw_session.rate/obj.fs;
                if ~sl.numbers.isIntegerValue(dec_rate)
                    %TODO: Clean this up, add detail
                   error('Resultant decimation rates are not all integers')  
                end
            end
            
            if ~isempty(obj.range)
                if length(obj.range) == 1
                    other = {'Range' [-obj.range obj.range]};
                else
                    other = {'Range' obj.range};
                end
            else
                other = {};
            end
            
            [ch,idx] = raw_session.addAnalogInput(device_id_local,...
                obj.daq_port,meas_type_local,other);
            
            chan = daq2.channel.analog_input_channel(ch,idx,fs_local,dec_rate,obj);
        end
    end
end

