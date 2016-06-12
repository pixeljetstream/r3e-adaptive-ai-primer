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

-- plausibility
-- we compare an interpolated value with recorded values
-- if recorded is within threshold to computed we think our data for the track is sane
testMaxTimePct   = 0.05  -- percentage (1.0 = 100%) of fastest time we have
testMaxFailsPct  = 0.33  -- how many outliers we accept per track (min is 1)
testMinAIdiffs   = 3     -- how far away the extreme AI levels we have for a track must be at least

-- for now only USER_DOCUMENTS is a special variable
targetfile   = [[$USER_DOCUMENTS$\My Games\SimBin\RaceRoom Racing Experience\UserData\Player1\aiadaptation.xml]]

