NoNoCAB is a competitive AI which uses trains, trucks, buses, aircraft and ships.

Current version: 6, released April 23, 2019.

Contents
--------
1. Introduction
2. Bug reporting and other links
3. Requirements
4. Limitations
5. NoCAB links
6. License


1. Introduction
---------------
NoNoCAB is a forked version of NoCAB which fixes the most annoying bugs and crashes
of the OpenTTD AI NoCAB. NoCAB is in general a very well performing AI but it
has some problems which have made it less fun to use.

Since there hasn't been any progress in a while I decided to see if I could do
something about the biggest problems especially the crashing while saving.
Besides that lots of other problems have been fixed and improvements have been made.

The idea behind this ai and it's precursor NoCAB is to predict the profits of a
connection (route, cargo, vehicle combination) and build the ones that it thinks
are the most profitable.


2. Bug reporting and other links
--------------------------------
I am not aware of any crashes still appearing but please report any
problems that you encounter in NoNoCAB's forum topic listed below.
Remarks aboput possible improvements or non optimal handling of
certain situations are also welcome.

NoNoCAB forum topic:
https://www.tt-forums.net/viewtopic.php?f=65&t=75030

Details about all changes can be found in my forked repository:
https://bitbucket.org/jacobb/nocab/overview


3. Requirements
---------------
NoNoCAB uses the AI library Queue.BinaryHeap (version 1).
Minimum OpenTTD version: 1.2.


4. Limitations
--------------
NoNoCAB generally prefers building longer (train, road vehicle) routes.
As such it will use a lot of infrastructure which means it may have
problems when infrastructure maintenance is on. In this case it is
advisable to disable aircraft for NoNoCAB (or all ais) or at the
very least set the plane speed factor to 1/1 instead of the default 1/4.
It does not have any special handling for industry NewGRFs, In general
this usually doesn't cause too many problems but certain industry
types may be handled non optimal.
There is no support for goal scripts meaning NoNoCAB will try to do its
normal thing without consideration for any possible goals.


5. NoCAB links
--------------
The original NoCAB is an AI by Morloth.

Original forum topics:
NoCAB: https://www.tt-forums.net/viewtopic.php?f=65&t=40203
NoCAB Bleeding Edge: https://www.tt-forums.net/viewtopic.php?f=65&t=43259


6. License
----------
NoCAB and NoNoCAB have a GPL version 2 license.
Details of this license can be found in the file license.txt.

The changes in this edition have been made by Wormnest (Jacob Boerema).
