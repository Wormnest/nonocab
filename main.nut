require("util/include.nut");
require("data_structures/include.nut");
require("management/include.nut");
require("advisors/include.nut");
require("pathfinding/include.nut");

class NoCAB extends AIController {
	stop = false;
   	parlement = null;
   	world = null;
   	advisors = null;
   	planner = null;
	
   	constructor() {
   		stop = false;
		parlement = Parlement();
		world = World();
		GameSettings.InitGameSettings();
		
		planner = Planner(world);
	}
}

function NoCAB::Save() { 
	Log.logWarning("Safe is not implemented yet!");
	return {};
}

function NoCAB::Load(version, data) {
	Log.logWarning("Load is not implemented yet!");
}
function NoCAB::Start()
{
	world.BuildIndustryTree();
	
		
	local connectionManager = ConnectionManager();
	advisors = [
		VehiclesAdvisor(world),
		RoadConnectionAdvisor(world, connectionManager),
		AircraftAdvisor(world, connectionManager),
		ShipAdvisor(world, connectionManager),
		//UpgradeConnectionAdvisor(world, connectionManager)
	];
	
	foreach (advisor in advisors)
		connectionManager.AddConnectionListener(advisor);
			
	// Required by the Framwork: start with sleep.
	this.Sleep(1);

	// Set president name.
	AICompany.SetPresidentName("B.C. Ridder");
	
	// Set company name.
	if(!AICompany.SetName("NoCAB - SVN 286")) {
		local i = 2;
		while(!AICompany.SetName("NoCAB #" + i + " - SVN 286")) { i++; }
	}

	AICompany.SetAutoRenewMonths(World.MONTHS_BEFORE_AUTORENEW);
	AICompany.SetAutoRenewStatus(true);

	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	
	// Start the threads!
	local pathFixer = PathFixer();
	world.pathFixer = pathFixer;
	planner.AddThread(pathFixer);
	
	foreach (advisor in advisors)
		planner.AddThread(advisor);
	
	// Do what we have to do.
	while(true) {
		GameSettings.UpdateGameSettings();
		planner.ScheduleAndExecute();
		
		// Get all reports from our advisors.
		local reports = [];
		foreach (advisor in advisors) {
			reports.extend(advisor.GetReports());
		}
		
		// Let the parlement decide on these reports and execute them!
		parlement.ClearReports();
		world.Update();	
		parlement.SelectReports(reports);
		
		while (!parlement.ExecuteReports()) {
			parlement.SelectReports(reports);
		}
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
function NoCAB::Stop() {
	this.stop = true;
	logInfo("Stopped.");
}
