class FNoCAB extends AIInfo {
      function GetAuthor()    { return "Bram Ridder"; }
      function GetName()      { return "NoCAB";	      }
      function GetDescription()	{ return "Making AIs cry since 2008"; }
      function GetVersion()	{ return 13; }
      function GetDate()	{ return "2008-11-13"; }
      function CreateInstance()	{ return "NoCAB"; }
}

RegisterAI(FNoCAB());
