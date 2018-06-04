classdef saved_data
    %
    %   Class:
    %   daq2.saved_data
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
    
    properties (Hidden)
        h
        analog_daq_names
        analog_channel_specs
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
        
        iplot_session %struct
        comments
    end
    
    methods
        function obj = saved_data(file_path)
            %
            %   obj = daq2.saved_data(file_path)
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
            temp = cell(n_chans,1);
            temp2 = cell(n_chans,1);
            temp3 = cell(n_chans,1);
            for i = 1:n_chans
                chan_spec = s.chans{I(i)};
                temp{i} = ['daq__' chan_spec.short_name];
                temp2{i} = chan_spec.name;
                temp3{i} = chan_spec;
            end
            obj.analog_channel_specs = [temp3{:}];
            obj.analog_daq_names = temp;
            obj.analog_channel_names = temp2;
            
            %TODO: I don't think this will always exist ...
%             if isfield(obj.h,'iplot_session_data') %doesn't seem to work
            if ismember('iplot_session_data',fieldnames(obj.h))
                obj.iplot_session = obj.h.iplot_session_data;
                obj.comments = obj.iplot_session.comments;
            end
        end
        function iplot = plotInteractive(obj,varargin)
            
            in.h_fig = [];
            in = daq2.sl.in.processVarargin(in,varargin);
            
            if isempty(in.h_fig)
                h_fig = figure();
            else
                h_fig = in.h_fig;
                figure(h_fig)
            end
            clf(h_fig)
            n_chans = length(obj.analog_channel_names);
            h_axes = cell(n_chans,1);
            for i = 1:n_chans
                h_axes{i} = subplot(n_chans,1,i);
                data = obj.getAnalogData(i);
                plot(data)
            end
            [~,filename] = fileparts(obj.file_path);
            iplot = interactive_plot(h_fig,h_axes,...
                'axes_names',obj.analog_channel_names,...
                'title',filename);
            
            c = obj.comments;
            iplot.addComments(c.times,c.strings);
        end
        function data = getAnalogData(obj,channel_name_or_index,varargin)
            %
            %
            %
            %   Optional Inputs
            %   ---------------
            %   NOT YET SUPPORTED
            %
            %   data = obj.getAnalogData(1);
            
            in.time = [];
            in.samples = [];
            in = daq2.sl.in.processVarargin(in,varargin);
            
            %Step 1 - resolve channel
            %---------------------------
            if isnumeric(channel_name_or_index)
                channel_I = channel_name_or_index;
            else
                %TODO: Replace with string partial matching algo
                channel_name = channel_name_or_index;
                I = find(strcmp(obj.analog_channel_names,channel_name));
                if isempty(I)
                    error('Unable to find channel match')
                elseif length(I) > 2
                    error('Multiple channel matches found')
                end
                channel_I = I;
            end
            
            field_name = obj.analog_daq_names{channel_I};
            
            %This call loads the data from the matfile (uses subsref magic)
            %TODO: Support sample indexing
            raw_data = obj.h.(field_name); %(I1:I2)
            
            %TODO: Data needs to be calibrated ... 
            %TODO: This is extremely awkward and needs to be cleaned up ...
            chan_spec = obj.analog_channel_specs(channel_I);
            
            short_name = chan_spec.short_name;
            calibrations = obj.iplot_session.settings.axes_props.calibrations;
            for i = 1:length(calibrations)
               temp = calibrations{i};
               if ~isempty(temp)
                  c_name = temp.chan_name;
                  if strcmp(c_name,short_name)
                     m = temp.m;
                     b = temp.b;
                     raw_data = raw_data*m + b;
                     break;
                  end
               end
            end
            
            
            
            if ~exist('sci.time_series.data','class')
                data = raw_data;
                
            else
                %TODO: Support time ranges ...
                
                fs = chan_spec.fs;
                data = sci.time_series.data(raw_data,1/fs,'y_label',chan_spec.name);

                if ~isempty(obj.comments) && ~isempty(obj.comments.times)
                    keep_mask = ~obj.comments.is_deleted;
                    c = obj.comments;
                    comment_events = ...
                        sci.time_series.discrete_events(...
                        'comments',c.times(keep_mask),...
                        'msgs',c.strings(keep_mask));
                    data.addEventElements(comment_events);
                end
                
            end
        end
    end
end

