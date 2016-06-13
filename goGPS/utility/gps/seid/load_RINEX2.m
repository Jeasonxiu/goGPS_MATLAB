function [pr1_R, pr1_M, ph1_R, ph1_M, pr2_R, pr2_M, ph2_R, ph2_M, ...
          dop1_R, dop1_M, dop2_R, dop2_M, snr1_R, snr1_M, ...
          snr2_R, snr2_M, time, time_R, time_M, week_R, week_M, ...
          date_R, date_M, pos_R, pos_M, Eph, iono, interval, flag_P1] = ...
          load_RINEX2(filename_nav, filename_R_obs, filename_M_obs, constellations, flag_SP3, wait_dlg)

% SYNTAX:
%   [pr1_R, pr1_M, ph1_R, ph1_M, pr2_R, pr2_M, ph2_R, ph2_M, ...
%    dop1_R, dop1_M, dop2_R, dop2_M, snr1_R, snr1_M, ...
%    snr2_R, snr2_M, time, time_R, time_M, week_R, week_M, ...
%    date_R, date_M, pos_R, pos_M, Eph, iono, interval] = ...
%    load_RINEX(filename_nav, filename_R_obs, filename_M_obs, constellations, flag_SP3, wait_dlg);
%
% INPUT:
%   filename_nav = RINEX navigation file
%   filename_R_obs = RINEX observation file (ROVER)
%   filename_M_obs = RINEX observation file (MASTER) (empty if not available)
%   constellations = struct with multi-constellation settings
%                   (see 'multi_constellation_settings.m' - empty if not available)
%   flag_SP3 = boolean flag to indicate SP3 availability
%   wait_dlg = optional handler to waitbar figure (optional)
%
% OUTPUT:
%   pr1_R = code observation (L1 carrier, ROVER)
%   pr1_M = code observation (L1 carrier, MASTER)
%   ph1_R = phase observation (L1 carrier, ROVER)
%   ph1_M = phase observation (L1 carrier, MASTER)
%   pr2_R = code observation (L2 carrier, ROVER)
%   pr2_M = code observation (L2 carrier, MASTER)
%   ph2_R = phase observation (L2 carrier, ROVER)
%   ph2_M = phase observation (L2 carrier, MASTER)
%   dop1_R = Doppler observation (L1 carrier, ROVER)
%   dop1_M = Doppler observation (L1 carrier, MASTER)
%   dop2_R = Doppler observation (L2 carrier, ROVER)
%   dop2_M = Doppler observation (L2 carrier, MASTER)
%   snr1_R = signal-to-noise ratio (L1 carrier, ROVER)
%   snr1_M = signal-to-noise ratio (L1 carrier, MASTER)
%   snr2_R = signal-to-noise ratio (L2 carrier, ROVER)
%   snr2_M = signal-to-noise ratio (L2 carrier, MASTER)
%   time = reference time
%   time_R = rover time
%   time_M = master time
%   date = date (year,month,day,hour,minute,second)
%   pos_R = rover approximate position
%   pos_M = master station position
%   Eph = matrix containing 31 navigation parameters for each satellite
%   iono = vector containing ionosphere parameters
%
% DESCRIPTION:
%   Parses RINEX files (observation and navigation) for both the ROVER
%   and the MASTER. Selects epochs they have in common.

%----------------------------------------------------------------------------------------------
%                           goGPS v0.3.1 beta
%
% Copyright (C) 2009-2012 Mirko Reguzzoni,Eugenio Realini
% Portions of code contributed by Damiano Triglione (2012)
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

flag_P1 = 0;

% Check the input arguments
if (nargin < 6)
    wait_dlg_PresenceFlag = false;
else
    wait_dlg_PresenceFlag = true;
end
if (isempty(filename_M_obs))
    filename_M_obs_PresenceFlag = false;
else
    filename_M_obs_PresenceFlag = true;
end
% if (isempty(constellations)) %then use only GPS as default
    constellations.GPS = struct('numSat', 32, 'enabled', 1, 'indexes', [1:32], 'PRN', [1:32]);
    constellations.GLONASS.enabled = 0;
    constellations.Galileo.enabled = 0;
    constellations.BeiDou.enabled = 0;
    constellations.QZSS.enabled = 0;
    constellations.nEnabledSat = 32;
    constellations.indexes = constellations.GPS.indexes;
    constellations.PRN     = constellations.GPS.PRN;
