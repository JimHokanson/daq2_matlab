classdef command_window < handle
    %
    %   Class:
    %   daq2.command_window
    %
    %   This class should handle all calls to log info or errors
    %   to the user. Functionally it should handle display of these
    %   messages in a text box.
    %
    %   Improvements
    %   -------------
    %   1) error notification event
    %   2) Support for old and new text boxes
    %   3) Optional throwing of an error
    
    events
        %TODO: Not yet implemented ...
        error_thrown
    end
    
    properties
        h_text
        strings = {}
    end
    
    methods
        function obj = command_window(h_text)
            %
            %   Do we want to log these to disk???
            %
            %   obj = daq2.command_window(*h_text)
            %
            %   Examples
            %   --------
            %   TODO: show h_text example
            %
            %   %Use the Matlab command window, not a GUI
            %   obj = daq2.command_window()
            
            if nargin
                obj.h_text = h_text;
            end
        end
        function logMessage(obj,msg,varargin)
            if ~isempty(varargin)
                msg = sprintf(msg,varargin{:});
            end
            time_string = datestr(now,'HH:MM:SS');
            msg2 = [time_string '  ' msg];
            STD_TYPE = 1;
            h__addMsg(obj,msg2,STD_TYPE)
        end
        function logWarningMessage(obj,msg,varargin)
            if ~isempty(varargin)
                msg = sprintf(msg,varargin{:});
            end
            time_string = datestr(now,'HH:MM:SS');
            msg2 = [time_string '  ' 'WARNING: ' msg];
            WARNING_TYPE = 3;
            h__addMsg(obj,msg2,WARNING_TYPE)
        end
        function logErrorMessage(obj,msg,varargin)
            if ~isempty(varargin)
                msg = sprintf(msg,varargin{:});
            end
            time_string = datestr(now,'HH:MM:SS');
            msg2 = [time_string '  ' 'ERROR: ' msg];
            ERROR_TYPE = 2;
            h__addMsg(obj,msg2,ERROR_TYPE)
        end
        function clear(obj)
            obj.strings = {};
            obj.h_text.Value = {};
        end
    end
end

function h__addMsg(obj,msg2,type)
%
%   type:
%   1 - normal
%   2 - error
%   3 - warning

    %Auto-grow for now ...
    obj.strings{end+1} = msg2;
    
    %If we have a text box, then display to the text box
    %
    %TODO: This might only be for new (or old) text boxes ...
    if ~isempty(obj.h_text)
        obj.h_text.Items = obj.strings;
        if length(obj.strings) > 5
            %I = length(obj.strings)-4;
            %Not sure why we can't set an index ....
            %obj.h_text.Value = obj.strings{end};
            scroll(obj.h_text,obj.strings{end});
        end
    else %Display in the command window ...
        %TODO: Fix this
        if type == 3
            type = 2;
        end
        fprintf(type,[msg2 '\n']);
        %Use Matlab Command Window
    end
end

