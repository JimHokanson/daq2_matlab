p = gcp('nocreate');
if isempty(p)
    p = parpool(2, 'IdleTimeout', inf);
end
q = parallel.pool.DataQueue;
afterEach(q, @(data) plot(data));
 
 
f = parfeval(p, @daqInputSession, 0,q);
 
function daqInputSession(q)
    s = daq.createSession('ni');
    addAnalogInputChannel(s,'cDAQ1Mod1',0,'Voltage');
    data = s.startForeground();
    send(q,data);
end 