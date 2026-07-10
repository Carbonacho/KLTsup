function setup_paths()
%SETUP_PATHS  Add all CODICE subfolders to the MATLAB path.
%
%   Run this once per MATLAB session before using the pipeline:
%       >> setup_paths
%
%   The two entry points (main_FFT_HFR and FascicleTrackerApp) also call
%   this automatically, so you normally do not need to run it by hand -
%   it is provided for convenience (e.g. before running demo_enhancement).

thisDir = fileparts(mfilename('fullpath'));
addpath(genpath(thisDir));
fprintf('CODICE subfolders added to the MATLAB path.\n');
end
