NoCAB - Fixed version of the Bleeding Edge Edition.

This is a version of NoCAB which fixes the most annoying bugs and crashes (I hope)
of the OpenTTD AI NoCAB. NoCAB is in general a very well performin AI but it
has some problems which have made it less fun to use.

Since there hasn't been any progress in a while I decided to see if I could do
something about the biggest problems.

1. Crashing when saving. Since it stores a lot of info NoCAB often ran out of
time, especially on larger maps, when saving. Since I think staying alive is
more important I changed it's save logic to stop saving it's connections as
soon as it detects it's getting close to running out of time.
Of course it will not know some of the connections after loading a save game
but at least it will not crash and keep running the current game.

2. It was not taking the map borders into consideration when checking
available spots near towns. In certain cases when a town was near the
map border it could take very long (about a year) to decide on available tiles.

3. On large maps with a high amount of towns and industries it could cause
OpenTTD to run out of memory causing it to crash. The cause of this was
that NoCAB tried to store data for all towns and industries. I changed this
to limit the towns to the top 1000 towns with the highest population and
a random choice of a maximum of 2000 industries.

4. Loading a savegame could cause a crash because certain data needed to
determine the route travel time wasn't saved. We fixed this by
recomputing certain data after loading a savegame.

Details about all changes can be found in my forked repository:
https://bitbucket.org/jacobb/nocab/overview

Original forum topics:
NoCAB: http://www.tt-forums.net/viewtopic.php?f=65&t=40203
NoCAB Bleeding Edge: http://www.tt-forums.net/viewtopic.php?f=65&t=43259

NoCAB is an AI by Morloth.
The fixes in this edition have been made by Wormnest.

June 2016
