-- for now no UI
-- change what you want to edit here
-- lookup classid, trackid and your preferred ai level via results/processed.html

-- modifyAdaptive (filename, database to use, trackid, classid, ai start, ai end, ai spacing (1: e.g 90,91,92,93... 2: 90,92,94...))

print "executing edits"

local target

if (true) then
  -- absolute path
  target = [[D:\projects\r3e-adaptive-ai-primer\aiadaptation.xml]]
else
  -- danger zone
  -- make backups!
  -- this will look at the default location of the aiapdatiation.xml
  target = specialFilename([[$USER_DOCUMENTS$\My Games\SimBin\RaceRoom Racing Experience\UserData\Player1\aiadaptation.xml]])
end

-- this changes "RaceRoom Raceway - Classic Sprint" (265) for "Aquila CR1 Cup" (255)
-- it will generate ai for 97,99,101,103
-- use tighter spacing 1 instead of 2, if you are more consistent
modifyAdaptive(target, processed, "265", "255",  97, 103, 2)

