function [pr1, ph1, pr2, ph2, dtR, dtRdot] = pre_processing_clock(time_GPS, time_rx, XR0, pr1, ph1, pr2, ph2, snr1, Eph, SP3_time, SP3_coor, SP3_clck, iono)

% SYNTAX:
%   [pr1, ph1, pr2, ph2, dtR, dtRdot] = pre_processing_clock(time_GPS, time_rx, XR0, pr1, ph1, pr2, ph2, snr1, Eph, SP3_time, SP3_coor, SP3_clck, iono);
%
% INPUT:
%   time_GPS = GPS reference time
%   time_rx = GPS reception time (as read from RINEX file)
%   XR0 = receiver position (=[] if not available)
%   pr1 = code observation (L1 carrier)
%   ph1 = phase observation (L1 carrier)
%   pr2 = code observation (L2 carrier)
%   ph2 = phase observation (L2 carrier)
%   snr1 = signal-to-noise ratio
%   Eph = matrix containing 31 ephemerides for each satellite
%   SP3_time = precise ephemeris time
%   SP3_coor = precise ephemeris coordinates
%   SP3_clck = precise ephemeris clocks
%   iono = ionosphere parameters (Klobuchar)

% OUTPUT:
%   pr1 = processed code observation (L1 carrier)
%   ph1 = processed phase observation (L1 carrier)
%   pr2 = processed code observation (L2 carrier)
%   ph2 = processed phase observation (L2 carrier)
%   dtR = receiver clock error
%   dtRdot receiver clock drift
%
% DESCRIPTION:
%   Pre-processing of code and phase observations to correct them for
%    the receiver clock error.

%----------------------------------------------------------------------------------------------
%                           goGPS v0.1.3 alpha
%
% Copyright (C) 2009-2011 Mirko Reguzzoni, Eugenio Realini
%----------------------------------------------------------------------------------------------
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%----------------------------------------------------------------------------------------------

global v_light lambda1 lambda2
global cutoff snr_threshold

%number of epochs
nEpochs = length(time_rx);

%receiver clock error
dtR = zeros(nEpochs,1);

%receiver clock drift
dtRdot = zeros(nEpochs-1,1);

%------------------------------------------------------------------------------------
% APPROXIMATE POSITION
%-----------------------------------------------------------------------------------

if ((sum(abs(XR0)) == 0) || isempty(XR0))
    %approximate position not available
    flag_XR = 0;
else
    %approximate position available
    flag_XR = 1;
end

for i = 1 : nEpochs
    
    %--------------------------------------------------------------------------------------------
    % SATELLITE AND EPHEMERIS SELECTION
    %--------------------------------------------------------------------------------------------
    
    sat0 = find(pr1(:,i) ~= 0);

    Eph_t = rt_find_eph (Eph, time_rx(i));
    
    %----------------------------------------------------------------------------------------------
    % RECEIVER POSITION AND CLOCK ERROR
    %----------------------------------------------------------------------------------------------
    
    if (length(sat0) >= 4)
        
        [~, dtR(i), ~, ~, ~, ~, ~, ~, ~, sat] = init_positioning(time_rx(i), pr1(sat0,i), snr1(sat0,i), Eph_t, SP3_time, SP3_coor, SP3_clck, iono, [], XR0, [], [], sat0, cutoff, snr_threshold, flag_XR, 0);
        
        if (size(sat,1) >= 4)
            
            if (i > 1)
                %compute receiver clock drift
                if (dtR(i) ~= 0 && dtR(i-1) ~= 0)
                    dtRdot(i-1) = (dtR(i) - dtR(i-1))/(time_rx(i) - time_rx(i-1));
                end
            end
        else
            if (i > 2)
                dtR(i) = dtR(i-1) + (dtR(i-1) - dtR(i-2));
                dtRdot(i-1) = (dtR(i) - dtR(i-1));
            end
        end
    end
end

%check if it is needed to correct observations for receiver clocks offsets
% (some RINEX files contain clock-corrected observations, although they are
%  not respecting the specifications); clock offsets lower than 1
%  microsecond don't need to be corrected
if (max(abs(dtR)) < 1e-6)
    return
end

%----------------------------------------------------------------------------------------------
% RECEIVER CLOCK DRIFT DISCONTINUITIES
%----------------------------------------------------------------------------------------------

%check if there is any discontinuity in the clock drift
clock_thresh = 1e-4;
disc = find(abs(dtRdot-mean(dtRdot)) > clock_thresh);

%remove discontinuities from the clock drift
for i = 1 : length(disc)
    if (disc(i) < 5)
        dtRdot(disc(i)) = median([dtRdot(1) dtRdot(10)]);
    elseif (disc(i) <= nEpochs-6)
        dtRdot(disc(i)) = median([dtRdot(disc(i)-4) dtRdot(disc(i)+5)]);
    elseif (disc(i) > nEpochs-6)
        dtRdot(disc(i)) = median([dtRdot(nEpochs-10) dtRdot(nEpochs-1)]);
    end
end

dtRdot(end+1) = dtRdot(end);

%----------------------------------------------------------------------------------------------
% OBSERVATION CORRECTION FOR CLOCK ERROR
%----------------------------------------------------------------------------------------------

%two types of corrections (as in http://www.navcen.uscg.gov/?pageName=RINEX):
% 1. "frequency correction" c*dtR
% 2. "receiver-satellite dynamics correction" by interpolating observations
%    on the time tag corrected by dtR)

%available epochs
index_e = find(time_rx ~= 0);

%if the nominal time (e.g. read from RINEX) and the reference time are identical
if (~any(time_GPS(index_e) - time_rx(index_e)))
    time_rx(index_e) = time_rx(index_e) + dtR(index_e);
end

for s = 1 : 32

    if (any(pr1(s,:)))

        index_s = find(pr1(s,:) ~= 0);
        index = intersect(index_e,index_s);
        
        pr1(s,index) = pr1(s,index) - v_light*dtR(index)';
        pr1(s,index) = interp1(time_rx(index), pr1(s,index), time_GPS(index), 'spline');
    end
    
    if (any(pr2(s,:)))
        
        index_s = find(pr2(s,:) ~= 0);
        index = intersect(index_e,index_s);
        
        pr2(s,index) = pr2(s,index) - v_light*dtR(index)';
        pr2(s,index) = interp1(time_rx(index), pr2(s,index), time_GPS(index), 'spline');
    end
    
    if (any(ph1(s,:)))
        
        index_s = find(ph1(s,:) ~= 0);
        index = intersect(index_e,index_s);
        
        ph1(s,index) = ph1(s,index) - v_light*dtR(index)'/lambda1;
        ph1(s,index) = interp1(time_rx(index), ph1(s,index), time_GPS(index), 'spline');
    end
    
    if (any(ph2(s,:)))
        
        index_s = find(ph2(s,:) ~= 0);
        index = intersect(index_e,index_s);
        
        ph2(s,index) = ph2(s,index) - v_light*dtR(index)'/lambda2;
        ph2(s,index) = interp1(time_rx(index), ph2(s,index), time_GPS(index), 'spline');
    end
end