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

/// Function to check the Log Level AI setting.
function NoCAB::CheckLogLevel()
{
	// Since this is a class variable of a class that doesn't get instantiated
	// we have to set it in the global table.
	local old = Log.logLevel;
	Log.logLevel <- GetSetting("log_level");
	if ((old != Log.logLevel))
		Log.logDebug("Changed log level to " + Log.logLevel);
}

function NoCAB::Save() { 
	Log.logInfo("Saving game using version " + minimalSaveVersion + "... (might take a while...)");
	local saveTable = {};
	if (initialized) {
		saveTable["SaveVersion"] <- minimalSaveVersion;
		pathFixer.SaveData(saveTable);
		world.SaveData(saveTable);
		connectionManager.SaveData(saveTable);
		Log.logInfo("Save successful!" + saveTable["SaveVersion"]);
	} else {
		// If we didn't initialize the AI yet, make the savegame invalid.
		Log.logWarning("Can't save, we haven't finished initializing yet!");
		saveTable["SaveVersion"] <- -1;
	}

	// We don't want saving to fail since that will crash our AI.
	local opsleft = GetOpsTillSuspend();
	if (opsleft > 100) {
		if (Log.logLevel == 0)
			Log.logWarning("Ops till suspend: " + opsleft);
		local opspct = (100000-opsleft) * 100 / 100000;
		local logmsg = "Saving used " + opspct + "% of max allowed time.";
		if (opsleft < 10000)
			Log.logWarning(logmsg + " Almost running out of time saving!");
		else
			Log.logInfo(logmsg);
	}
	return saveTable;
}

function NoCAB::Load(version, data) {
	CheckLogLevel();
	local saveVersion = data["SaveVersion"];
	if (saveVersion != minimalSaveVersion) {
		// Wormnest: If you set MinVersionToLoad in info.nut correctly you will never arrive here.
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

	CheckLogLevel();
	AICompany.SetAutoRenewMoney(1000000);
	
	AIGroup.EnableWagonRemoval(true);
	
	parlement = Parlement();
	world = World(GetSetting("NiceCAB"));
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
	if (GetSetting("Enable trains")) {
		Log.logInfo("Train advisor initiated!");
		advisors.push(TrainConnectionAdvisor(world, worldEventManager, connectionManager, GetSetting("Allow trains town to town")));
	}
	if (GetSetting("Enable ships")) {
		Log.logInfo("Ship advisor initiated!");
		advisors.push(ShipAdvisor(world, worldEventManager, connectionManager));
	}
	//UpgradeConnectionAdvisor(world, connectionManager)
	
	foreach (advisor in advisors)
		connectionManager.AddConnectionListener(advisor);
		
	advisors.push(VehiclesAdvisor(connectionManager));

	if (loadData) {
		// We need up to date game settings when there are already vehicles present.
		GameSettings.UpdateGameSettings();
		Log.logInfo("(2/5) Load path fixer data");
		pathFixer.LoadData(loadData);
		Log.logInfo("(3/5) Load active connections");
		world.LoadData(loadData);
		Log.logInfo("(4/5) Load active connections");
		connectionManager.LoadData(loadData, world);
		Log.logInfo("(5/5) Load successfull!");
		// Free memory since we don't need it anymore.
		loadData = null;
	}
	
	// Required by the Framwork: start with sleep.
	initialized = true;
	this.Sleep(1);
	
	Finance.RepayLoan();
	
	// Set president name.
	AICompany.SetPresidentName("B.C. Ridder");

	// Set company name.
	local companyName =  (GetSetting("NiceCAB") ? "NiceCAB" : "NoCAB");
	local _version = " - v2.2b1";
	if(!AICompany.SetName(companyName + _version)) {
		local i = 2;
		while(!AICompany.SetName(companyName + _version + " - #" + i)) { i++; }
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
		CheckLogLevel();
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
					// For debugging purposes skip when travelTime == 0
					if (travelTime == 0) {
						Log.logError("TravelTime == 0 for vehicle: " + AIVehicle.GetName(vehicle) + ", connection: " + connection.ToString());
						continue;
					}
					assert (travelTime > 0);

					local vehicleCapacity = AIVehicle.GetCapacity(vehicle, connection.cargoID);
					if (vehicleCapacity == 0) {
						// This happened once around 2020. Since counter was 470 it must have been the roadvehicles. CargoID was 6.
						// Maybe something went wrong with autoreplace. Wrong cargo?
						Log.logError("vehicleCapacity == 0 for vehicle " + AIVehicle.GetName(vehicle) + ", cargo: " + AICargo.GetCargoLabel(connection.cargoID));
						Log.logWarning("Connection this belongs to: " + connection.ToString());
					}
					assert (vehicleCapacity > 0);
						
					// Calculate netto income per vehicle.
					local transportedCargoPerVehiclePerMonth = (Date.DAYS_PER_MONTH.tofloat() / travelTime) * vehicleCapacity;						

					local distance = AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation());
					if (distance < 0) {
						// This could happen if from or to node (industry) disappears.
						Log.logError("Invalid distance: " + distance + ", From and/or To node probably invalid!");
						continue;
					}
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
		Log.logWarning("Planner: Schedule and Execute");
		planner.ScheduleAndExecute();
		// Get all reports from our advisors.
		local reports = [];
		Log.logWarning("Get reports from advisors");
		foreach (advisor in advisors) {
			reports.extend(advisor.GetReports());
		}
		// Let the parlement decide on these reports and execute them!
		parlement.ClearReports();
		
		// Process all the events which have been fired in the mean time.
		Log.logWarning("Process World Events");
		worldEventManager.ProcessEvents();
		
		// Update all active connections and check if vehicles need to be sold / replaced, etc.
		Log.logWarning("Maintain Active connections");
		connectionManager.MaintainActiveConnections();
		
		
		AICompany.SetAutoRenewMoney(5000000);
		Log.logWarning("Select reports");
		parlement.SelectReports(reports);
		
		Log.logWarning("Execute and Select reports");
		while (!parlement.ExecuteReports()) {
			parlement.SelectReports(reports);
		}

		Log.logWarning("Handle politics");
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
