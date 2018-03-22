classdef saved_data_explorer
    %
    %   Class:
    %   daq2.saved_data_explorer
    %
    %   Not yet implemented
    %
    %   Goals:
    %   1) Launch interactive plot
    %   2) Have some table display of all variables ...
    %
    %   See Also
    %   --------
    %   daq2.explore
    %
    %   Data Format
    %   -----------
    %   daq2__raw_session - info on timing
    %   daq__<chan_name> - saved data
    %   iplot_session_data (optional) 
    %       - may include comments & calibrations
    %   - everything else is optional that has been added by the user
    
    properties (Hidden)
        h
    end
    
    properties
       trial_status
       user_data %struct
       daq_session
       analog_inputs
    end
    
    methods
        function obj = saved_data_explorer(file_path)
            %   
            %   obj = daq2.saved_data_explorer(file_path)
            %
            
            obj.h = matfile(file_path);
            
            obj.trial_status = obj.h.trial_status;
            obj.daq_session = obj.h.daq2_raw_session;
            
            %Extracting user data
            %-------------------------------------
            
            
            fn = fieldnames(obj.h);
            
            %These have special meaning so we'll ignore them
            fields_to_ignore = {...
                'Properties',...
                'iplot_session_data',...
                'daq2_raw_session',...
                'trial_status'};
            fn(ismember(fn,fields_to_ignore)) = [];
            
            is_daq_chan = cellfun(@(x) strncmp(x,'daq__',5),fn);
            
            user_names = fn(~is_daq_chan);
            
            s = struct;
            for i = 1:length(user_names)
               cur_name = user_names{i};
               s.(cur_name) = obj.h.(cur_name);
            end
            
            obj.user_data = s;
            
            %Extracting daq data
            %-------------------------------------------
            keyboard
            s = obj.daq_session;
            ANALOG_INPUT = 1;
            I = find(s.chan_types == ANALOG_INPUT);
            n_chans = length(I);
            temp = cell(1,n_chans);
            for i = 1:n_chans
                chan_spec = s.chans{I(i)};
            end
            
        end
    end
end

