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
	initialized = null;
	
   	constructor() {
   		stop = false;
		loadData = null;
		initialized = false;
	}
}

function NoCAB::Save() { 
	Log.logInfo("Saving game using version " + minimalSaveVersion + "... (might take a while...)");
	local saveTable = {};
	if (initialized) {
		pathFixer.SaveData(saveTable);
		world.SaveData(saveTable);
		connectionManager.SaveData(saveTable);
		saveTable["SaveVersion"] <- minimalSaveVersion;
		Log.logInfo("Save successful!" + saveTable["SaveVersion"]);
	} else {
		// If we didn't initialize the AI yet, make the savegame invalid.
		saveTable["SaveVersion"] <- -1;
	}
	return saveTable;
}

function NoCAB::Load(version, data) {
	local saveVersion = data["SaveVersion"];
	if (saveVersion != minimalSaveVersion) {
		Log.logWarning("Saved version is incompatible with this version of NoCAB!");
		Log.logWarning("Only save version " + minimalSaveVersion + " is supported, your version is: " + saveVersion);
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
//			break;
		}
	}

/*	AICompany.SetAutoRenewStatus(true);
	AICompany.SetAutoRenewMonths(-1200);
*/
	AICompany.SetAutoRenewMoney(1000000);
	
	AIGroup.EnableWagonRemoval(true);
	
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
		Log.logInfo("(4/5) Load connections to stationIds");
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
		advisors.push(TrainConnectionAdvisor(world, connectionManager, GetSetting("Allow trains town to town")));
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
	initialized = true;
	this.Sleep(1);
	
	// Set president name.
	AICompany.SetPresidentName("B.C. Ridder");

	// Determine how much NoCAB is going to get into politics.
	local politicHardness = GetSetting("Politics Setting");
	local plantTrees = politicHardness > 0;
	local buildStatues = politicHardness > 1;
	local secureRights = politicHardness > 2;
	local la = LocalAuthority(plantTrees, buildStatues, secureRights);

	local politicSymbols = ["_", "-", "+", "*"];
	
	// Set company name.
	local companyName = politicSymbols[politicHardness] + (GetSetting("NiceCAB") ? "NiceCAB" : "NoCAB");
	if(!AICompany.SetName(companyName + " - v2.0.8")) {
		local i = 2;
		while(!AICompany.SetName(companyName + " - v2.0.8 - #" + i)) { i++; }
	}

	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	
	// Build the HQ.
	if (GetSetting("Build HQ"))
		if (AICompany.GetCompanyHQ(AICompany.COMPANY_SELF) == AIMap.TILE_INVALID)
			BuildHQ();
	
	
	// Start the threads!
	world.pathFixer = pathFixer;
	planner.AddThread(pathFixer);
	
	foreach (advisor in advisors)
		planner.AddThread(advisor);

	

	// Do what we have to do.
	//local thisYear = AIDate.GetYear(AIDate.GetCurrentDate());
	while(true) {
		
		/*if (thisYear != AIDate.GetYear(AIDate.GetCurrentDate())) {
			thisYear = AIDate.GetYear(AIDate.GetCurrentDate());
			AILog.Info(thisYear + "; Value " + AICompany.GetCompanyValue(AICompany.COMPANY_SELF) + "; Money: " + AICompany.GetBankBalance(AICompany.COMPANY_SELF));
			local trucks = AIVehicleList();
			trucks.Valuate(AIVehicle.GetVehicleType);
			trucks.KeepValue(AIVehicle.VT_ROAD);
			AILog.Info("Trucks: " + trucks.Count());
			
			local trains = AIVehicleList();
			trains.Valuate(AIVehicle.GetVehicleType);
			trains.KeepValue(AIVehicle.VT_RAIL);
			AILog.Info("Trains: " + trains.Count());
			
			local ships = AIVehicleList();
			ships.Valuate(AIVehicle.GetVehicleType);
			ships.KeepValue(AIVehicle.VT_WATER);
			AILog.Info("Ships: " + ships.Count());
			
			local planes = AIVehicleList();
			planes.Valuate(AIVehicle.GetVehicleType);
			planes.KeepValue(AIVehicle.VT_AIR);
			AILog.Info("Planes: " + planes.Count());
		}*/
		
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
		
		AICompany.SetAutoRenewMoney(5000000);
		parlement.SelectReports(reports);
		
		while (!parlement.ExecuteReports()) {
			parlement.SelectReports(reports);
		}

		la.HandlePolitics();
		
		AICompany.SetAutoRenewMoney(1000000);
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
