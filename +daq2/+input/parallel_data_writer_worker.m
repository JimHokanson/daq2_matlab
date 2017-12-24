function parallel_data_writer_worker(q_send,h_matfile)
%
%   daq2.input.parallel_data_writer_worker(q_send,h_matfile)
%
%   Commands
%   --------
%   add_samples

%Message Structure
%-----------------
%.cmd : command to execute

%.cmd = 'add_samples'
%.name : channel name
%.data : data to add
%.start_I : start index
%.end_I : end index

%matlab.io.MatFile

q_recv = parallel.pool.PollableDataQueue;
q_send.send(q_recv);

while (true)
    if q_recv.QueueLength > 0
        s = q_recv.poll();
        
        if ~isstruct(s)
            break
        end
        
        switch s.cmd
            case 'add_samples'
                h_matfile.(s.name)(s.start_I:s.end_I,1) = s.data;
            otherwise
                q_send.send('Unrecognized command')
        end
        
    else  
        pause(0.1);
    end
end


%Cleanup
%----------------------------------------

%Nothing currently ????

end