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
	minimalSaveVersion = 7;
	
   	constructor() {
   		stop = false;
		loadData = null;
	}
}

function NoCAB::Save() { 
	Log.logInfo("Saving game using version " + minimalSaveVersion + "... (might take a while...)");
	local saveTable = {};
	pathFixer.SaveData(saveTable);
	world.SaveData(saveTable);
	connectionManager.SaveData(saveTable);
	saveTable["SaveVersion"] <- minimalSaveVersion;
	Log.logInfo("Save successful!" + saveTable["SaveVersion"]);
	return saveTable;
}

function NoCAB::Load(version, data) {
	local test = data["starting_year"];
	local saveVersion = data["SaveVersion"];
	if (saveVersion != minimalSaveVersion) {
		AILog.logWarning("Saved version is incompatible with this version of NoCAB!");
		AILog.logWarning("Only save version 4 is supported, your version is: " + saveVersion);
		return;
	}
	loadData = data;
}

function NoCAB::Start()
{
	// Initialize the AI.
	local l = AIRailTypeList();
	foreach (rt, index in l) {
		if (AIRail.IsRailTypeAvailable(rt)) {
			AIRail.SetCurrentRailType(rt);
			Log.logDebug("Set Rail type!!!");
			break;
		}
	}
	
	parlement = Parlement();
	world = World(GetSetting("NiceCAB"));
	GameSettings.InitGameSettings();
	connectionManager = ConnectionManager();
	pathFixer = PathFixer();
	subsidyManager = SubsidyManager(world.worldEventManager);
		
	planner = Planner(world);

	if (loadData) {
		Log.logInfo("Loading game saved using version " + loadData["SaveVersion"] + "... (might take a while...)");
		Log.logInfo("(1/5) Build industry tree");
	}

	world.BuildIndustryTree();

	if (loadData) {
		Log.logInfo("(2/5) Load path fixer data");
		pathFixer.LoadData(loadData);
		Log.logInfo("(3/5) Load active connections");
		activeConnections = world.LoadData(loadData, connectionManager);
		Log.logInfo("4/5 Load connections to stationIds");
		connectionManager.LoadData(loadData);
		Log.logInfo("(5/5) Load successfull!");
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
	if (GetSetting("Enable trains")) {
		Log.logInfo("Train advisor initiated!");
		advisors.push(TrainConnectionAdvisor(world, connectionManager));
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
	if(!AICompany.SetName(companyName + " - v2.0a14")) {
		local i = 2;
		while(!AICompany.SetName(companyName + " - v2.0a14 - #" + i)) { i++; }
	}

	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	
	// Build the HQ.
	BuildHQ();
	
	
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
 * NOTE: Shameless copy of Rondje's code :).
 */
function Sqrt(i) {
	if (i == 0)
		return 0;   // Avoid divide by zero
	local n = (i / 2) + 1;       // Initial estimate, never low
	local n1 = (n + (i / n)) / 2;
	while (n1 < n) {
		n = n1;
		n1 = (n + (i / n)) / 2;
	}
	return n;
}
 
function NoCAB::BuildHQ()
{
	// Check if we have an HQ.
	if (AICompany.GetCompanyHQ(AICompany.COMPANY_SELF) != AIMap.TILE_INVALID) {
		Log.logDebug("We already have an HQ, continue!");
		return;
	}
	Log.logInfo("Build HQ!");
	
	// Find biggest town for HQ
	local towns = AITownList();
	towns.Valuate(AITown.GetPopulation);
	towns.Sort(AIAbstractList.SORT_BY_VALUE, true);
	local town = towns.Begin();
	
	// Find empty 2x2 square as close to town centre as possible
	local maxRange = Sqrt(AITown.GetPopulation(town)/100) + 5; //TODO check value correctness
	local HQArea = AITileList();
	
	HQArea.AddRectangle(AITown.GetLocation(town) - AIMap.GetTileIndex(maxRange, maxRange), AITown.GetLocation(town) + AIMap.GetTileIndex(maxRange, maxRange));
	HQArea.Valuate(AITile.IsBuildableRectangle, 2, 2);
	HQArea.KeepValue(1);
	HQArea.Valuate(AIMap.DistanceManhattan, AITown.GetLocation(town));
	HQArea.Sort(AIList.SORT_BY_VALUE, true);
	
	for (local tile = HQArea.Begin(); HQArea.HasNext(); tile = HQArea.Next()) {
		if (AICompany.BuildCompanyHQ(tile)) {
			return;
		}
	}
}

/** Required by interface . */
function NoCAB::Stop() {
	this.stop = true;
	logInfo("Stopped.");
}
