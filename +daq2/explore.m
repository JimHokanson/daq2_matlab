function f = explore(file_path)
%
%   daq2.explore(*file_path)
%
%   Optional Inputs
%   ----------------
%   file_path : string
%       If empty, a prompt comes up.
%
%   Examples
%   --------
%   daq2.explore

%{
daq2.explore
%}

%If no file, prompt

%daq2.saved_data_explorer

%Goal is to allow plotting previously collected data

%We might change to:

%d = daq2.loadData()
%plot(d)

persistent base_path

if isempty(base_path)
    base_path = '';
end

if nargin == 0
    [filename, pathname] = uigetfile('*.mat',...
        'Pick a MATLAB mat file',...
        base_path);
    if filename == 0
        return
    end
    file_path = fullfile(pathname,filename);
    base_path = pathname;
end

f = daq2.saved_data_explorer(file_path);

keyboard

end