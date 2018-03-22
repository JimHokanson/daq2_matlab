function parallel_session_worker(type,q_send)
%
%   daq2.parallel_session_worker(type,q_send)
%
%   See Also
%   --------
%   daq2.session
%   daq2.parallel_raw_session
%   daq2.utils.initDAQInfo
%   daq2.output.null_stim
%   daq2.basic_stimulator
%   
%   Improvements
%   ------------
%   1) Place updating of output buffer into a callback rather than
%      polling (i.e. specify output listener, DataRequired??)
%   2) Place command handling into a callback rather than polling
%   
%   If we implement #s 1 and 2, then we just need to have a loop with a
%   pause statement - assuming both #s 1 and 2 are able to execute during
%   the pause ...
%

%Options ...
%----------------------


%- 'struct' get session props (return struct)
%- 'q_data'
%       .data - n seconds to add
%- 'quit' - quit everything


%0 - Send Queue
%------------------------------------------
q_recv = parallel.pool.PollableDataQueue;
q_send.send(q_recv);

try
    
    %State variables
    %-------------------------------
    stim = daq2.output.null_stim;
    is_running = false;
    n_analog_inputs = 0;
    n_analog_outputs = 0;
    n_loops = 0;
    n_pauses = 0;
    
    data_available_L = [];
    dec_rates = [];
    
    %When we overflow on this amount, we reset
    %back to 1 rather than reallocating the loop variable
    N_LOOP = 1e5;
    
    %loop_I wraps every N_LOOP
    loop_I = 0;
    %Elapsed time for loop execution
    loop_etimes = zeros(1,N_LOOP);
    %Command that was executed at every loop
    loop_types = zeros(1,N_LOOP);
    loop_is_full = false;
    output_min_time = 0; %#ok<NASGU>
    pause_time = 0; %#ok<NASGU>
    
    %1 Initialize session with listeners
    %----------------------------------------------------------------------
    %DAQ props and channels are modified below with commands from client
    
    log = daq2.parallel.parallel_session_log;
    
    session = daq.createSession(type);

    session.addlistener('ErrorOccurred',...
        @(src,event)h__errorTriggered(event,q_send));
    
    output_min_time = double(session.NotifyWhenScansQueuedBelow)/session.Rate;
    pause_time = 1/3*output_min_time;
    
    while (true)
        n_loops = n_loops + 1;
        
        h_tic = tic;
        
        if is_running && n_analog_outputs && (session.ScansQueued < session.NotifyWhenScansQueuedBelow)
            %Adding data to output queue
            %---------------------------
            data = stim.getData();
            if ~isempty(data)
                session.queueOutputData(data);
            end
            loop_type = 1;
            
        elseif q_recv.QueueLength > 0
            %Processing commands from main process
            %-------------------------------------
            s = q_recv.poll();
            
            %Generic ...
            loop_type = 2; %#ok<NASGU>
            
            switch s.cmd
                %Keep this first since it should be the most often
                %----------------------------------------------------------
                case 'update_stim'
                    loop_type = 2.01;
                    %   Pass new parameters to the stimulator.
                    %
                    %.data - this can be anything, especially since
                    %any stimulator may be defined
                    %
                    %   See Also
                    %   daq2.basic_stimulator
                     
                    data = stim.updateParams(is_running,s.data);
                    if ~isempty(data)
                        session.queueOutputData(data);
                    end
                    
                    %----------------------------------------------------------
                case 'add_analog_input'
                    loop_type = 2.02;
                    %   Add an analog input channel to the session
                    %
                    %   .id - device id
                    %   .port - daq_port
                    %   .type - measurement type
                    %   .other - cell or prop/value pairs
                    %   .dec_rate - decimation rate for this channel
                    
                    [ch,idx] = session.addAnalogInputChannel(s.id,s.port,s.type);
                    
                    %Application of other properties
                    %------------------------------
                    for i = 1:2:length(s.other)
                        prop = s.other{i};
                        value = s.other{i+1};
                        ch.(prop) = value;
                    end
                    
                    dec_rates = [dec_rates s.dec_rate]; %#ok<AGROW>
                    
                    n_analog_inputs = n_analog_inputs + 1;
                    
                    %----------------------------------------------------------
                case 'add_analog_output'
                    loop_type = 2.03;
                    %   Add an analog output channel to the session
                    %
                    %   .id - device id
                    %   .port - daq port
                    %   .type - measurement type
                    
                    [ch,idx] = session.addAnalogOutputChannel(s.id,s.port,s.type);
                    n_analog_outputs = n_analog_outputs + 1;
                    
                    %----------------------------------------------------------
                case 'construct_stim'
                    loop_type = 2.04;
                    %   Construct the stimulator locally
                    %
                    %   .stim_fcn - function handle for stimulator
                    %   .data - input structure to stimulator
                    %
                    %   The thought is that the stimulator might work
                    %   more cleanly if constructed in this process, rather
                    %   than passed through IPC. This may not be true and
                    %   we could add an option for passing a stimulator
                    %   directly to this process.
                    
                    fs = session.Rate;
                    min_queue_samples = session.NotifyWhenScansQueuedBelow;
                    fh = s.stim_fcn;
                    stim = fh(fs,min_queue_samples,s.data);
                    
                    %----------------------------------------------------------
                case 'perf'
                    loop_type = 2.05;
                    %   Create and return perf struct to main processs
                    %
                    %   Format may change ...
                    p = struct;
                    p.n_pauses = n_pauses;
                    p.n_loops = n_loops;
                    p.loop_etimes = loop_etimes;
                    p.loop_types = loop_types;
                    p.loop_I = loop_I;
                    p.loop_is_full = loop_is_full;
                    p.read_data_process_times = log.etimes_process;
                    p.read_data_send_times = log.etimes_send;
                    p.read_data_process_I = log.I1;
                    p.read_data_send_I = log.I2;
                    
                    s2 = struct;
                    s2.cmd = 'perf';
                    s2.data = p;
                    h__send(q_send,s2)
                    
                    %----------------------------------------------------------
                case 'q_data'
                    loop_type = 2.06;
                    %   This is a direct call to the stimulator to queue
                    %   more data
                    %   
                    %   .n_seconds_add
                    
                    n_seconds_add = s.n_seconds_add;
                    data = stim.getData(n_seconds_add);
                    if ~isempty(data)
                        session.queueOutputData(data);
                    end
                    
                    %----------------------------------------------------------
                case 'quit'
                    loop_type = 2.07; %#ok<NASGU>
                    return
                    
                    %----------------------------------------------------------
                case {'struct' 'disp'}
                    loop_type = 2.08;
                    
                    %Get session struct
                    temp = h__getSessionStruct(session);
                    
                    %Send reply back to client
                    s2 = struct;
                    s2.cmd = s.cmd;
                    s2.data = temp;
                    h__send(q_send,s2)
                    
                    %----------------------------------------------------------
                case 'start'
                    loop_type = 4;
                    %- no fields besides the command ('cmd')
                    
                    %Initialize stimulator
                    %---------------------------------------
                    %TODO: How does the stimulator know if it needs to 
                    %output samples or not?
                    data = stim.init();
                    if ~isempty(data)
                        session.queueOutputData(data);
                    end
                    

                    dec_handler = daq2.input.decimation_handler(dec_rates);
                    
                    %obj = daq2.input.decimation_handler(decimation_rates)
                    data_available_L = session.addlistener('DataAvailable',...
                        @(src,event)h__dataAvailable(event,q_send,log,dec_handler));
                    
                    session.startBackground();
                    is_running = true;
                    
                    %----------------------------------------------------------
                case 'stop'
                    loop_type = 5;
                    %- no fields besides cmd
                    is_running = false;
                    session.stop();
                    
                    if ~isempty(data_available_L)
                       delete(data_available_L);
                       data_available_L = [];
                    end
                    
                    %----------------------------------------------------------
                case 'update_daq_prop'
                    loop_type = 2.09;
                    %   Update a property of the DAQ session
                    %
                    %   .name - prop name
                    %   .value -  prop value
                    
                    session.(s.name) = s.value;
                    output_min_time = double(session.NotifyWhenScansQueuedBelow)/session.Rate;
                    pause_time = 1/3*output_min_time;
                otherwise
                    error('Unrecognized command')
            end
            
            
        else
            n_pauses = n_pauses + 1;
            pause(pause_time-toc(h_tic));
            loop_type = 3;
        end
        
        %Log loop values
        %---------------------------------------------
        loop_I = loop_I + 1;
        
        %Using a fixed-size buffer, if over start over at 1
        if loop_I > N_LOOP
            loop_I = 1;
            loop_is_full = true;
        end
        etime = toc(h_tic);
        loop_etimes(loop_I) = etime;
        loop_types(loop_I) = loop_type;
    end
