classdef analog_output
    %
    %   Class:
    %   daq2.channel.spec.analog_output
    %
    %   A spec functions as structure for defining a particular channel. It
    %   can be "sent" to the daq to create the specified channel.
    %
    %   See Also
    %   ---------
    %   daq2.channel.spec.analog_input
    %   daq2.channel.analog_output_channel
    
    properties
        %JAH TODO: Describe the difference between short_name and name
        short_name
        name
        
        daq_port    %string (or number???)
        %e.g. 'ao0'  
        %=> analog output 0
        
        device_id   %string or []
        %If the device ID is not specified then the first available device
        %is used. This is what we want when we only have a single device.
        
        measurement_type = 'Voltage' %string
        %I'm not entirely sure why we need to specificy this for an output.
        %Perhaps some DAQs allow for dynamic configuration between
        %different types?
    end
    
    methods
        function obj = analog_output(short_name,daq_port)
            %
            %   obj = daq2.channel.spec.analog_output(short_name,daq_port)
            %
            %   Note that the other properties can be updated after the
            %   object is created
            %
            %   Example
            %   -------
            %   obj = daq2.channel.spec.analog_output('stim_out','ao0')
            %
            %   See Also
            %   --------
            %   daq2.session.addChannelsBySpec
            
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
            
            meas_type_local = obj.measurement_type;
            
            [ch,idx] = raw_session.addAnalogOutput(device_id_local,...
                obj.daq_port,...
                meas_type_local);
            
            chan = daq2.channel.analog_output_channel(ch,idx,obj);
            
        end
    end
end

