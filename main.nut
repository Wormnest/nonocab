require("util/include.nut");
require("data_structures/include.nut");
require("pathfinding/include.nut");
require("management/include.nut");
require("advisors/include.nut");

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
			ConnectionAdvisor(world)
		];
		 
		
	}
}

function NoCAB::Save() { return {};}
function NoCAB::Load() {}
function NoCAB::Start()
{
	// Required by the Framwork: start with sleep.
	this.Sleep(1);

	// Set president name.
	AICompany.SetPresidentName("B.C. Ridder");
	
	// Set company name.
	if(!AICompany.SetName("NoCAB")) {
		local i = 2;
		while(!AICompany.SetName("NoCAB #" + i)) { i++; }
	}
	
	AICompany.SetAutoRenewMonths(12 * 12);
	AICompany.SetAutoRenewStatus(true);
	
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
		/*
		{
			local pf = RoadPathFinding();
			pf.FixBuildLater();
		}
		*/
		parlement.SelectReports(reports);
		parlement.ExecuteReports();
	}
	Log.logInfo("Done!");
}
/**
 * Build Head Quaters at the largest place available. 
 */
function NoCAB::BuildHQ()
{
	Log.logInfo("Build Head Quaters.");
	Log.logDebug("TODO: not implemented.");
}
/** Required by interface . */
function NoCAB::Stop()
{
	this.stop = true;
	logInfo("Stopped.");
}
