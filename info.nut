class FNoCAB extends AIInfo {
      function GetAuthor()    { return "Bram Ridder"; }
      function GetName()      { return "NoCAB";	      }
      function GetDescription()	{ return "Competitive AI which uses trains, trucks, busses, aircrafts and ships. See the forum for more info."; }
      function GetVersion()	{ return 441; }
      function MinVersionToLoad() { return 7; }
      function GetDate()	{ return "2010-04-02"; }
      function CreateInstance()	{ return "NoCAB"; }
      function GetShortName() { return "NCAB"; }
      function GetAPIVersion() { return 0.7; }
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
      }
}

RegisterAI(FNoCAB());
