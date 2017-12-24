classdef daq2
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
    end
    
    methods (Static)
        function s = createSession(type)
            s = daq2.session(type);
        end
        function getCurrentPool(no_create)
            
        end
    end
end

