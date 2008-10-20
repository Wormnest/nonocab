class FNoCAB extends AIInfo {
      function GetAuthor()    { return "Corniel Nobel && Bram Ridder"; }
      function GetName()      { return "NoCAB";	      }
      function GetDescription()	{ return "Making AIs cry since 2008"; }
      function GetVersion()	{ return 12; }
      function GetDate()	{ return "2008-10-20"; }
      function CreateInstance()	{ return "NoCAB"; }
}

RegisterAI(FNoCAB());
