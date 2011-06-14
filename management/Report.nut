/**
 * This class is the base class for all reports which can be constructed and
 * presented to the Parlement for selection and execution. A report consists 
 * of a list of actions which must be executed if this reports is selecte for
 * execution. 
 *
 * All reports in this framework calculate their Utility as the netto profit
 * per month times the actual number of months over which this netto profit 
 * is gained!
 */
class Report
{
	
	actions = null;                   // The list of actions.
	brutoIncomePerMonth = 0;          // The bruto income per month which is invariant of the number of vehicles.
	brutoCostPerMonth = 0;            // The bruto cost per month which is invariant of the number of vehicles.
	initialCost = 0;                  // Initial cost, which is only paid once!
	runningTimeBeforeReplacement = 0; // The running time in which profit can be made.
	
	brutoIncomePerMonthPerVehicle = 0; // The bruto income per month per vehicle.
	brutoCostPerMonthPerVehicle = 0;   // The bruto cost per month per vehicle.
	initialCostPerVehicle = 0;         // The initial cost per vehicle which is only paid once!
	nrVehicles = 0;                    // The total number of vehicles.
	nrWagonsPerVehicle = 0;            // The number of wagons per vehicle we'll build.
	transportEngineID = 0;             // The engine ID to transport the cargo.
	holdingEngineID = 0;               // The engine ID to hold the cargo to be transported.
	                                   
	fromConnectionNode = null;         // The node which produces the cargo.
	toConnectionNode = null;           // The node which accepts the produced cargo.
	isInvalid = null;                  // If an error is found during the construction this value is set to true.
	connection = null;                 // The proposed connection.
	cargoID = 0;                       // The cargo to transport.
	
	nrRoadStations = 0;                // The number of road stations which need to be build on each side.
	
	upgradeToRailType = 0;             // The rail type to upgrade an existing connection to (or null if not).
	loadingTime = 0;                   // The time it takes to load a vehicle.

	world = 0;
	