% end

%number of satellite slots for enabled constellations
nSatTot = constellations.nEnabledSat;

%fraction of INTERVAL (epoch-to-epoch timespan, as specified in the header)
%that is allowed as maximum difference between rover and master timings
%during synchronization
max_desync_frac = 0.1;

%read navigation files
if (~flag_SP3)
    if (wait_dlg_PresenceFlag)
        waitbar(0.5,wait_dlg,'Reading navigation files...')
    end
    
    Eph_G = []; iono_G = zeros(8,1);
    Eph_R = [];
    Eph_E = []; iono_E = zeros(8,1);
    Eph_B = []; iono_B = zeros(8,1);
    Eph_J = []; iono_J = zeros(8,1);
    
    if (constellations.GPS.enabled)
        if (exist(filename_nav,'file'))
            %parse RINEX navigation file (GPS)
            [Eph_G, iono_G] = RINEX_get_nav(filename_nav, constellations);
        else
            fprintf('Warning: GPS navigation file not found. Disabling GPS positioning. \n');
            constellations.GPS.enabled = 0;
        end
    end

    if (constellations.GLONASS.enabled)
        if (exist([filename_nav(1:end-1) 'g'],'file'))
            %parse RINEX navigation file (GLONASS)
            [Eph_R] = RINEX_get_nav_GLO([filename_nav(1:end-1) 'g'], constellations);
        else
            fprintf('Warning: GLONASS navigation file not found. Disabling GLONASS positioning. \n');
            constellations.GLONASS.enabled = 0;
        end
    end
    
    if (constellations.Galileo.enabled)
        if (exist([filename_nav(1:end-1) 'l'],'file'))
            %parse RINEX navigation file (Galileo)
            [Eph_E, iono_E] = RINEX_get_nav([filename_nav(1:end-1) 'l'], constellations);
        else
            fprintf('Warning: Galileo navigation file not found. Disabling Galileo positioning. \n');
            constellations.Galileo.enabled = 0;
        end
    end
    
    if (constellations.BeiDou.enabled)
        %if (exist([filename_nav(1:end-1) 'b'],'file'))
        %    parse RINEX navigation file (BeiDou)
        %     [Eph_B] = RINEX_get_nav_BDS([filename_nav(1:end-1) 'b'], constellations);
        %else
        %    fprintf('Warning: BeiDou navigation file not found. Disabling BeiDou positioning. \n');
            fprintf('Warning: BeiDou not supported yet. Disabling BeiDou positioning. \n');
            constellations.BeiDou.enabled = 0;
        %end
    end
    
    if (constellations.QZSS.enabled)
        if (exist([filename_nav(1:end-1) 'q'],'file'))
            %parse RINEX navigation file (QZSS)
            [Eph_J, iono_J] = RINEX_get_nav([filename_nav(1:end-1) 'q'], constellations);
        else
            fprintf('Warning: QZSS navigation file not found. Disabling QZSS positioning. \n');
            constellations.QZSS.enabled = 0;
        end
    end

    Eph = [Eph_G Eph_R Eph_E Eph_B Eph_J];
    
    if (any(iono_G))
        iono = iono_G;
    elseif (any(iono_E))
        iono = iono_E;
    elseif (any(iono_B))
        iono = iono_B;
    elseif (any(iono_J))
        iono = iono_J;
    else
        iono = zeros(8,1);
        fprintf('Warning: ionosphere parameters not found in navigation file(s).\n');
    end
    
    if (wait_dlg_PresenceFlag)
        waitbar(1,wait_dlg)
    end
else
    Eph = zeros(31,nSatTot);
    iono = zeros(8,1);
end

%-------------------------------------------------------------------------------

%open RINEX observation file (ROVER)
FR_oss = fopen(filename_R_obs,'r');

if (filename_M_obs_PresenceFlag)
    %open RINEX observation file (MASTER)
    FM_oss = fopen(filename_M_obs,'r');
end

%-------------------------------------------------------------------------------

if (wait_dlg_PresenceFlag)
    waitbar(0.5,wait_dlg,'Parsing RINEX headers...')
end

%parse RINEX header
[obs_typ_R,  pos_R, info_base_R, interval_R] = RINEX_parse_hdr(FR_oss);

