class FNoCAB extends AIInfo {
      function GetAuthor()    { return "Corniel Nobel && Bram Ridder"; }
      function GetName()      { return "NoCAB";	      }
      function GetDescription()	{ return "Best AI evah, we hope"; }
      function GetVersion()	{ return 11; }
      function GetDate()	{ return "2008-09-20"; }
      function CreateInstance()	{ return "NoCAB"; }
}

RegisterAI(FNoCAB());
