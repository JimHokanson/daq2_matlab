function parallel_session_worker(type,q_send)
%
%   daq2.parallel_session_worker(type,q_send)
%
%   See Also
%   --------
%   daq2.parallel_raw_session

%Received Commands
%---------------------------
%- 'add_analog_input'
%       .id
%       .port
%       .type
%       .other - (optional) prop-value pair cell array
%- 'add_analog_output'
%       .id
%       .port
%       .type
%- 'update_prop' update prop
%       .name - prop name
%       .value - prop value
%- 'start' - start session
%- 'stop'  - stop session
%- 'construct_stim' - construct stim
%       .fcn - function handle
%       .data - data to pass to function
%- 'update_stim' - update stim params
%       .data - anything ...
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
    %---------------
    stim = daq2.output.null_stim;
    is_running = false;
    n_analog_inputs = 0;
    n_analog_outputs = 0;
    n_loops = 0;
    n_pauses = 0;
    
    %1 Initialize session ...
    %------------------------------------------
    session = daq.createSession(type);
    session.addlistener('DataAvailable',...
        @(src,event)h__dataAvailable(src,event,q_send));
    session.addlistener('ErrorOccurred',...
        @(src,event)h__errorTriggered(src,event,q_send));
    while (true)
        n_loops = n_loops + 1;
        if is_running && n_analog_outputs && (session.ScansQueued < session.NotifyWhenScansQueuedBelow)
            data = stim.getData();
            if ~isempty(data)
                session.queueOutputData(data);
            end
        elseif q_recv.QueueLength > 0
            s = q_recv.poll();
            
            switch s.cmd
                %Keep this first since it should be the most often
                
                %----------------------------------------------------------
                case 'update_stim'
                    %.data - this can be anything ...
                    data = stim.updateParams(is_running,s.data);
                    if ~isempty(data)
                        session.queueOutputData(data);
                    end
                    
                    %----------------------------------------------------------
                case 'add_analog_input'
                    %.id - device id
                    %.port - daq_port
                    %.type - measurement type
                    %.other - prop/value pairs
                    
                    [ch,idx] = session.addAnalogInputChannel(s.id,s.port,s.type);
                    
                    for i = 1:2:length(s.other)
                        prop = s.other{i};
                        value = s.other{i+1};
                        ch.(prop) = value;
                    end
                    n_analog_inputs = n_analog_inputs + 1;
                    
                    %----------------------------------------------------------
                case 'add_analog_output'
                    %.id - device id
                    %.port - daq port
                    %.type - measurement type
                    
                    [ch,idx] = session.addAnalogOutputChannel(s.id,s.port,s.type);
                    n_analog_outputs = n_analog_outputs + 1;
                    
                    %----------------------------------------------------------
                case 'construct_stim'
                    %.stim_fcn - function handle for stimulator
                    %.data - input structure to stimulator
                    fs = session.Rate;
                    min_queue_samples = session.NotifyWhenScansQueuedBelow;
                    fh = s.stim_fcn;
                    stim = fh(fs,min_queue_samples,s.data);
                    
                    %----------------------------------------------------------
                case 'perf'
                    %Create perf struct
                    p = struct;
                    p.n_pauses = n_pauses;
                    p.n_loops = n_loops;
                    
                    s2 = struct;
                    s2.cmd = 'perf';
                    s2.data = p;
                    h__send(q_send,s2)
                    
                    %----------------------------------------------------------
                case 'q_data'
                    %.data - TODO: rename
                    n_seconds_add = s.data;
                    data = stim.getData(n_seconds_add);
                    if ~isempty(data)
                        session.queueOutputData(data);
                    end
                    
                    %----------------------------------------------------------
                case 'quit'
                    return
                    
                    %----------------------------------------------------------
                case {'struct' 'disp'}
                    temp = h__getSessionStruct(session);
                    s2 = struct;
                    s2.cmd = s.cmd;
                    s2.data = temp;
                    h__send(q_send,s2)
                    
                    %----------------------------------------------------------
                case 'start'
                    data = stim.init();
                    if ~isempty(data)
                        session.queueOutputData(data);
                    end
                    session.startBackground();
                    is_running = true;
                    
                    %----------------------------------------------------------
                case 'stop'
                    is_running = false;
                    session.stop();
                    %case 'update_stim'
                    %   Now first since most frequent
                    
                    %----------------------------------------------------------
                case 'update_prop'
                    %.name - prop name
                    %.value -  prop value
                    session.(s.name) = s.value;
                    
                    
                otherwise
                    error('Unrecognized command')
            end
        else
            n_pauses = n_pauses + 1;
            pause(0.1);
        end
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

function h__dataAvailable(~,data,q_send)
%We need a try/catch because otherwise errors
%are silent in the listener
try
    s = struct;
    s.cmd = 'data_available';
    s.src = [];
    
    %TODO: Implement decimation here to avoid
    %transmission overhead ...
    
    %Can't write to Source in data
    %so we copy it ...
    s2 = struct;
    s2.Data = data.Data;
    s2.TimeStamps = data.TimeStamps;
    s2.Source = [];
    s2.EventName = data.EventName;
    s2.TriggerTime = data.TriggerTime;
    
    s.data = s2;
    h__send(q_send,s)
catch ME
    h__sendError(q_send,ME)
end
end
function h__errorTriggered(src,data,q_send)
try
    s = struct;
    s.cmd = 'daq_error';
    s.ME = data.Error;
    h__send(q,s)
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