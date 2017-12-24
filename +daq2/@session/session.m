classdef session
    %
    %   daq2.session
    
    properties
        h
        n_analog_inputs
        n_analog_outputs
        n_digital_inputs
        n_digital_outputs
    end
    
    properties (Dependent)
%                          AutoSyncDSA: false
%                        NumberOfScans: 1000
%                    DurationInSeconds: 1
%                                 Rate: 1000
%                         IsContinuous: false
%       NotifyWhenDataAvailableExceeds: 100
% IsNotifyWhenDataAvailableExceedsAuto: true
%           NotifyWhenScansQueuedBelow: 500
%     IsNotifyWhenScansQueuedBelowAuto: true
%               ExternalTriggerTimeout: 10
%                       TriggersPerRun: 1
%                             UserData: ''
%                               Vendor: National Instruments
%                             Channels: ''
%                          Connections: ''
%                            IsRunning: false
%                            IsLogging: false
%                               IsDone: false
%          IsWaitingForExternalTrigger: false
%                    TriggersRemaining: 1
%                            RateLimit: ''
%                          ScansQueued: 0
%                ScansOutputByHardware: 0
%                        ScansAcquired: 0
    end
    
    methods
        function obj = session(type)
            
        end
    end
end

