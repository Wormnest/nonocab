require("version.nut");

class FNoNoCAB extends AIInfo {
      function GetAuthor()    { return "Bram Ridder, Jacob Boerema"; }
      function GetName()      { return "NoNoCAB"; }
      function GetDescription()	{ return "NoNoCAB is a fixed and improved version of NoCAB by Wormnest. It is a competitive AI which uses trains, trucks, buses, aircraft and ships."; }
      function GetVersion()	{ return SELF_VERSION; }
      function MinVersionToLoad() { return 1; }
      function GetDate()	{ return SELF_DATE; }
      function CreateInstance()	{ return "NoNoCAB"; }
      function GetShortName() { return "NONO"; }
      function GetAPIVersion() { return "1.2"; }
	  function GetURL()        { return "https://www.tt-forums.net/viewtopic.php?f=65&t=75030"; }
	  function GetSettings() {
		AddSetting( { name = "NiceCAB", description = "NoNoCAB will try to stay away from already served industries", easy_value = 1, medium_value = 0, hard_value = 0, custom_value = 0, flags = AICONFIG_BOOLEAN } );
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

		AddSetting( { name = "Politics Setting", description = "Aggressiveness", min_value = 0, max_value = 3, easy_value = 0, medium_value = 1, hard_value = 2, custom_value = 2, flags = 0} );
		AddLabels(
			"Politics Setting", 
			{_0 = "NoNoCAB is a friendly competitor", 
			_1 = "NoNoCAB is friendly but can plant trees", 
			_2 = "NoNoCAB can also build statues and a headquarter", 
			_3 = "NoNoCAB will also try to get exclusive transport rights"});

		// Developer setting to make it possible to change log level in a running game.
		AddSetting({
			name = "log_level",
			description = "How much info to show in the AI log.",
			min_value = 0,
			max_value = 3,
			easy_value = 1,
			medium_value = 1,
			hard_value = 2,
			custom_value = 2,
			step_size = 1,
			flags = CONFIG_DEVELOPER + CONFIG_INGAME
		});
		AddLabels(
			"log_level", 
			{_0 = "Everything including debug info",_1 = "Everything except debug info", _2 = "Warnings and errors only", _3 = "Errors only"}
		);

      }
}

RegisterAI(FNoNoCAB());
