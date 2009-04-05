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
   	didLoad = null;
   	activeConnections = null;
   	connectionManager = null;
   	pathFixer = null;
	
   	constructor() {
   		stop = false;
		parlement = Parlement();
		world = World();
		GameSettings.InitGameSettings();
		connectionManager = ConnectionManager();
		pathFixer = PathFixer();
		didLoad = false;
		
		planner = Planner(world);
	}
}

function NoCAB::Save() { 
	Log.logInfo("Saving game using version 1... (might take a while...)");
	local saveTable = {};
	pathFixer.SaveData(saveTable);
	world.SaveData(saveTable);
	saveTable["SaveVersion"] <- 1;
	Log.logInfo("Save successful!");
	return saveTable;
}

function NoCAB::Load(version, data) {
	local saveVersion = data["SaveVersion"];
	Log.logInfo("Loading game saved using version " + saveVersion + "... (might take a while...)");
	if (saveVersion != 1) {
		AILog.logWarning("Saved version is incompatible with this version of NoCAB!");
		AILog.logWarning("Only save version 1 is supported, your version is: " + saveVersion);
		return;
	}
	pathFixer.LoadData(data);
	activeConnections = world.LoadData(data, connectionManager);
	didLoad = true;
}

function NoCAB::Start()
{	
	if (!didLoad)
		world.BuildIndustryTree();
	
	advisors = [
		VehiclesAdvisor(world),
		RoadConnectionAdvisor(world, connectionManager),
		AircraftAdvisor(world, connectionManager),
		ShipAdvisor(world, connectionManager),
		//UpgradeConnectionAdvisor(world, connectionManager)
	];
	
	foreach (advisor in advisors)
		connectionManager.AddConnectionListener(advisor);
	
	// If we loaded a game, add all active connections to the listeners.
	if (didLoad) {
		foreach (connection in activeConnections) {
			connectionManager.ConnectionRealised(connection);
		}
	}
	
	// Required by the Framwork: start with sleep.
	this.Sleep(1);
	
	// Set president name.
	AICompany.SetPresidentName("B.C. Ridder");
	
	// Set company name.
	if(!AICompany.SetName("NoCAB - Version 1.16")) {
		local i = 2;
		while(!AICompany.SetName("NoCAB - Version 1.16 #" + i)) { i++; }
	}


	AICompany.SetAutoRenewMonths(World.MONTHS_BEFORE_AUTORENEW);
	AICompany.SetAutoRenewStatus(true);

	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	
	// Start the threads!
	
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
