require("data_structures/fibonacciheap.nut");
require("pathfinding/pathfinding.nut");
require("pathfinding/tiles.nut");
require("utils.nut");
require("industry.nut");
require("management/World.nut");
require("management/Parlement.nut");
require("management/Action.nut");
require("advisors/Advisor.nut");
require("advisors/Advisor_Finance.nut");
require("advisors/Advisor_Connections.nut");

class NoCAB extends AIController {
	stop = false;
   	parlement = null;
   	world = null;
   	advisors = null;
	
   	constructor() {
   		stop = false;
		this.parlement = Parlement();
		this.world = World();
		
		this.advisors = [
			FinanceAdvisor(world),
			ConnectionAdvisor(world)
		];
		 
		
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

	local world = World();
	//local adv = ConnectionAdvisor(world);
	//adv.PrintTree();
	//adv.getReports();

	// Do what we have to do.
	while(true)
	{
		world.Update();
		
		// Get all reports from our advisors.
		local reports = [];
		foreach (advisor in advisors) {
			reports.extend(advisor.getReports());
		}
		
		// Let the parlement decide on these reports and execute them!
		parlement.ClearReports();
		parlement.SelectReports(reports);
		parlement.ExecuteReports();
		
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
