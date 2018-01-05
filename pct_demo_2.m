function f = pct_demo_2()
    p = gcp('nocreate');
    if isempty(p)
        p = parpool(2, 'IdleTimeout', inf);
    end
    q = parallel.pool.DataQueue;
    afterEach(q, @receivedSomething);
 
 
    f = parfeval(p, @daqInputSession, 0,q); 
end

function receivedSomething(s)

plot(s.data);

end

function daqInputSession(q)
try
    s = daq.createSession('ni');
    d = daq.getDevices;
    device_ID = d.ID;
    addAnalogInputChannel(s,device_ID,'ai0','Voltage');
    s.IsContinuous = true;
    s.addlistener('DataAvailable',@(src,data)gotsData(src,data,q));
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
    send(q,s2);
catch ME
    s2 = struct;
    s2.cmd = 'error';
    s2.data = ME;
    send(q,s2);
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