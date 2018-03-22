classdef session_options
    %
    %   Class:
    %   daq2.session.session_options
    %
    %   See Also
    %   --------
    %   daq2.session
    
    properties
        use_parallel = true
        %Currently the non-parallel path is broken.
        
        default_trial_duration = 180;
      	base_save_path = ''
        command_window 
        
        min_write_data_time = 3 %Time in seconds
        %Currently we save to matfiles which is extremely inefficienct 
        %for streaming, particularly if we write at the same rate at which
        %we collect data. This option decouples the acquisition/plotting
        %rate from the data writing rate.
        %
        %By writing more data at once I expect that the 
    end
    
    methods
        function obj = session_options()
            %
            %   obj = daq2.session.session_options()
        end
    end
end

