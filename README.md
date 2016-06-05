# r3e-adaptive-ai-primer

Allows tweaking of the adaptive AI file for [R3E](http://game.raceroom.com/), based on a database that provides the track times the AI does at different levels.

The file can be found in 
```My Documents\My Games\SimBin\RaceRoom Racing Experience\UserData\Player1\aiadaptation.xml```

How the system works was reverse engineered [here](https://forum.sector3studios.com/index.php?threads/the-new-adaptive-ai.5013/page-4#post-70837) by the user "Cheerfullyinsane" on the sector3studios forums. This work is based upong the findings in that thread.

## Work in progress
No actual application to modify the files yet. Only a html table generator to see what values are stored in aiadaptation.xml files. The goal is to have a utility that directly modifies the file that R3E uses and makes a better experience to race against AI.


## How to use
Dump as many "aiadaptation.xml" files as you can find from many people in the "/seeds" directory. Run the tool it will generate an "ailevels.html" file similar to [this](http://htmlpreview.github.io/?https://github.com/pixeljetstream/r3e-adaptive-ai-primer/blob/master/docs/sample.html).

The table gives you AI laptimes for different levels for each track/car combo found in the database. The lower number is the "variance" in seconds, when multiple times for the same AI level were found. The lower the variance the more reliable the number (unless zero then it means we only have one entry).
