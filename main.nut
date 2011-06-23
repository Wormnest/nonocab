require("util/include.nut");
require("data_structures/include.nut");
require("management/include.nut");
require("advisors/include.nut");
require("pathfinding/include.nut");

class NoCAB extends AIController {
	stop = false;
   	parlement = null;
   	world = null;
   	worldEventManager = null;
   	advisors = null;
   	planner = null;
   	loadData = null;
   	connectionManager = null;
   	pathFixer = null;
   	subsidyManager = null;
	minimalSaveVersion = 9;
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
/*	local l = AIRailTypeList();
	foreach (rt, index in l) {
		if (AIRail.IsRailTypeAvailable(rt) && AIRail.GetMaxSpeed(rt) > AIRail.GetMaxSpeed(AIRail.GetCurrentRailType())) {
			AIRail.SetCurrentRailType(rt);
			Log.logDebug("Set Rail type!!!");
//			break;
		}
	}
*/

	AICompany.SetAutoRenewMoney(1000000);
	
	AIGroup.EnableWagonRemoval(true);
	
	parlement = Parlement();
	world = World(GetSetting("NiceCAB"), GetSetting("UseDelta"));
	worldEventManager = WorldEventManager(world);
	GameSettings.InitGameSettings();
	connectionManager = ConnectionManager(worldEventManager);
	pathFixer = PathFixer();
	subsidyManager = SubsidyManager(worldEventManager);
		
	planner = Planner(world);

	if (loadData) {
		Log.logInfo("Loading game saved using version " + loadData["SaveVersion"] + "... (might take a while...)");
		Log.logInfo("(1/5) Build industry tree");
	}

	world.BuildIndustryTree();
	
	advisors = [];

	if (GetSetting("Enable road vehicles")) {
		Log.logInfo("Road vehicle advisor initiated!");
		advisors.push(RoadConnectionAdvisor(world, worldEventManager, connectionManager));
	}
	if (GetSetting("Enable airplanes")) {
		Log.logInfo("Airplane advisor initiated!");
		advisors.push(AircraftAdvisor(world, worldEventManager, connectionManager));
	}
	if (GetSetting("Enable ships")) {
		Log.logInfo("Ship advisor initiated!");
		advisors.push(ShipAdvisor(world, worldEventManager, connectionManager));
	}
	if (GetSetting("Enable trains")) {
		Log.logInfo("Train advisor initiated!");
		advisors.push(TrainConnectionAdvisor(world, worldEventManager, connectionManager, GetSetting("Allow trains town to town")));
	}
	//UpgradeConnectionAdvisor(world, connectionManager)
	
	foreach (advisor in advisors)
		connectionManager.AddConnectionListener(advisor);
		
	advisors.push(VehiclesAdvisor(connectionManager));

	if (loadData) {
		Log.logInfo("(2/5) Load path fixer data");
		pathFixer.LoadData(loadData);
		Log.logInfo("(3/5) Load active connections");
		world.LoadData(loadData);
		Log.logInfo("(4/5) Load active connections");
		connectionManager.LoadData(loadData, world);
		Log.logInfo("(5/5) Load successfull!");
	}
	
	// Required by the Framwork: start with sleep.
	initialized = true;
	this.Sleep(1);
	
	Finance.RepayLoan();
	
	// Set president name.
	AICompany.SetPresidentName("B.C. Ridder");

	// Set company name.
	local companyName =  (GetSetting("NiceCAB") ? "NiceCAB" : "NoCAB");
	if(!AICompany.SetName(companyName + " - v2.2a3")) {
		local i = 2;
		while(!AICompany.SetName(companyName + " - v2.2a3 - #" + i)) { i++; }
	}

	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	
	// Start the threads!
	world.pathFixer = pathFixer;
	planner.AddThread(pathFixer);
	
	foreach (advisor in advisors)
		planner.AddThread(advisor);

	// Determine how much NoCAB is going to get into politics.
	local politicHardness = GetSetting("Politics Setting");
	local plantTrees = politicHardness > 0;
	local buildStatues = politicHardness > 1;
	local secureRights = politicHardness > 2;
	local la = LocalAuthority(plantTrees, buildStatues, secureRights);
	
