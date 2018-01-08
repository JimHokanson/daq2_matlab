function initDAQInfo()
%
%   daq2.utils.initDAQInfo
%
%   See Also
%   daq2.session

%The real work behind getting the instance only needs to be
%done once and is really really slow

hw = daq.HardwareInfo.getInstance();

end