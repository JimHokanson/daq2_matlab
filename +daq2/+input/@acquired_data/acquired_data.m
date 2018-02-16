classdef acquired_data < handle
    %
    %   Class:
    %   daq2.input.acquired_data
    %
    %   The current design holds all acquired data in memory (although it 
    %   is also saved to disk as it is collected - elsewhere).
    %
    %   This class holds classes which have the data. It does not contain
    %   the raw data itself.
    %
    %   See Also
    %   --------
    %   daq2.input_data_handler
    %   daq2.input.data_writer
    %   big_plot.streaming_data
    
    properties
        raw_session
        perf_mon
        cmd_window
        
        short_names
        
        daq_entries %struct
        %objects are field in the struct
        
        daq_entries_array %array of objects
        
        n_chans
        non_daq_entries %fields of type ... NYI
        non_daq_xy_entries %fields of type
        %daq2.data.non_daq_streaming_xy
        ip
    end
    
    properties (Dependent)
        daq_tmax
    end
    
    methods
        function value = get.daq_tmax(obj)
            value = obj.daq_entries_array(1).t_max;
        end
    end
    
    methods
        function obj = acquired_data(raw_session,perf_mon,cmd_window,options)
            %
            %   obj = daq2.input.acquired_data(fs,names,dec_rates,ip,n_seconds_init)
            %
            %   Inputs
            %   ------
            %   fs :
            %       Sampling Rate of highest rate channel
            %   names :
            %       Names of the channels being recorded
            %   dec_rates :
            %       Decimation rates for each channel
            %   ip : interactive_plot
            %   n_seconds_init :
            %       How many seconds to allocate for each channel
            %
            
            obj.raw_session = raw_session;
            obj.perf_mon = perf_mon;
            obj.cmd_window = cmd_window;
            
            %obj.ip = ip;
            
            ai_chans = raw_session.getAnalogInputChans();
            
            obj.daq_entries = struct;
            obj.non_daq_entries= struct;
            obj.non_daq_xy_entries = struct;
            
            %TODO: Add on daq__ to avoid any name conflicts ...
            
            obj.short_names = {ai_chans.short_name};
            disp_names = {ai_chans.name};
            fs = [ai_chans.fs];
            
            n_chans = length(ai_chans);
            
            temp = cell(1,n_chans);
            
            obj.n_chans = n_chans;
            for i = 1:n_chans
                %TODO: Eventually I want to use a local streaming_data class
                dt = 1/fs(i);
                n_samples_init = fs(i)*options.default_trial_duration;
                new_entry = big_plot.streaming_data(dt,n_samples_init,'name',disp_names{i});
                obj.daq_entries.(obj.short_names{i}) = new_entry;
                temp{i} = new_entry;
            end
            obj.daq_entries_array = [temp{:}];
        end
    end
    methods
        function iplot = plotDAQData(obj,varargin)
            %
            %   TODO: This is a work in progress ...
            %
            %   Optional Inputs
            %   ---------------
            %   h_fig
                 
            in.h_fig = [];
            in.position = [];
            in = daq2.sl.in.processVarargin(in,varargin);
            
            if isempty(in.h_fig) || ~isvalid(in.h_fig)
                f = figure;
                %Only position if it didn't exist
                set(f,'Position',in.position);
            else
                f = in.h_fig;
                clf
                figure(in.h_fig);
            end
            
            
            ax = cell(obj.n_chans,1);
            for i = 1:obj.n_chans
                ax{i} = subplot(obj.n_chans,1,i);
                plotBig(obj.daq_entries_array(i));
            end
            
            names = fieldnames(obj.daq_entries);
            %names = regexprep(names,'_','\n');
            iplot = interactive_plot(f,ax,...
                'streaming',true,...
                'axes_names',names,...
                'comments',true);
            
        end
%         function rec_data_entry = initNonDaqEntry(obj,name,fs,n_seconds_init)
%             %
%             %   For now non-DAQ entries will use the old class
%             rec_data_entry = aua17.data.recorded_data_entry(name,fs,n_seconds_init);
%             obj.non_daq_entries.(name) = rec_data_entry;
%         end
        function xy_obj = getXYData(obj,name)
            if isfield(obj.non_daq_xy_entries,name)
               xy_obj = obj.non_daq_xy_entries.(name);
            else
               xy_obj = [];
            end
        end
        function addNonDaqData(obj,name,data)
            
        end
%         function initNonDaqXYData(obj,name,varargin)
%             %We can initialize on adding, we just don't get as much control
%            error('Not yet implemented')
%         end
        function addNonDaqXYData(obj,name,y_data,x_data)
            %non_daq_xy_map
            
            if isfield(obj.non_daq_xy_entries,name)
               xy_obj = obj.non_daq_xy_entries.(name);
            else
               xy_obj = daq2.data.non_daq_streaming_xy(name);
               obj.non_daq_xy_entries.(name) = xy_obj;
            end
            
            xy_obj.addSamples(y_data,x_data);
            
        end
        function addDAQData(obj,new_data)
            %
            %   addData(obj,new_data)
            %
            %   Inputs
            %   ------
            %   new_data : cell array
            %       New data should be decimated already.
            
            for i = 1:obj.n_chans
                obj.daq_entries_array(i).addData(new_data{i});
            end
        end
        function out = getChannel(obj,name)
            out = obj.daq_entries.(name);
        end
    end
end