	// Do what we have to do.
	while(true) {
		
		local numberOfShips = 0;
		local shipPercentageErrors = [];
			
		local numberOfTrains = 0;
		local trainPercentageErrors = [];
			
		local numberOfTrucks = 0;
		local truckPercentageErrors = [];
			
		local numberOfAirplanes = 0;
		local airplanePercentageErrors = [];
			
		local counter = 0;
			
		foreach (connection in connectionManager.allConnections) {
			local allVehiclesInGroup = AIVehicleList_Group(connection.vehicleGroupID);
			local cargoIDTransported = connection.cargoID;
			
			local numberOfVehicles = 0;
			local incomeError = 0;
			local percentageError = 0;
			local prospectedAvgEarnings = 0;
			local actualAvgEarnings = 0;
			local percentageList = "{";

			foreach (vehicle, value in allVehiclesInGroup) {
				++counter;
				
				assert (AIVehicle.IsValidVehicle(vehicle));
				if (AIVehicle.GetAge(vehicle) > 3  * Date.DAYS_PER_YEAR) 
				{
					// Validate that the projected income of the vehicle is close to the actual earnings.
					local transportEngineID = AIVehicle.GetEngineType(vehicle);
					assert (AIEngine.IsValidEngine(transportEngineID));
						
					// Wagons will be handled by the vehicles pulling them.
					if (AIEngine.IsWagon(transportEngineID))
						continue;
							
					// Don't consider vehicles who have been ordered to stop.
					if (AIVehicle.IsStoppedInDepot(vehicle))
						continue;
						
					local travelTimeForward = connection.pathInfo.GetTravelTime(transportEngineID, true);
					local travelTimeBackward = connection.pathInfo.GetTravelTime(transportEngineID, false);
					local travelTime = travelTimeForward + travelTimeBackward;
					assert (travelTime > 0);

					local vehicleCapacity = AIVehicle.GetCapacity(vehicle, connection.cargoID);
					Log.logWarning("Main vehicle capacity: " + vehicleCapacity + "; Wagons attached to it: " + AIVehicle.GetNumWagons(vehicle));
					assert (vehicleCapacity > 0);
						
					// Calculate netto income per vehicle.
					local transportedCargoPerVehiclePerMonth = (Date.DAYS_PER_MONTH.tofloat() / travelTime) * vehicleCapacity;						

					local distance = AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation());
					local brutoIncomePerMonthPerVehicle = AICargo.GetCargoIncome(cargoIDTransported, distance, travelTimeForward.tointeger()) * transportedCargoPerVehiclePerMonth;

					// In case of a bilateral connection we take a persimistic take on the amount of 
					// vehicles supported by this connection, but we do increase the income by adding
					// the expected income of the other connection to the total.
					if (connection.bilateralConnection || connection.travelToNode.nodeType == ConnectionNode.TOWN_NODE && connection.travelFromNode.nodeType == ConnectionNode.TOWN_NODE) {
						brutoIncomePerMonthPerVehicle += AICargo.GetCargoIncome(cargoIDTransported, distance, travelTimeBackward.tointeger()) * transportedCargoPerVehiclePerMonth;
					}
					assert (brutoIncomePerMonthPerVehicle > 0);
						
					local brutoCostPerMonthPerVehicle = AIEngine.GetRunningCost(transportEngineID) / Date.MONTHS_PER_YEAR;
					assert (brutoCostPerMonthPerVehicle > 0);
					local projectedIncomePerVehiclePerYear = (brutoIncomePerMonthPerVehicle - brutoCostPerMonthPerVehicle) * Date.MONTHS_PER_YEAR;
						
					local actualIncomePerYear = AIVehicle.GetProfitLastYear(vehicle);
						
					local error = actualIncomePerYear - projectedIncomePerVehiclePerYear;
					//Log.logWarning(error + " - Actual income: " + actualIncomePerYear + "; Projected income: " + projectedIncomePerVehiclePerYear);

					++numberOfVehicles;
					incomeError += error;
					percentageError += projectedIncomePerVehiclePerYear / actualIncomePerYear;
					percentageList += percentageError + ", ";
					prospectedAvgEarnings += projectedIncomePerVehiclePerYear;
					actualAvgEarnings += actualIncomePerYear;
				}
				percentageList += "}";
			}
			
			if (numberOfVehicles > 0) {
				//if (AIVehicle.GetVehicleType(connection.vehicleTypes) == AIVehicle.VT_WATER) {
				if (connection.vehicleTypes == AIVehicle.VT_WATER) {
					++numberOfShips;
					shipPercentageErrors.push(percentageError / numberOfVehicles);
					Log.logWarning("SHIP CONNECTION: " + percentageList);
				} else if (connection.vehicleTypes == AIVehicle.VT_RAIL) {
					++numberOfTrains;
					trainPercentageErrors.push(percentageError / numberOfVehicles);
					Log.logWarning("TRAIN CONNECTION: " + percentageList);
				} else if (connection.vehicleTypes == AIVehicle.VT_ROAD) {
					++numberOfTrucks;
					truckPercentageErrors.push(percentageError / numberOfVehicles);
					Log.logWarning("TRUCK CONNECTION: " + percentageList);
				} else if (connection.vehicleTypes == AIVehicle.VT_AIR) {
					++numberOfAirplanes;
					airplanePercentageErrors.push(percentageError / numberOfVehicles);
					Log.logWarning("AEROPLANE CONNECTION: " + percentageList);
				} else {
					assert (false);
				}
				
				Log.logWarning("Prospected avg earnings: " + (prospectedAvgEarnings / numberOfVehicles) + " v.s. actual avg earnings: " + (actualAvgEarnings / numberOfVehicles));
			}
		}
			
