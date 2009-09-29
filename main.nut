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
   	loadData = null;
   	activeConnections = null;
   	connectionManager = null;
   	pathFixer = null;
   	subsidyManager = null;
	
   	constructor() {
   		stop = false;
		parlement = Parlement();
		world = World(GetSetting("NiceCAB"));
		GameSettings.InitGameSettings();
		connectionManager = ConnectionManager();
		pathFixer = PathFixer();
		loadData = null;
		subsidyManager = SubsidyManager(world.worldEventManager);
		
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
	if (saveVersion != 1) {
		AILog.logWarning("Saved version is incompatible with this version of NoCAB!");
		AILog.logWarning("Only save version 1 is supported, your version is: " + saveVersion);
		return;
	}
	loadData = data;
}

function NoCAB::Start()
{	
	if (loadData) {
		Log.logInfo("Loading game saved using version " + loadData["SaveVersion"] + "... (might take a while...)");
		Log.logInfo("(1/4) Build industry tree");
	}

	world.BuildIndustryTree();

	if (loadData) {
		Log.logInfo("(2/4) Load path fixer data");
		pathFixer.LoadData(loadData);
		Log.logInfo("(3/4) Load active connections");
		activeConnections = world.LoadData(loadData, connectionManager);
		Log.logInfo("(4/4) Load successfull!");
	}
	
	advisors = [
		VehiclesAdvisor(world)
	];

	if (GetSetting("Enable road vehicles")) {
		Log.logInfo("Road vehicle advisor initiated!");
		advisors.push(RoadConnectionAdvisor(world, connectionManager));
	}
	if (GetSetting("Enable airplanes")) {
		Log.logInfo("Airplane advisor initiated!");
		advisors.push(AircraftAdvisor(world, connectionManager));
	}
	if (GetSetting("Enable ships")) {
		Log.logInfo("Ship advisor initiated!");
		advisors.push(ShipAdvisor(world, connectionManager));
	}

	//UpgradeConnectionAdvisor(world, connectionManager)
	
	foreach (advisor in advisors)
		connectionManager.AddConnectionListener(advisor);
	
	// If we loaded a game, add all active connections to the listeners.
	if (loadData) {
		foreach (connection in activeConnections) {
			connectionManager.ConnectionRealised(connection);
		}
	}
	
	// Required by the Framwork: start with sleep.
	this.Sleep(1);
	
	// Set president name.
	AICompany.SetPresidentName("B.C. Ridder");
	
	// Set company name.
	local companyName = GetSetting("NiceCAB") ? "NiceCAB" : "NoCAB";
	if(!AICompany.SetName(companyName + " - v1.23")) {
		local i = 2;
		while(!AICompany.SetName(companyName + " - v1.23#" + i)) { i++; }
	}

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
