class FNoCAB extends AIInfo {
      function GetAuthor()    { return "Corniel Nobel && Bram Ridder"; }
      function GetName()      { return "NoCAB";	      }
      function GetDescription()	{ return "Best AI evah"; }
      function GetVersion()	{ return 6; }
      function GetDate()	{ return "2008-07-10"; }
      function CreateInstance()	{ return "NoCAB"; }
}

RegisterAI(FNoCAB());
