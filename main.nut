require("util/include.nut");
require("data_structures/include.nut");
require("management/include.nut");
require("advisors/include.nut");
require("pathfinding/include.nut");
require("version.nut");

class NoNoCAB extends AIController {
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
	la = null;					// Local Authority class
	// Easy access to our vehicle advisors
	_rvAdvisor = null;
	_airAdvisor = null;
	_trainAdvisor = null;
	_shipAdvisor = null;
	
   	constructor() {
   		stop = false;
		loadData = null;
		initialized = false;
	}
}

/// Function to check the Log Level AI setting.
function NoNoCAB::CheckLogLevel()
{
	// Since this is a class variable of a class that doesn't get instantiated
	// we have to set it in the global table.
	local old = Log.logLevel;
	Log.logLevel <- GetSetting("log_level");
	if ((old != Log.logLevel))
		Log.logDebug("Changed log level to " + Log.logLevel);
}

function NoNoCAB::Save() { 
	Log.logInfo("Saving game using version " + minimalSaveVersion);
	local saveTable = {};
	if (initialized) {
		saveTable["SaveVersion"] <- minimalSaveVersion;
		pathFixer.SaveData(saveTable);
		world.SaveData(saveTable);
		connectionManager.SaveData(saveTable);
		Log.logInfo("Save successful!");
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

function NoNoCAB::Load(version, data) {
	CheckLogLevel();
	local saveVersion = data["SaveVersion"];
	if (saveVersion != minimalSaveVersion) {
		// Wormnest: If you set MinVersionToLoad in info.nut correctly you will never arrive here.
		Log.logWarning("Saved version is incompatible with this version of NoNoCAB!");
		Log.logWarning("Only save version " + minimalSaveVersion + " is supported, your version is: " + saveVersion);
		return;
	}
	loadData = data;
}

/**
 * Checks the user changeable settings and updates them.
 */
function NoNoCAB::UpdateSettings() {
	// Determine how much NoNoCAB is going to get into politics.
	local politicHardness = GetSetting("Politics Setting");
	local plantTrees = politicHardness > 0;
	local buildStatues = politicHardness > 1;
	local secureRights = politicHardness > 2;
	
	if (la == null)
		la = LocalAuthority(plantTrees, buildStatues, secureRights);
	else {
		la.improveRelationsEnabled = plantTrees;
		la.buildStatuesEnabled = buildStatues;
		la.secureRightsEnabled = secureRights;
	}
	
	// Check competitors setting
	world.niceCABEnabled = GetSetting("NiceCAB");
	
	// Check which vehicle types are enabled/disabled by the user either for our ai or globally.
	_rvAdvisor.disabled = !GetSetting("Enable road vehicles") ||
		AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_ROAD) ||
		AIGameSettings.GetValue("max_roadveh") == 0;
	_airAdvisor.disabled = !GetSetting("Enable airplanes") ||
		AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_AIR) ||
		AIGameSettings.GetValue("max_aircraft") == 0 ||
		// If Infrastructure maintenance is on and plane speed is slower than 1/2 disable aircraft since it won't be profitable
		(AIGameSettings.GetValue("infrastructure_maintenance") == 1 && AIGameSettings.GetValue("plane_speed") > 2);
	_trainAdvisor.disabled = !GetSetting("Enable trains") ||
		AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_RAIL) ||
		AIGameSettings.GetValue("max_trains") == 0;
	_shipAdvisor.disabled = !GetSetting("Enable ships") ||
		AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_WATER) ||
		AIGameSettings.GetValue("max_ships") == 0;
	
	// Update setting to (dis)allow trains for town to town connections.
	_trainAdvisor.allowTownToTownConnections = GetSetting("Allow trains town to town");
}

