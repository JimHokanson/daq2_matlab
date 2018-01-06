function parallel_session_worker(type,q_send)
%
%   daq2.parallel_session_worker(q_send)

%Output Commands
%----------------
%   'struct' - sending session struct to client
%   'disp' - sending session struct to client for display ...
%   'error'

%Stim Interface
%- 1 input constructor
%- init()
%- data = getData()
%- updateParams(s)
%      s can contain anything
%- 


%0 - Send Queue
%------------------------------------------
q_recv = parallel.pool.PollableDataQueue;
q_send.send(q_recv);
    
%State variables
%---------------
%- session
%- stim
stim = daq2.output.null_stim;
is_running = false;
check_stim = false;
n_analog_inputs = 0;
n_analog_outputs = 0;
try
    
    %1 Initialize session ...
    %------------------------------------------
    session = daq.createSession(type);
    while (true)
        %Commands
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
        %- 'quit' - quit everything
        
        

        %- struct
        %     (no props)
        %- start
        %     (no props)
        %- stim
        %     .fcn
        %     .data
        %- quit
        
        %Checking on output queue if running
        
        if q_recv.QueueLength > 0
            s = q_recv.poll();

            switch s.cmd
                case 'update_stim'
                    stim.updateParams(s.data);
                case 'add_analog_input'
                    session.addAnalogInputChannel(device_ID,'ai0','Voltage');
                case 'add_analog_output'
                case 'update_prop'
                    session.(s.name) = s.value;
                case {'struct' 'disp'}
                    temp = h__getSessionStruct(session);
                    s2 = struct;
                    s2.cmd = s.cmd;
                    s2.data = temp;
                    q_send.send(s2);
                case 'start'
                    is_running = true;
                    session.startBackground();
                    stim.init();
                case 'stop'
                    is_running = false;
                    session.stop();
                case 'construct_stim'
                    stim = s.fcn(s.data);
                    if ~isempty(stim)
                        
                    end
                case 'quit'
                    return
                otherwise
                    error('Unrecognized command')
            end
        else  
            pause(0.02);
        end
    end
    
%{
    d = daq.getDevices;
    device_ID = d.ID;
    session.addAnalogInputChannel(device_ID,'ai0','Voltage');
    session.addAnalogOutputChannel(device_ID,'ao0','Voltage');
    session.IsContinuous = true;
    session.addlistener('DataAvailable',@(src,data)delete([]));
	session.startBackground();
    
%}

    %     
%     
%     
%     
%     
%     h_tic = tic;
%     while (true)
%         pause(0.1)
%         if toc(h_tic) > 5
%             break
%         end
%     end
%     s2 = struct;
%     s2.cmd = 'done';
%     s2.data = s;
%     send(q_send,s2);
catch ME
    s2 = struct;
    s2.cmd = 'error';
    s2.data = ME;
    q_send.send(s2);
end
end 


function s = h__getSessionStruct(session)
    %Serialize the session ...
    s = struct;
    fn = fieldnames(session);
    for i = 1:length(fn)
       cur_name = fn{i};
       s.(cur_name) = session.(cur_name);
       s.summary
    end
end

function gotsData(src,data,q)
    s = struct;
    s.cmd = 'data';
    s.data = data.Data;
    send(q,s);
end

 
 %start background
 %- receive commands
 %      - change stim
 %      - quit
 %- send commands
 %      - new data