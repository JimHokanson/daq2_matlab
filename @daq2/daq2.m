classdef daq2
    %
    %   Class:
    %   daq2
    
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

