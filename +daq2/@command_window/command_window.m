classdef command_window < handle
    %
    %   Class:
    %   daq2.command_window
    %
    %   This class should handle all calls to log info or errors
    %   to the user. Functionally it should handle display of these
    %   messages in a text box.
    
    properties
        text_h
        strings = {}
    end
    
    methods
        function obj = command_window(text_h)
            %
            %   Do we want to log these to disk???
            %
            %   obj = daq2.command_window(*text_h)
            %
            %   Examples
            %   --------
            %   TODO: show text_h example
            %
            %   %Use the Matlab command window, not a GUI
            %   obj = daq2.command_window()
            
            if nargin
                obj.text_h = text_h;
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
            obj.text_h.Value = {};
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
    if ~isempty(obj.text_h)
        obj.text_h.Items = obj.strings;
        if length(obj.strings) > 5
            %I = length(obj.strings)-4;
            %Not sure why we can't set an index ....
            %obj.text_h.Value = obj.strings{end};
            scroll(obj.text_h,obj.strings{end});
        end
    else
        %TODO: Fix this
        if type == 3
            type = 2;
        end
        fprintf(type,[msg2 '\n']);
        %Use Matlab Command Window
    end
end