		Log.logWarning(counter + " vehicles in spected.");
		if (numberOfShips > 0) {
			Log.logWarning("Ships: " + numberOfShips);// + " - average error: " + (shipIncomeError / numberOfShips) + " (" + (shipPercentageError / numberOfShips) + ").");
			DrawHistogram(0.37, 3, 0.25, shipPercentageErrors);
		}
		else {
			Log.logWarning("No ships!");
		}
			
		if (numberOfTrains > 0) {
			Log.logWarning("Trains: " + numberOfTrains);// + " - average error: " + (trainIncomeError / numberOfTrains) + " (" + (trainPercentageError / numberOfTrains) + ").");
			DrawHistogram(0.37, 3, 0.25, trainPercentageErrors);
		} else
			Log.logWarning("No trains!");
					
		if (numberOfTrucks > 0) {
			Log.logWarning("Trucks: " + numberOfTrucks);// + " - average error: " + (truckIncomeError / numberOfTrucks) + " (" + (truckPercentageError / numberOfTrucks) + ").");
			DrawHistogram(0.37, 3, 0.25, truckPercentageErrors);
		} else
			Log.logWarning("No trucks!");
				
		if (numberOfAirplanes > 0) {
			Log.logWarning("Airplanes: " + numberOfAirplanes);//	 + " - average error: " + (airplaneIncomeError / numberOfAirplanes) + " (" + (airplanePercentageError / numberOfAirplanes) + ").");
			DrawHistogram(0.37, 3, 0.25, airplanePercentageErrors);
		} else
			Log.logWarning("No airplanes!");
			
		
		GameSettings.UpdateGameSettings();
		planner.ScheduleAndExecute();
		// Get all reports from our advisors.
		local reports = [];
		foreach (advisor in advisors) {
			reports.extend(advisor.GetReports());
		}
		// Let the parlement decide on these reports and execute them!
		parlement.ClearReports();
		
		// Process all the events which have been fired in the mean time.
		worldEventManager.ProcessEvents();
		
		// Update all active connections and check if vehicles need to be sold / replaced, etc.
		connectionManager.MaintainActiveConnections();
		
		
		AICompany.SetAutoRenewMoney(5000000);
		parlement.SelectReports(reports);
		
		while (!parlement.ExecuteReports()) {
			parlement.SelectReports(reports);
		}

		la.HandlePolitics();
		
		AICompany.SetAutoRenewMoney(1000000);
	}
}

function DrawHistogram(min, max, step, data) {
	assert (min < max);
	assert (step > 0);

	for (local i = min; i < max + step; i += step) {
		local counter = 0.0;
		
		// Count all the data elements between [i - step, i]; 
		foreach (number in data) {
			if ((i > max || number < i) && (i == min || number > i - step)) {
				++counter;
			} 
		}
		
		local percentage = counter / data.len();
		local axis;
		if (i == min)
			axis = " < min ";
		else if (i > max)
			axis = " > max ";
		else
			axis = "# " + (i - step) + "-" + i;
		
		for (local j = axis.len(); j < 20; j++)
			axis += " ";
		axis += ": ";
		
		for (local j = 0; j < percentage * 25; j++) {
			axis += "*";
		}
		
		axis += "    " + counter + " / " + data.len() + " - " + percentage;
		
		Log.logWarning(axis);
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
 

/** Required by interface . */
function NoCAB::Stop() {
	this.stop = true;
	logInfo("Stopped.");
}
