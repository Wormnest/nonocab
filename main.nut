require("data_structures/fibonacciheap.nut");
require("pathfinding/pathfinding.nut");
require("pathfinding/tiles.nut");
require("utils.nut");
require("industry.nut");
require("World.nut");
require("Parlement.nut");
require("Action.nut");
require("Advisor.nut");
require("Advisor_Finance.nut");

class NoCAB extends AIController {
	stop = false;
   	parlement = null;
   	advisors = array(0);
	
   	constructor() {
		this.parlement = Parlement();
		this.advisors = array(1);
		
		this.advisors[0] = FinanceAdvisor(World()); 
		
	}
	//function Start();
	//function Stop();
}
function NoCAB::Save() { return {};}
function NoCAB::Load() {}
function NoCAB::Start()
{
	// Required by the Framwork: start with sleep.
	this.Sleep(1);
	AILog.Info("Starting...")
	Utils.logDebug("Log DEBUG enabled.");
	Utils.logInfo("Log INFO enabled.");
	Utils.logWarning("Log WARNING enabled.");
	Utils.logError("Log ERROR enabled.");

	// Set president name.
	if(!AICompany.SetPresidentName("B.C.Ridder-Nobel")) {
	if(!AICompany.SetPresidentName("B.Ridder")) {
	if(!AICompany.SetPresidentName("C.Nobel")) {
	if(!AICompany.SetPresidentName("B.Ridder jr.")) {
	if(!AICompany.SetPresidentName("C.Nobel jr.")) {
		logWarning("Presidentname could not be set.");
	} } } } }
	// Set company name.
	if(!AICompany.SetCompanyName("NoCAB")) {
		local i = 2;
		while(!AICompany.SetCompanyName("NoCAB #" + i)) { i++; }
	}
	Utils.logInfo(AICompany.GetCompanyName(8));
	Utils.logInfo(AICompany.GetPresidentName(8));

	// Do what we have to do.
	while(true)
	{
		
		this.Sleep(500);
	}
	
	
	//	if(this.company.
	// Get max loan!
	while(true) {
		local comp = AICompany();
		AICompany.SetLoanAmount(comp.GetMaxLoanAmount());

		local indus = IndustryManager();
		indus.UpdateIndustry();
        	this.Sleep(500);
	}
	Utils.logInfo("Done!");
}

/** Required by interface . */
function NoCAB::Stop()
{
	this.stop = true;
	logInfo("Stopped.");
}