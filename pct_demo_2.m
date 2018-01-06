function f = pct_demo_2()
    p = gcp('nocreate');
    if isempty(p)
        p = parpool(2, 'IdleTimeout', inf);
    end
    q = parallel.pool.DataQueue;
    afterEach(q, @receivedSomething);
 
 
    f = parfeval(p, @parallel_daq_session, 0,q); 
end

function receivedSomething(s)

plot(s.data);

end

function parallel_daq_session(q_send)
%0 - Send Queue
%------------------------------------------
q_recv = parallel.pool.PollableDataQueue;
q_send.send(q_recv);
    
try
    
    
    %1 Initialize session ...
    %------------------------------------------
    session = daq.createSession('ni');
    while (true)
        %Commands
        %---------------------------
        %- update prop
        %- 
        if q_recv.QueueLength > 0
            s = q_recv.poll();

            if ~isstruct(s)
                break
            end

            switch s.cmd
                case 'add_samples'
                    h_matfile.(s.name)(s.start_I:s.end_I,1) = s.data;
                case 'clear'
                    h_matfile.(s.name) = [];
                case 'save'
                    h_matfile.(s.name) = s.data;
                otherwise
                    q_send.send('Unrecognized command')
            end

        else  
            pause(0.1);
        end
    end
    
    d = daq.getDevices;
    device_ID = d.ID;
    addAnalogInputChannel(s,device_ID,'ai0','Voltage');
    s.IsContinuous = true;
    s.addlistener('DataAvailable',@(src,data)gotsData(src,data,q_send));
    s.startBackground();
    h_tic = tic;
    while (true)
        pause(0.1)
        if toc(h_tic) > 5
            break
        end
    end
    s2 = struct;
    s2.cmd = 'done';
    s2.data = s;
    send(q_send,s2);
catch ME
    s2 = struct;
    s2.cmd = 'error';
    s2.data = ME;
    send(q_send,s2);
   %Need to send something back to main process 
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