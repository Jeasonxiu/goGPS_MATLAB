function icol = find_eph(Eph, sv, time)

% SYNTAX:
%   icol = find_eph(Eph, sv, time);
%
% INPUT:
%   Eph = ephemerides matrix
%   sv = satellites in view
%   time = GPS time
%
% OUTPUT:
%   icol = column index for the selected satellite
%
% DESCRIPTION:
%   Selection of the column corresponding to the specified satellite
%   (with respect to the specified GPS time) in the ephemerides matrix.

%----------------------------------------------------------------------------------------------
%                           goGPS v0.2.0 beta
%
% Copyright (C) Kai Borre
% Kai Borre and C.C. Goad 11-26-96
%
% Adapted by Mirko Reguzzoni, Eugenio Realini, 2009
%----------------------------------------------------------------------------------------------

isat = find(Eph(1,:) == sv);
n = size(isat,2);
if n == 0
    icol = [];
    return
end
icol = isat(1);
time = check_t(time);
dtmin = Eph(21,icol)-time;
for t = isat
   dt = Eph(21,t)-time;
   if dt < 0
      if abs(dt) < abs(dtmin)
         icol = t;
         dtmin = dt;
      end
   end
end