%check the availability of basic data to parse the RINEX file (ROVER)
if (info_base_R == 0)
    error('Basic data is missing in the ROVER RINEX header')
end

if (filename_M_obs_PresenceFlag)
    [obs_typ_M, pos_M, info_base_M, interval_M] = RINEX_parse_hdr(FM_oss);
    
    %check the availability of basic data to parse the RINEX file (MASTER)
    if (info_base_M == 0)
        error('Basic data is missing in the ROVER RINEX header')
    end
else
    pos_M = zeros(3,1);
    interval_M = [];
end

if (wait_dlg_PresenceFlag)
    waitbar(1,wait_dlg)
end

interval = min([interval_R, interval_M]);

%-------------------------------------------------------------------------------

nEpochs = 86400;

%variable initialization (GPS)
time_R = zeros(nEpochs,1);
time_M = zeros(nEpochs,1);
pr1_R = zeros(nSatTot,nEpochs);
pr2_R = zeros(nSatTot,nEpochs);
ph1_R = zeros(nSatTot,nEpochs);
ph2_R = zeros(nSatTot,nEpochs);
dop1_R = zeros(nSatTot,nEpochs);
dop2_R = zeros(nSatTot,nEpochs);
snr1_R = zeros(nSatTot,nEpochs);
snr2_R = zeros(nSatTot,nEpochs);
pr1_M = zeros(nSatTot,nEpochs);
pr2_M = zeros(nSatTot,nEpochs);
ph1_M = zeros(nSatTot,nEpochs);
ph2_M = zeros(nSatTot,nEpochs);
snr1_M = zeros(nSatTot,nEpochs);
snr2_M = zeros(nSatTot,nEpochs);
dop1_M = zeros(nSatTot,nEpochs);
dop2_M = zeros(nSatTot,nEpochs);
date_R = zeros(nEpochs,6);
date_M = zeros(nEpochs,6);

%read data for the first epoch (ROVER)
[time_R(1), sat_R, sat_types_R, epoch_R] = RINEX_get_epoch(FR_oss);

%read ROVER observations
obs_R = RINEX_get_obs(FR_oss, sat_R, sat_types_R, obs_typ_R, constellations);

%read ROVER observations
if (sum(obs_R.P1 ~= 0) == length(sat_R))
    pr1_R(:,1) = obs_R.P1;
    flag_P1 = 1;
else
    pr1_R(:,1) = obs_R.C1;
end
pr2_R(:,1) = obs_R.P2;
ph1_R(:,1) = obs_R.L1;
ph2_R(:,1) = obs_R.L2;
dop1_R(:,1) = obs_R.D1;
dop2_R(:,1) = obs_R.D2;
snr1_R(:,1) = obs_R.S1;
snr2_R(:,1) = obs_R.S2;

%-------------------------------------------------------------------------------

if (filename_M_obs_PresenceFlag)
    %read data for the first epoch (MASTER)
    [time_M(1), sat_M, sat_types_M, epoch_M] = RINEX_get_epoch(FM_oss);
    
    %read MASTER observations
    obs_M = RINEX_get_obs(FM_oss, sat_M, sat_types_M, obs_typ_M, constellations);
    
    %read MASTER observations
    if (sum(obs_M.P1 ~= 0) == constellations.nEnabledSat)
        pr1_M(:,1) = obs_M.P1;
    else
        pr1_M(:,1) = obs_M.C1;
    end
    pr2_M(:,1) = obs_M.P2;
    ph1_M(:,1) = obs_M.L1;
    ph2_M(:,1) = obs_M.L2;
    dop1_M(:,1) = obs_M.D1;
    dop2_M(:,1) = obs_M.D2;
    snr1_M(:,1) = obs_M.S1;
    snr2_M(:,1) = obs_M.S2;

end
%-------------------------------------------------------------------------------

if (wait_dlg_PresenceFlag)
    waitbar(0.5,wait_dlg,'Parsing RINEX headers...')
end

