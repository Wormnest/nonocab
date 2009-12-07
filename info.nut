class FNoCAB extends AIInfo {
      function GetAuthor()    { return "Bram Ridder"; }
      function GetName()      { return "NoCAB";	      }
      function GetDescription()	{ return "Competitive AI which uses trucks, busses, aircrafts and ships. AI is currently being rewritten to add more advanced features and support for trains and trams; See the forum for more info."; }
      function GetVersion()	{ return 331; }
      function MinVersionToLoad() { return 2; }
      function GetDate()	{ return "2009-12-06"; }
      function CreateInstance()	{ return "NoCAB"; }
      function GetShortName() { return "NCAB"; }
      function GetSettings() {
		AddSetting( { name = "NiceCAB", description = "NoCAB will try to stay away from already served industries", easy_value = 1, medium_value = 0, hard_value = 0, custom_value = 0, flags = AICONFIG_BOOLEAN } );
		AddLabels("NiceCAB", {_0 = "Disabled", _1 = "Enabled"});

		AddSetting( { name = "Enable road vehicles", description = "Enable road vehicles", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN } );
		AddLabels("Enable road vehicles", {_0 = "Disabled", _1 = "Enabled"});

		AddSetting( { name = "Enable ships", description = "Enable ships", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN } );
		AddLabels("Enable ships", {_0 = "Disabled", _1 = "Enabled"});

		AddSetting( { name = "Enable airplanes", description = "Enable airplanes", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN } );
		AddLabels("Enable airplanes", {_0 = "Disabled", _1 = "Enabled"});
      }
}

RegisterAI(FNoCAB());
