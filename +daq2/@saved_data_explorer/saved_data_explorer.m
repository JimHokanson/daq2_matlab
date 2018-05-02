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
    %
    %   TODO:
    %   ------
    %   I think I want to rename this class to saved_data
    
    properties (Hidden)
        h
        analog_daq_names
    end
    
    properties
        file_path
       trial_status
       user_data %struct
       %Anything that is specified by the user goes in this struct. These
       %fields are created by calls to save user data functions
       
       daq_session %struct
       % 
       %    Contains options and channel specs
       
    %Example, may be out of date
    %------------------------------
    %                     VERSION: 1
    %          STRUCT_DATE: 737072.414046933
    %                 TYPE: 'daq2.parallel_raw_session'
    %                chans: {1×11 cell}
    %           chan_types: [1×11 double]
    %                 rate: 10000
    %         read_cb_time: 0.33
    %      read_cb_samples: 3300
    %        write_cb_time: 0.4
    %     write_cb_samples: 4000
       
       analog_channel_names
    end
    
    methods
        function obj = saved_data_explorer(file_path)
            %   
            %   obj = daq2.saved_data_explorer(file_path)
            %
            
            obj.file_path = file_path;
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
            s = obj.daq_session;
            ANALOG_INPUT = 1;
            I = find(s.chan_types == ANALOG_INPUT);
            n_chans = length(I);
            temp = cell(1,n_chans);
            temp2 = cell(1,n_chans);
            for i = 1:n_chans
                chan_spec = s.chans{I(i)};
                temp{i} = ['daq__' chan_spec.short_name];
                temp2{i} = chan_spec.name; 
            end
            obj.analog_daq_names = temp;
            obj.analog_channel_names = temp2;
        end
        function plotInteractive(obj)
            
        end
    end
end

