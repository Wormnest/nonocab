class FNoCAB extends AIInfo {
      function GetAuthor()    { return "Bram Ridder"; }
      function GetName()      { return "NoCAB";	      }
      function GetDescription()	{ return "Competitive AI which uses trucks, busses, aircrafts and ships. AI is currently being rewritten to add more advanced features and support for trains and trams; See the forum for more info."; }
      function GetVersion()	{ return 288; }
      function GetDate()	{ return "2009-03-18"; }
      function CreateInstance()	{ return "NoCAB"; }
      function GetShortName() { return "NCAB"; }
}

RegisterAI(FNoCAB());
