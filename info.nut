class FNoCAB extends AIInfo {
      function GetAuthor()    { return "Bram Ridder"; }
      function GetName()      { return "WormCAB";	      }
      function GetDescription()	{ return "Fixed version of NoCAB by Wormnest. Competitive AI which uses trains, trucks, busses, aircrafts and ships."; }
      function GetVersion()	{ return 620; }
      function MinVersionToLoad() { return 9; }
      function GetDate()	{ return "2016-06-18"; }
      function CreateInstance()	{ return "NoCAB"; }
      function GetShortName() { return "WCAB"; }
      function GetAPIVersion() { return "1.2"; }
	  function GetURL()        { return "https://www.tt-forums.net/viewtopic.php?p=1170011#p1170011"; }
	  function GetSettings() {
		AddSetting( { name = "NiceCAB", description = "NoCAB will try to stay away from already served industries", easy_value = 1, medium_value = 0, hard_value = 0, custom_value = 0, flags = AICONFIG_BOOLEAN } );
		AddLabels("NiceCAB", {_0 = "Disabled", _1 = "Enabled"});

		AddSetting( { name = "Enable road vehicles", description = "Enable road vehicles", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN } );
		AddLabels("Enable road vehicles", {_0 = "Disabled", _1 = "Enabled"});

		AddSetting( { name = "Enable ships", description = "Enable ships", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN } );
		AddLabels("Enable ships", {_0 = "Disabled", _1 = "Enabled"});

		AddSetting( { name = "Enable airplanes", description = "Enable airplanes", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN } );
		AddLabels("Enable airplanes", {_0 = "Disabled", _1 = "Enabled"});

		AddSetting( { name = "Enable trains", description = "Enable trains", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN } );
		AddLabels("Enable trains", {_0 = "Disabled", _1 = "Enabled"});

		AddSetting( { name = "Allow trains town to town", description = "Allow trains town to town", easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0, flags = AICONFIG_BOOLEAN } );
		AddLabels("Allow trains town to town", {_0 = "No", _1 = "Yes (Doesn't perform well!)"});

		AddSetting( { name = "Politics Setting", description = "Politics Setting", min_value = 0, max_value = 3, easy_value = 0, medium_value = 1, hard_value = 2, custom_value = 2, flags = 0} );
		AddLabels("Politics Setting", {_0 = "NoCAB stays away from politics!", _1 = "Hippy friendly tree planter", _2 = "Build statues and an HQ to see who's boss", _3 = "Machiavellian - No one transports but NoCAB!"});

		// Developer setting to make it possible to change log level in a running game.
		AddSetting({
			name = "log_level",
			description = "How much info to show in the AI log.",
			min_value = 0,
			max_value = 3,
			easy_value = 1,
			medium_value = 1,
			hard_value = 1,
			custom_value = 1,
			step_size = 1,
			flags = CONFIG_DEVELOPER + CONFIG_INGAME
		});
		AddLabels(
			"log_level", 
			{_0 = "Everything including debug info",_1 = "Everything except debug info", _2 = "Warnings and errors only", _3 = "Errors only"}
		);

      }
}

RegisterAI(FNoCAB());
