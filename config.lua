-- general setup

-- leave r3egamedir nil to use a registry query, otherwise enter manually (directory that contains RRRE.exe)
-- e.g [[C:\Program Files (x86)\Steam\SteamApps\common\raceroom racing experience\Game]]
r3egamedir = nil

-- html generation
reportfile = "database.html"
processedfile = "processed.html"
stylesheetfile = "_style.css"
minAI = 80
maxAI = 120
embedStylesheet = "results/_style.css" -- leave nil if you just want to link to above file

-- general
seeddir       = "seeds/"
outdir        = "results/"
databasefile  = "database.lua"

-- curve fitting
fitAll = true -- uses all samples, otherwise uses average
-- plausibility
-- we compare an interpolated value with recorded values
-- if recorded is within threshold to computed we think our data for the track is sane
testMaxTimePct   = 0.05  -- percentage (1.0 = 100%) of fastest time we have
testMaxFailsPct  = 0.20  -- how many outliers we accept per track (min is 1)
testMinAIdiffs   = 4     -- how far away the extreme AI levels we have for a track must be at least

-- ui tool related
-- for now only USER_DOCUMENTS is a special variable
targetfile   = [[$USER_DOCUMENTS$\My Games\SimBin\RaceRoom Racing Experience\UserData\Player1\aiadaptation.xml]]
aiNumLevels  = 5
aiSpacing    = 1