function NoNoCAB::Start()
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

	// To make it easier to update the disabled state of a certain type of vehicle advisor we save
	// the vehicle advisors also as class variables. The disabled state is updated in UpdateSettings.
	_rvAdvisor = RoadConnectionAdvisor(world, worldEventManager, connectionManager);
	advisors.push(_rvAdvisor);
	_airAdvisor = AircraftAdvisor(world, worldEventManager, connectionManager);
	advisors.push(_airAdvisor);
	_trainAdvisor = TrainConnectionAdvisor(world, worldEventManager, connectionManager, GetSetting("Allow trains town to town"));
	advisors.push(_trainAdvisor);
	_shipAdvisor = ShipAdvisor(world, worldEventManager, connectionManager);
	advisors.push(_shipAdvisor);
	
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
		
		if (Log.logLevel == 0)
			connectionManager.PrintConnections();
	}
	
	// DEBUG TESTING
	/*Log.logDebug("Tile AITile.SLOPE_FLAT " + AITile.SLOPE_FLAT);
	Log.logDebug("Tile AITile.SLOPE_W " + AITile.SLOPE_W);
	Log.logDebug("Tile AITile.SLOPE_S " + AITile.SLOPE_S);
	Log.logDebug("Tile AITile.SLOPE_E " + AITile.SLOPE_E);
	Log.logDebug("Tile AITile.SLOPE_N " + AITile.SLOPE_N);
	Log.logDebug("Tile AITile.SLOPE_STEEP " + AITile.SLOPE_STEEP);
	Log.logDebug("Tile AITile.SLOPE_NW " + AITile.SLOPE_NW);
	Log.logDebug("Tile AITile.SLOPE_SW " + AITile.SLOPE_SW);
	Log.logDebug("Tile AITile.SLOPE_SE " + AITile.SLOPE_SE);
	Log.logDebug("Tile AITile.SLOPE_NE " + AITile.SLOPE_NE);
	Log.logDebug("Tile AITile.SLOPE_EW " + AITile.SLOPE_EW);
	Log.logDebug("Tile AITile.SLOPE_NS " + AITile.SLOPE_NS);
	Log.logDebug("Tile AITile.SLOPE_ELEVATED " + AITile.SLOPE_ELEVATED);
	Log.logDebug("Tile AITile.SLOPE_NWS " + AITile.SLOPE_NWS);
	Log.logDebug("Tile AITile.SLOPE_WSE " + AITile.SLOPE_WSE);
	Log.logDebug("Tile AITile.SLOPE_SEN " + AITile.SLOPE_SEN);
	Log.logDebug("Tile AITile.SLOPE_ENW " + AITile.SLOPE_ENW);
	Log.logDebug("Tile AITile.SLOPE_STEEP_W " + AITile.SLOPE_STEEP_W);
	Log.logDebug("Tile AITile.SLOPE_STEEP_S " + AITile.SLOPE_STEEP_S);
	Log.logDebug("Tile AITile.SLOPE_STEEP_E " + AITile.SLOPE_STEEP_E);
	Log.logDebug("Tile AITile.SLOPE_STEEP_N " + AITile.SLOPE_STEEP_N);
	Log.logDebug("Tile AITile.SLOPE_INVALID " + AITile.SLOPE_INVALID);*/
	
	// Required by the Framwork: start with sleep.
	initialized = true;
	this.Sleep(1);
	
	Finance.RepayLoan();
	
	// Set president name.
	AICompany.SetPresidentName("C.E.O. Worm");

	// Set company name.
	local companyName =  "NoNoCAB";
	local _version = " - v" + SELF_VERSION;
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

	// Do what we have to do.
	while(true) {
		UpdateSettings();			// Checks whether any user settings have been changed.
		CheckLogLevel();			// Checks whether the log level has been changed.
		
		/* For Debugging/Testing
		Log.logWarning( "------------------------------");
		Log.logWarning( "Quarterly Income: " + AICompany.GetQuarterlyIncome(AICompany.COMPANY_SELF,AICompany.CURRENT_QUARTER+1));
		Log.logWarning( "Quarterly Expenses: " + AICompany.GetQuarterlyExpenses(AICompany.COMPANY_SELF,AICompany.CURRENT_QUARTER+1));
		Log.logWarning( "Delivered Cargo: " + AICompany.GetQuarterlyCargoDelivered(AICompany.COMPANY_SELF,AICompany.CURRENT_QUARTER+1));
		Log.logWarning( "Performance Rating: " + AICompany.GetQuarterlyPerformanceRating(AICompany.COMPANY_SELF,AICompany.CURRENT_QUARTER+1));
		Log.logWarning( "Company Value: " + AICompany.GetQuarterlyCompanyValue(AICompany.COMPANY_SELF,AICompany.CURRENT_QUARTER+1));
		
		Log.logWarning( "Monthly Road infrastructure costs: " + AIInfrastructure.GetMonthlyInfrastructureCosts(AICompany.COMPANY_SELF, AIInfrastructure.INFRASTRUCTURE_ROAD));
		Log.logWarning( "Monthly Rail infrastructure costs: " + AIInfrastructure.GetMonthlyInfrastructureCosts(AICompany.COMPANY_SELF, AIInfrastructure.INFRASTRUCTURE_RAIL));
		Log.logWarning( "Monthly Airport infrastructure costs: " + AIInfrastructure.GetMonthlyInfrastructureCosts(AICompany.COMPANY_SELF, AIInfrastructure.INFRASTRUCTURE_AIRPORT));
		Log.logWarning( "Monthly Station infrastructure costs: " + AIInfrastructure.GetMonthlyInfrastructureCosts(AICompany.COMPANY_SELF, AIInfrastructure.INFRASTRUCTURE_STATION));
		Log.logWarning( "------------------------------");
		*/
		
		local numberOfShips = 0;
		local shipPercentageErrors = [];
			
		local numberOfTrains = 0;
		local trainPercentageErrors = [];
			
		local numberOfTrucks = 0;
		local truckPercentageErrors = [];
			
		local numberOfAirplanes = 0;
		local airplanePercentageErrors = [];
			
		local counter = 0;
			
		Refinance();
		foreach (connection in connectionManager.allConnections) {
			connection.expectedAvgEarnings = null;
			connection.actualAvgEarnings = null;
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
					
					local cargoEngineID = null;
					if (connection.vehicleTypes == AIVehicle.VT_RAIL)
						cargoEngineID = AIVehicle.GetWagonEngineType(vehicle, 0);
					local travelTimeForward = connection.pathInfo.GetTravelTime(transportEngineID, cargoEngineID, true);
					local travelTimeBackward = connection.pathInfo.GetTravelTime(transportEngineID, cargoEngineID, false);
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
						// It seems a vehicle got added to the wrong group.
						Log.logError("vehicleCapacity == 0 for vehicle " + AIVehicle.GetName(vehicle) + ", cargo: " + AICargo.GetCargoLabel(connection.cargoID));
						Log.logError("Connection this belongs to: " + connection.ToString() + ", group: " + AIGroup.GetName(connection.vehicleGroupID));
						// Since we probably haven't fixed this yet just continue instead of crashing to improve the user experience.
						continue;
					}
					assert (vehicleCapacity > 0);
						
					// Calculate netto income per vehicle.
					local transportedCargoPerVehiclePerMonth = (Date.DAYS_PER_MONTH.tofloat() / travelTime) * vehicleCapacity;

					local distance = AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation());
					if (distance < 0) {
						// This could happen if from or to node (industry) disappears.
						Log.logError("Invalid distance: " + distance + ", From and/or To node probably invalid! " +
							AIVehicle.GetName(vehicle) + ", cargo: " + AICargo.GetCargoLabel(connection.cargoID));
						Log.logError("Connection this belongs to: " + connection.ToString() + ", group: " + AIGroup.GetName(connection.vehicleGroupID));
						continue;
					}
					local brutoIncomePerMonthPerVehicle = AICargo.GetCargoIncome(cargoIDTransported, distance, travelTimeForward.tointeger()) * transportedCargoPerVehiclePerMonth;

					// In case of a bilateral connection we take a pessimistic take on the amount of
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
					Log.logInfo("SHIP CONNECTION: " + percentageList);
				} else if (connection.vehicleTypes == AIVehicle.VT_RAIL) {
					++numberOfTrains;
					trainPercentageErrors.push(percentageError / numberOfVehicles);
					Log.logInfo("TRAIN CONNECTION: " + percentageList);
				} else if (connection.vehicleTypes == AIVehicle.VT_ROAD) {
					++numberOfTrucks;
					truckPercentageErrors.push(percentageError / numberOfVehicles);
					Log.logInfo("TRUCK CONNECTION: " + percentageList);
				} else if (connection.vehicleTypes == AIVehicle.VT_AIR) {
					++numberOfAirplanes;
					airplanePercentageErrors.push(percentageError / numberOfVehicles);
					Log.logInfo("AEROPLANE CONNECTION: " + percentageList);
				} else {
					assert (false);
				}
				
				local prospectedAverageEarnings = prospectedAvgEarnings / numberOfVehicles;
				local actualAverageEarnings = actualAvgEarnings / numberOfVehicles;
				connection.expectedAvgEarnings = prospectedAverageEarnings;
				connection.actualAvgEarnings = actualAverageEarnings;
				local infoString = "Prospected avg earnings: " + prospectedAverageEarnings + ", actual avg earnings: " + actualAverageEarnings +
					" for connection " + connection.ToString();
				// Show the info as a Warning in case of negative earnings or when earnings are less than a third of what we expected.
				if (actualAverageEarnings < 0 || actualAverageEarnings * 3 < prospectedAverageEarnings)
					Log.logWarning(infoString);
				else
					Log.logInfo(infoString);
			}
		}
		
		Log.logWarning(counter + " vehicles inspected.");
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
		Refinance();
		Log.logWarning("Planner: Schedule and Execute");
		planner.ScheduleAndExecute();
		// Get all reports from our advisors.
		local reports = [];
		Log.logWarning("Get reports from advisors");
		foreach (advisor in advisors) {
			reports.extend(advisor.GetReports());
		}
		Refinance();
		// Let the parlement decide on these reports and execute them!
		parlement.ClearReports();
		
		// Process all the events which have been fired in the mean time.
		Log.logWarning("Process World Events");
		worldEventManager.ProcessEvents();
		
		// Update all active connections and check if vehicles need to be sold / replaced, etc.
		Log.logWarning("Maintain Active connections");
		connectionManager.MaintainActiveConnections();
		
		
		Refinance();
		AICompany.SetAutoRenewMoney(5000000);
		Log.logWarning("Select reports");
		parlement.SelectReports(reports);
		
		Log.logWarning("Execute and Select reports");
		while (!parlement.ExecuteReports()) {
			parlement.SelectReports(reports);
		}

		Log.logWarning("Handle politics");
		la.HandlePolitics();
		
		Refinance();
		AICompany.SetAutoRenewMoney(1000000);
	}
}

function Refinance() {
	Finance.RepayLoan();
	Finance.CheckNegativeBalance();
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
function NoNoCAB::Stop() {
	this.stop = true;
	logInfo("Stopped.");
}
