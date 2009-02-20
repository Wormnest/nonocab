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
   	eventManager = null;
	
   	constructor() {
   		stop = false;
		parlement = Parlement();
		eventManager = EventManager();
		world = World(eventManager);
		GameSettings.InitGameSettings();
		
		local connectionManager = ConnectionManager();

		local vehicleAdvisor = VehiclesAdvisor(world);
		local updateAdvisor = UpgradeConnectionAdvisor(world, connectionManager);
		connectionManager.AddConnectionListener(vehicleAdvisor);
		connectionManager.AddConnectionListener(updateAdvisor);
		advisors = [
			vehicleAdvisor,
			RoadConnectionAdvisor(world, connectionManager, eventManager),
			AircraftAdvisor(world, connectionManager, eventManager),
			//ShipAdvisor(world, connectionManager, eventManager),
			//updateAdvisor
		];
		
		planner = Planner(world);
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

	AICompany.SetAutoRenewMonths(World.MONTHS_BEFORE_AUTORENEW);
	AICompany.SetAutoRenewStatus(true);

	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	
	// Start the threads!
	local pathFixer = PathFixer();
	world.pathFixer = pathFixer;
	planner.AddThread(pathFixer);
	
	
	foreach (advisor in advisors) {
		planner.AddThread(advisor);
	}
	// Do what we have to do.
	world.Update();
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
		eventManager.ProcessEvents();	
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
function NoCAB::Stop() {
	this.stop = true;
	logInfo("Stopped.");
}