	/**
	 * Construct a connection report.
	 * @param world The world.
	 * @param travelFromNode The connection node the connection comes from (the producing side).
	 * @param travelToNode The connection node the connection goes to (the accepting side).
	 * @param transportEngineID The engine which is used (or will be used) for transporting the cargo.
	 * @param holdingEngineID The engine which is used (or will be used) for holding the cargo.
	 * @param cargoAlreadyTransported The cargo which is already transpored.
	 */
	constructor(world, travelFromNode, travelToNode, cargoID, transportEngineID, holdingEngineID, cargoAlreadyTransported) {

		this.world = world;
		this.transportEngineID = transportEngineID;
		this.holdingEngineID = holdingEngineID;
		toConnectionNode = travelToNode;
		fromConnectionNode = travelFromNode;
		this.cargoID = cargoID;
		isInvalid = false;
		upgradeToRailType = null;
		loadingTime = 0;
		
		// Check if the engine is valid.
		if (!AIEngine.IsBuildable(transportEngineID) || !AIEngine.IsBuildable(holdingEngineID) ||
			toConnectionNode.isInvalid || fromConnectionNode.isInvalid) {
			isInvalid = true;
			return;
		}
		// Calculate the travel times for the prospected engine ID.
		local maxSpeed = AIEngine.GetMaxSpeed(transportEngineID);
		
		// Get the distances (real or estimated).
		local travelTime;
		local travelTimeTo;
		local travelTimeFrom;
		connection = travelFromNode.GetConnection(travelToNode, cargoID);
		local distance = AIMap.DistanceManhattan(travelFromNode.GetLocation(), travelToNode.GetLocation());
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_ROAD) {
			if (connection != null && connection.pathInfo.roadList != null && connection.pathInfo.vehicleType == AIVehicle.VT_ROAD) {
				travelTimeTo = connection.pathInfo.GetTravelTime(transportEngineID, true);
				travelTimeFrom = connection.pathInfo.GetTravelTime(transportEngineID, false);

				if (!connection.pathInfo.build)
					initialCost = PathBuilder(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(transportEngineID), null).GetCostForRoad();
			} else {
				travelTimeTo = distance * Tile.straightRoadLength / maxSpeed;
				travelTimeFrom = travelTimeTo;
				initialCost = AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD) * distance * 3 +
				              AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_DEPOT) +
				              AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_TRUCK_STOP) * 2;
			}

			loadingTime = 0;
		} else if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_AIR) {

			// For air connections the distance travelled is different (shorter in general)
			// than road vehicles. A part of the tiles are traversed diagonal, we want to
			// capture this so we can make more precise predictions on the income per vehicle.
			local fromLoc = travelFromNode.GetLocation();
			local toLoc = travelToNode.GetLocation();
			local distanceX = AIMap.GetTileX(fromLoc) - AIMap.GetTileX(toLoc);
			local distanceY = AIMap.GetTileY(fromLoc) - AIMap.GetTileY(toLoc);

			if (distanceX < 0) distanceX = -distanceX;
			if (distanceY < 0) distanceY = -distanceY;

			local diagonalTiles;
			local straightTiles;

			if (distanceX < distanceY) {
				diagonalTiles = distanceX;
				straightTiles = distanceY - diagonalTiles;
			} else {
				diagonalTiles = distanceY;
				straightTiles = distanceX - diagonalTiles;
			}

			// Take the landing sequence in consideration.
			local realDistance = diagonalTiles * Tile.diagonalRoadLength + (straightTiles + 40) * Tile.straightRoadLength;

			travelTimeTo = realDistance / maxSpeed;
			travelTimeFrom = travelTimeTo;
			if (connection == null || !connection.pathInfo.build) {

				local isTowntoTown = travelFromNode.nodeType == ConnectionNode.TOWN_NODE && travelToNode.nodeType == ConnectionNode.TOWN_NODE;
				local costForFrom = BuildAirfieldAction.GetAirportCost(travelFromNode, cargoID, isTowntoTown ? true : false);
				local costForTo = BuildAirfieldAction.GetAirportCost(travelToNode, cargoID, true);

				if (costForFrom == -1 || costForTo == -1) {
					isInvalid = true;
					return;
				}
					
				initialCost = costForFrom + costForTo;
			}

			loadingTime = 20;
		} else if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_WATER) {

			if (connection != null && connection.pathInfo.roadList != null && connection.pathInfo.vehicleType == AIVehicle.VT_WATER) {
				travelTimeTo = WaterPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(transportEngineID), true);
				travelTimeFrom = travelTimeTo;
				initialCost = WaterPathBuilder(connection.pathInfo.roadList).GetCostForRoad();
			} else {
				travelTimeTo = distance * Tile.straightRoadLength / maxSpeed;
				travelTimeFrom = travelTimeTo;
			}

			if (connection == null || !connection.pathInfo.build)
				initialCost += BuildShipYardAction.GetCosts();

			loadingTime = 0;
		} else if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL) {
			if (connection != null && connection.pathInfo.roadList != null && connection.pathInfo.vehicleType == AIVehicle.VT_RAIL) {
				travelTimeTo = connection.pathInfo.GetTravelTime(transportEngineID, true);
				travelTimeFrom = connection.pathInfo.GetTravelTime(transportEngineID, false);

				if (!connection.pathInfo.build)
					initialCost = RailPathBuilder(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(transportEngineID), null).GetCostForRoad() * 2;
					
				//Log.logWarning("To get from " + travelFromNode.GetName() + " to " + travelToNode.GetName() + " takes " + travelTimeTo + " " + travelTimeFrom + " days...");
			} else {
				travelTimeTo = distance * Tile.straightRoadLength / maxSpeed;
				travelTimeFrom = travelTimeTo;
				local rail_type = TrainConnectionAdvisor.GetBestRailType(transportEngineID);
				assert (rail_type != AIRail.RAILTYPE_INVALID);
				initialCost = AIRail.GetBuildCost(rail_type, AIRail.BT_TRACK) * distance * 3 +
				              AIRail.GetBuildCost(rail_type, AIRail.BT_SIGNAL) * distance / 5 +
				              AIRail.GetBuildCost(rail_type, AIRail.BT_DEPOT) +
				              AIRail.GetBuildCost(rail_type, AIRail.BT_STATION) * 6 * 2;
			}

			loadingTime = 15;
		} else {
			Log.logError("Unknown vehicle type: " + AIEngine.GetVehicleType(transportEngineID));
			isInvalid = true;
			world.InitCargoTransportEngineIds();
		}
		travelTime = travelTimeTo + travelTimeFrom;

		// Calculate netto income per vehicle.
		local transportedCargoPerVehiclePerMonth = (World.DAYS_PER_MONTH.tofloat() / travelTime) * AIEngine.GetCapacity(holdingEngineID);
		
		// In case of trains, we have 5 wagons.
		nrWagonsPerVehicle = 5;
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL)
			transportedCargoPerVehiclePerMonth *= nrWagonsPerVehicle;
		
		
		// If we refit from passengers to mail, we devide the capacity by 2, to any other cargo type by 4.
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_AIR && AICargo.HasCargoClass(AIEngine.GetCargoType(holdingEngineID), AICargo.CC_PASSENGERS) && 
		    !AICargo.HasCargoClass(cargoID, AICargo.CC_PASSENGERS) && !AICargo.HasCargoClass(cargoID, AICargo.CC_MAIL)) {
			if (AICargo.GetTownEffect(cargoID) == AICargo.TE_GOODS)
				transportedCargoPerVehiclePerMonth *= 0.6;
			else
				transportedCargoPerVehiclePerMonth *= 0.3;
		}
		nrVehicles = (travelFromNode.GetProduction(cargoID) - cargoAlreadyTransported).tofloat() / transportedCargoPerVehiclePerMonth;

		if (nrVehicles > 0.75 && nrVehicles < 1 && (connection == null || connection.pathInfo.build))
			nrVehicles = 1;
		else
			nrVehicles = nrVehicles.tointeger();

		brutoIncomePerMonth = 0;
		brutoIncomePerMonthPerVehicle = AICargo.GetCargoIncome(cargoID, distance, travelTimeTo.tointeger()) * transportedCargoPerVehiclePerMonth;

		// In case of a bilateral connection we take a persimistic take on the amount of 
		// vehicles supported by this connection, but we do increase the income by adding
		// the expected income of the other connection to the total.
		if (connection != null && connection.bilateralConnection || travelToNode.nodeType == ConnectionNode.TOWN_NODE && travelFromNode.nodeType == ConnectionNode.TOWN_NODE) {
			// Also calculate the route in the other direction.
			local nrVehiclesOtherDirection = ((travelToNode.GetProduction(cargoID) - cargoAlreadyTransported) / transportedCargoPerVehiclePerMonth).tointeger();

			if (nrVehiclesOtherDirection < nrVehicles)
				nrVehicles = nrVehiclesOtherDirection;

			brutoIncomePerMonthPerVehicle += AICargo.GetCargoIncome(cargoID, distance, travelTimeFrom.tointeger()) * transportedCargoPerVehiclePerMonth;
		}

		// Calculate the maximum number of vehicles this line supports.
		if (loadingTime != 0) {
			local maxVehicles = min((travelTimeTo / loadingTime).tointeger(), (travelTimeFrom / loadingTime).tointeger()) * 2;
			if (nrVehicles > maxVehicles) {
				Log.logDebug("Dropped max nr. vehicles on line " + travelFromNode.GetName() + " " + travelToNode.GetName() + " from " + nrVehicles + " to " + maxVehicles + "{" + AICargo.GetCargoLabel(cargoID));
				nrVehicles = maxVehicles;
			
				if (nrVehicles == 0)
					nrVehicles = 1;
			}
		}


		brutoCostPerMonth = 0;
		brutoCostPerMonthPerVehicle = AIEngine.GetRunningCost(transportEngineID) / World.MONTHS_PER_YEAR;
		initialCostPerVehicle = AIEngine.GetPrice(transportEngineID);
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL) {
			initialCostPerVehicle += AIEngine.GetPrice(holdingEngineID) * nrWagonsPerVehicle;
			// Check if the current rail type of this connection is such that the new
			// train cannot run on it.
			if (connection != null && connection.pathInfo.build) {
				//local railTypeOfTrain = AIEngine.GetRailType(transportEngineID);
				local railTypeOfConnection = AIRail.GetRailType(connection.pathInfo.depot);
				local foundRailTrack = -1;
				local l = AIRailTypeList();
				foreach (railTypeOfTrain, index in l) {
					if (AIRail.IsRailTypeAvailable(railTypeOfTrain) && 
						AIEngine.CanRunOnRail(transportEngineID, railTypeOfTrain) &&
						AIEngine.HasPowerOnRail(transportEngineID, railTypeOfTrain) &&
						AIRail.GetMaxSpeed(railTypeOfTrain) > AIRail.GetMaxSpeed(foundRailTrack) &&
						(!AIRail.TrainCanRunOnRail(railTypeOfTrain, railTypeOfConnection) ||
						!AIRail.TrainHasPowerOnRail(railTypeOfTrain, railTypeOfConnection))) {
						foundRailTrack = railTypeOfTrain;
					}
				}
				
				// Make sure we do not DOWNgrade the existing connection.
				if (foundRailTrack > railTypeOfConnection) {
					initialCost += RailPathUpgradeAction.GetCostForUpgrade(connection, foundRailTrack);
					upgradeToRailType = foundRailTrack;
				}
				// Else, just build more trains :)
			}
		}
		runningTimeBeforeReplacement = AIEngine.GetMaxAge(transportEngineID);
	}
	
	function ToString() {
		return "Build a connection from " + fromConnectionNode.GetName() + " to " + toConnectionNode.GetName() +
		" transporting " + AICargo.GetCargoLabel(cargoID) + " and build " + nrVehicles + " " + AIEngine.GetName(transportEngineID) + ". Cost for the road: " +
		initialCost + ". Cost pm/v: " + brutoCostPerMonthPerVehicle + ". Income pm/v: " + brutoIncomePerMonthPerVehicle + " " + Utility();
	}

	function NettoIncomePerMonthForMoney(money, forecast) {
		
		local oldNrVehicles = nrVehicles;
		if (GetNrVehicles(money, 0) == 0)
			nrVehicles = 0;
		else
			nrVehicles = GetNrVehicles(money, forecast);

		local maxBuildableVehicles = GameSettings.GetMaxBuildableVehicles(AIEngine.GetVehicleType(transportEngineID));
		if (nrVehicles > maxBuildableVehicles)
			nrVehicles = maxBuildableVehicles;
		
		local nettoIncome = NettoIncomePerMonth();
		
		nrVehicles = oldNrVehicles;
		return nettoIncome;
	}
	
	function NettoIncomePerMonth() {
		local maxBuildableVehicles = GameSettings.GetMaxBuildableVehicles(AIEngine.GetVehicleType(transportEngineID));
		if (nrVehicles > maxBuildableVehicles)
			nrVehicles = maxBuildableVehicles;

		if (nrVehicles == 0)
			return 0;
			
		local totalBrutoIncomePerMonth = brutoIncomePerMonth + (nrVehicles < 0 ? 0 : nrVehicles * brutoIncomePerMonthPerVehicle);
		
		// Check if the connection is subsidised.
		if (Subsidy.IsSubsidised(fromConnectionNode, toConnectionNode, cargoID))
			totalBrutoIncomePerMonth *= GameSettings.GetSubsidyMultiplier();

		local totalBrutoCostPerMonth = brutoCostPerMonth + (nrVehicles < 0 ? 0 : nrVehicles * brutoCostPerMonthPerVehicle);

		if (runningTimeBeforeReplacement == 0)
			return 0;
		
		return totalBrutoIncomePerMonth - totalBrutoCostPerMonth;
	}
	
	/**
	 * The utility for a report is the netto profit per month times
 	 * the actual number of months over which this netto profit is 
 	 * gained!
	 */
	function Utility() {
		local vehicleType = AIEngine.GetVehicleType(transportEngineID);
		if (vehicleType == AIVehicle.VT_INVALID)
			return 0;

		// Check how much this distances is from the 'optimal' distance.
		local optimalDistance = world.optimalDistances[vehicleType][cargoID];
		local distance = AIMap.DistanceManhattan(fromConnectionNode.GetLocation(), toConnectionNode.GetLocation());

		local optimalIncome = GetIncomePerVehicle(optimalDistance).tointeger();
		local income = GetIncomePerVehicle(distance).tointeger();
		local delta = min(optimalIncome, income).tofloat() / max(optimalIncome, income).tofloat();

		local nettoIncome = NettoIncomePerMonth();
		return nettoIncome * delta;
	}

	function GetIncomePerVehicle(distance) {

		if (connection != null && connection.pathInfo.build)
			return 1;

		local capacity = AIEngine.GetCapacity(holdingEngineID);
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL)
			capacity *= 5;
		local travel_time = distance * Tile.straightRoadLength / AIEngine.GetMaxSpeed(transportEngineID);
		local income = AICargo.GetCargoIncome(cargoID, distance, travel_time.tointeger()) * capacity;
		local costs = AIEngine.GetRunningCost(transportEngineID) / World.DAYS_PER_YEAR * travel_time;

		income -= costs;

		income /= distance;
		return income;
	}
	
	/**
	 * This utility function is called by the parlement to check what the utility is
	 * if the money available is restricted to 'money' and we take into account the
	 * maximum number of vehicles which can be build.
	 * @param The money to spend, if this value is -1 we have unlimited money to spend.
	 * @return the net income per month for the money to spend.
	 */
	function UtilityForMoney(money) {
		if (money == -1)
			return Utility();

		// Now calculate the new utility based on the number of vehicles we can buy.
		local oldNrVehicles = nrVehicles;
		if (GetNrVehicles(money, 0) == 0)
			nrVehicles = 0;
		else
			nrVehicles = GetNrVehicles(money, 24);

		local maxBuildableVehicles = GameSettings.GetMaxBuildableVehicles(AIEngine.GetVehicleType(transportEngineID));
		if (nrVehicles > maxBuildableVehicles)
			nrVehicles = maxBuildableVehicles;
		local utility = Utility();
		
		// Restore values.
		nrVehicles = oldNrVehicles;
		
		// Return the utility;
		return utility;
	}
	
	/**
	 * Get the number of vehicles we can buy given the amount of money.
	 * @param money The money to spend, if this value is -1 we have unlimited money to spend.
	 * @forcast The number of months we want to look ahead. If we construct the construction now,
	 * how many vehicles will we be able to produce in the future? This only applies to unbuild
	 * connections.
	 * @return The maximum number of vehicles we can buy for this money.
	 */
	function GetNrVehicles(money, forcast) {
		if (nrVehicles < 0)
			return nrVehicles;
		money -= initialCost;

		// For the remainder of the money calculate the number of vehicles we could buy.
		if (initialCostPerVehicle == 0)
			return nrVehicles;
		local vehiclesToBuy = (money / initialCostPerVehicle).tointeger();

		// Add the revenue we make on the first month to this number.
		if (connection == null || !connection.pathInfo.build) {
			local revenue = (brutoIncomePerMonthPerVehicle - brutoCostPerMonthPerVehicle) * forcast * vehiclesToBuy;
			local extraVehiclesToBuy = (revenue / initialCostPerVehicle).tointeger();
			vehiclesToBuy += extraVehiclesToBuy;
		}
			
		if (vehiclesToBuy > nrVehicles)
			vehiclesToBuy = nrVehicles;

		return vehiclesToBuy;
	}
	
	/**
	 * Get the cost for executing this report given a certain amount of money.
	 * @param money The money to spend, if this value is -1 we have unlimited money to spend.
	 * @return The cost for executing this report given the amount of money.
	 */
	function GetCost(money) {
		if (money == -1) 
			return initialCost + initialCostPerVehicle * nrVehicles;
			
		local maxNrVehicles = GetNrVehicles(money, 0);
		return initialCost + initialCostPerVehicle * maxNrVehicles;
	}
	
/*	function ToString() {
		return "Bruto income: " + brutoIncomePerMonth + "; BrutoCost: " + brutoCostPerMonth + "; Running time: " + runningTimeBeforeReplacement + "; Init cost: " + initialCost + ".";
	}*/
}
