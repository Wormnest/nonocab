class FNoCAP extends AIInfo {
      function GetAuthor()    { return "Corniel Nobel && Bram Ridder"; }
      function GetName()      { return "NoCAP";	      }
      function GetDescription()	{ return "Best AI evah"; }
      function GetVersion()	{ return 1; }
      function GetDate()	{ return "2008-07-05"; }
      function CreateInstance()	{ return "NoCAP"; }
}

RegisterAI(FNoCAP());