catch ME
    h__sendError(q_send,ME)
end
end

function h__sendError(q_send,ME)
%Caught error from code, not from the DAQ
s = struct;
s.cmd = 'parallel_error';
s.ME = ME;
h__send(q_send,s)
end

function s = h__getSessionStruct(session)
%Serialize the session ...
s = struct;
fn = fieldnames(session);
for i = 1:length(fn)
    cur_name = fn{i};
    s.(cur_name) = session.(cur_name);
    %s.summary
end
%This may be ok ..
s.Vendor = [];
%I think these point to HW specific resources ...
s.Channels = [];
s.Connections = [];
end

function h__dataAvailable(cb_struct,q_send,log,dec_handler)
%
%   Inputs
%   ------
%   log : daq2.parallel.parallel_session_log
%   dec_handler : daq2.input.decimation_handler

%We need a try/catch because otherwise errors
%are silent in the listener

%Format of callback
%--------------------------------------
%   cb_struct:
%     TriggerTime: 7.3705e+05
%            Data: [1000×10 double]
%      TimeStamps: [1000×1 double]
%          Source: [1×1 daq.ni.Session]
%       EventName: 'DataAvailable'



try
    %Process -----------------------
    h_tic = tic;
    s = struct;
    s.cmd = 'data_available';
    s.src = [];
    
    %Can't write to Source in data
    %so we copy it ...
%     s2 = struct;
%     s2.Data = cb_struct.Data;
%     s2.TimeStamps = cb_struct.TimeStamps;
%     s2.Source = [];
%     s2.EventName = cb_struct.EventName;
%     s2.TriggerTime = cb_struct.TriggerTime;

    %Only transfering minimum now
    
    s2.decimated_data = dec_handler.getDecimatedData(cb_struct.Data);
    %anything else????

    s.data = s2;
    
    log.addProcessTime(toc(h_tic));
    
    %Send -----------------------
    h_tic = tic;
    h__send(q_send,s)
    log.addSendTime(toc(h_tic));
    
catch ME
    h__sendError(q_send,ME)
end
end
function h__errorTriggered(data,q_send)
try
    s = struct;
    s.cmd = 'daq_error';
    s.ME = data.Error;
    h__send(q_send,s)
catch ME
    h__sendError(q_send,ME)
end
end

function h__send(q,s)
s.send_time = tic;
q.send(s);
end

% function gotsData(src,data,q)
%     s = struct;
%     s.cmd = 'data';
%     s.data = data.Data;
%     send(q,s);
% end


%start background
%- receive commands
%      - change stim
%      - quit
%- send commands
%      - new data