if (filename_M_obs_PresenceFlag)
    while ((time_M(1) - time_R(1)) < 0 && abs(time_M(1) - time_R(1)) >= max_desync_frac*interval)
        
        %read data for the current epoch (MASTER)
        [time_M(1), sat_M, sat_types_M, epoch_M] = RINEX_get_epoch(FM_oss);
        
        %read MASTER observations
        obs_M = RINEX_get_obs(FM_oss, sat_M, sat_types_M, obs_typ_M, constellations);
        
        %read MASTER observations
        if (sum(obs_M.P1 ~= 0) == constellations.nEnabledSat)
            pr1_M(:,1) = obs_M.P1;
        else
            pr1_M(:,1) = obs_M.C1;
        end
        pr2_M(:,1) = obs_M.P2;
        ph1_M(:,1) = obs_M.L1;
        ph2_M(:,1) = obs_M.L2;
        dop1_M(:,1) = obs_M.D1;
        dop2_M(:,1) = obs_M.D2;
        snr1_M(:,1) = obs_M.S1;
        snr2_M(:,1) = obs_M.S2;
    end
    
    while ((time_R(1) - time_M(1)) < 0 && abs(time_R(1) - time_M(1)) >= max_desync_frac*interval)
        
        %read data for the current epoch (ROVER)
        [time_R(1), sat_R, sat_types_R, epoch_R] = RINEX_get_epoch(FR_oss);
        
        %read ROVER observations
        obs_R = RINEX_get_obs(FR_oss, sat_R, sat_types_R, obs_typ_R, constellations);
        
        %read ROVER observations
        if (flag_P1)
            pr1_R(:,1) = obs_R.P1;
        else
            pr1_R(:,1) = obs_R.C1;
        end
        pr2_R(:,1) = obs_R.P2;
        ph1_R(:,1) = obs_R.L1;
        ph2_R(:,1) = obs_R.L2;
        dop1_R(:,1) = obs_R.D1;
        dop2_R(:,1) = obs_R.D2;
        snr1_R(:,1) = obs_R.S1;
        snr2_R(:,1) = obs_R.S2;
    end
end

if (wait_dlg_PresenceFlag)
    waitbar(1,wait_dlg)
end

%-------------------------------------------------------------------------------


time(1,1) = roundmod(time_R(1),interval);
date_R(1,:) = epoch_R(1,:);
if (filename_M_obs_PresenceFlag)
    date_M(1,:) = epoch_M(1,:);
end

if (wait_dlg_PresenceFlag)
    waitbar(0.5,wait_dlg,'Reading RINEX observations...')
end

k = 2;
while (~feof(FR_oss))

    if (abs((time_R(k-1) - time(k-1))) < max_desync_frac*interval)
        %read data for the current epoch (ROVER)
        [time_R(k), sat_R, sat_types_R, epoch_R] = RINEX_get_epoch(FR_oss);
    else
        time_R(k) = time_R(k-1);
        if (time_R(k-1) ~= 0)
            fprintf('Missing epoch %f (ROVER)\n', time(k-1));
        end
        time_R(k-1) = 0;
    end

    if (filename_M_obs_PresenceFlag)
        if (abs((time_M(k-1) - time(k-1))) < max_desync_frac*interval)
            %read data for the current epoch (MASTER)
            [time_M(k), sat_M, sat_types_M, epoch_M] = RINEX_get_epoch(FM_oss);
        else
            time_M(k) = time_M(k-1);
            if (time_M(k-1) ~= 0)
                fprintf('Missing epoch %f (MASTER)\n', time(k-1));
            end
            time_M(k-1) = 0;
        end
    end

    if (k > nEpochs)
        %variable initialization (GPS)
        pr1_R(:,k) = zeros(nSatTot,1);
        pr2_R(:,k) = zeros(nSatTot,1);
        ph1_R(:,k) = zeros(nSatTot,1);
        ph2_R(:,k) = zeros(nSatTot,1);
        dop1_R(:,k) = zeros(nSatTot,1);
        dop2_R(:,k) = zeros(nSatTot,1);
        snr1_R(:,k) = zeros(nSatTot,1);
        snr2_R(:,k) = zeros(nSatTot,1);
        pr1_M(:,k) = zeros(nSatTot,1);
        pr2_M(:,k) = zeros(nSatTot,1);
        ph1_M(:,k) = zeros(nSatTot,1);
        ph2_M(:,k) = zeros(nSatTot,1);
        snr1_M(:,k) = zeros(nSatTot,1);
        snr2_M(:,k) = zeros(nSatTot,1);
        dop1_M(:,k) = zeros(nSatTot,1);
        dop2_M(:,k) = zeros(nSatTot,1);

        nEpochs = nEpochs  + 1;
    end
    
    date_R(k,:) = epoch_R(1,:);
    if (filename_M_obs_PresenceFlag)
        date_M(k,:) = epoch_M(1,:);
    end

    time(k,1) = time(k-1,1) + interval;
    
    if (abs(time_R(k)-time(k)) < max_desync_frac*interval)

        %read ROVER observations
        obs_R = RINEX_get_obs(FR_oss, sat_R, sat_types_R, obs_typ_R, constellations);

        %read ROVER observations
        if (flag_P1)
            pr1_R(:,k) = obs_R.P1;
        else
            pr1_R(:,k) = obs_R.C1;
        end
        pr2_R(:,k) = obs_R.P2;
        ph1_R(:,k) = obs_R.L1;
        ph2_R(:,k) = obs_R.L2;
        dop1_R(:,k) = obs_R.D1;
        dop2_R(:,k) = obs_R.D2;
        snr1_R(:,k) = obs_R.S1;
        snr2_R(:,k) = obs_R.S2;
    end

    if (filename_M_obs_PresenceFlag)

        if (abs(time_M(k) - time(k)) < max_desync_frac*interval)
            
            %read MASTER observations
            obs_M = RINEX_get_obs(FM_oss, sat_M, sat_types_M, obs_typ_M, constellations);
            
            %read MASTER observations
            if (sum(obs_M.P1 ~= 0) == constellations.nEnabledSat)
                pr1_M(:,k) = obs_M.P1;
            else
                pr1_M(:,k) = obs_M.C1;
            end
            pr2_M(:,k) = obs_M.P2;
            ph1_M(:,k) = obs_M.L1;
            ph2_M(:,k) = obs_M.L2;
            dop1_M(:,k) = obs_M.D1;
            dop2_M(:,k) = obs_M.D2;
            snr1_M(:,k) = obs_M.S1;
            snr2_M(:,k) = obs_M.S2;
        end
    end
    
    k = k+1;
