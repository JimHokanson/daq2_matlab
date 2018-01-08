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
        default_trial_duration = 180;
      	base_save_path = ''
        command_window 
    end
    
    methods
        function obj = session_options()
            %
            %   obj = daq2.session.session_options()
        end
    end
end

