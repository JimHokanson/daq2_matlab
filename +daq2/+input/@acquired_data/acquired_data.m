classdef acquired_data < handle
    %
    %   Class:
    %   daq2.input.acquired_data
    
    properties
        raw_session
        perf_mon
        cmd_window
        
        daq_entries %struct
        %objects are field in the struct
        
        daq_entries_array %array of objects
        
        n_chans
        non_daq_entries
        ip
    end
    properties (Hidden)
        %Not sure if cell array access is faster than struct?
        %Could make an object array
        %entries_array
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
            obj.non_daq_entries = struct;
            
            short_names = {ai_chans.short_name};
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
                obj.daq_entries.(short_names{i}) = new_entry;
                temp{i} = new_entry;
            end
            obj.daq_entries_array = [temp{:}];
        end
    end
    methods
        function ip = plotData(obj,varargin)
            %
            %   TODO: This is a work in progress ...
            %
            %
            
            %JAH: Not yet transferred
            
            %Default plot width ??????
            in.width_s = 10;
            in = sl.in.processVarargin(in,varargin);
            
            f = figure;
            set(f,'Position',[1 1 1200 800]);
            ax = cell(obj.n_chans,1);
            for i = 1:obj.n_chans
                ax{i} = subplot(obj.n_chans,1,i);
                plotBig(obj.entries_array(i));
            end
            
            %This relies on structs keeping fields ordered so that the
            %names are in the correct order
            
            names = fieldnames(obj.entries);
            names = regexprep(names,'_','\n');
            obj.ip = interactive_plot(f,ax,'streaming',true,...
                'axes_names',names);
            
            ip = obj.ip;
        end
        function rec_data_entry = initNonDaqEntry(obj,name,fs,n_seconds_init)
            %
            %   For now non-DAQ entries will use the old class
            rec_data_entry = aua17.data.recorded_data_entry(name,fs,n_seconds_init);
            obj.non_daq_entries.(name) = rec_data_entry;
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
            if ~isempty(obj.ip)
                obj.ip.dataAdded(obj.daq_entries_array(1).t_max);
            end
        end
        function out = getChannel(obj,name)
            out = obj.daq_entries.(name);
        end
    end
end