end

%remove empty slots
time_R(k:nEpochs) = [];
time_M(k:nEpochs) = [];
pr1_R(:,k:nEpochs) = [];
pr2_R(:,k:nEpochs) = [];
ph1_R(:,k:nEpochs) = [];
ph2_R(:,k:nEpochs) = [];
dop1_R(:,k:nEpochs) = [];
dop2_R(:,k:nEpochs) = [];
snr1_R(:,k:nEpochs) = [];
snr2_R(:,k:nEpochs) = [];
pr1_M(:,k:nEpochs) = [];
pr2_M(:,k:nEpochs) = [];
ph1_M(:,k:nEpochs) = [];
ph2_M(:,k:nEpochs) = [];
snr1_M(:,k:nEpochs) = [];
snr2_M(:,k:nEpochs) = [];
dop1_M(:,k:nEpochs) = [];
dop2_M(:,k:nEpochs) = [];
date_R(k:nEpochs,:) = [];
date_M(k:nEpochs,:) = [];

%remove rover tail
if (filename_M_obs_PresenceFlag)
    flag_tail = 1;
    while (flag_tail)
        if (time_M(end) == 0)
            date_R(end,:) = [];
            date_M(end,:) = [];
            time(end) = [];
            time_R(end) = [];
            time_M(end) = [];
            pr1_R(:,end) = [];
            pr2_R(:,end) = [];
            ph1_R(:,end) = [];
            ph2_R(:,end) = [];
            dop1_R(:,end) = [];
            dop2_R(:,end) = [];
            snr1_R(:,end) = [];
            snr2_R(:,end) = [];
            pr1_M(:,end) = [];
            pr2_M(:,end) = [];
            ph1_M(:,end) = [];
            ph2_M(:,end) = [];
            snr1_M(:,end) = [];
            snr2_M(:,end) = [];
            dop1_M(:,end) = [];
            dop2_M(:,end) = [];
        else
            flag_tail = 0;
        end
    end
end

if (wait_dlg_PresenceFlag)
    waitbar(1,wait_dlg)
end

%-------------------------------------------------------------------------------

%close RINEX files
fclose(FR_oss);
if (filename_M_obs_PresenceFlag)
    fclose(FM_oss);
end

%GPS week number
week_R = date2gps(date_R);
week_M = date2gps(date_M);