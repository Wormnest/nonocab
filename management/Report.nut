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
	transportEngineID = 0;             // The engine ID to transport the cargo.
	holdingEngineID = 0;               // The engine ID to hold the cargo to be transported.
	utilityForMoneyNrVehicles = 0;     // After a call to 'UtilityForMoney', the number of
	                                   // vehicles used for the utility function is stored
	                                   // in this parameter.
	                                   
	fromConnectionNode = null;         // The node which produces the cargo.
	toConnectionNode = null;           // The node which accepts the produced cargo.
	isInvalid = null;                  // If an error is found during the construction this value is set to true.
	connection = null;                 // The proposed connection.
	cargoID = 0;                       // The cargo to transport.
	
	nrRoadStations = 0;                // The number of road stations which need to be build on each side.
	
	oldReport = null;

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

		this.transportEngineID = transportEngineID;
		this.holdingEngineID = holdingEngineID;
		toConnectionNode = travelToNode;
		fromConnectionNode = travelFromNode;
		this.cargoID = cargoID;
		isInvalid = false;
		
		// Check if the engine is valid.
		if (!AIEngine.IsValidEngine(transportEngineID) || !AIEngine.IsValidEngine(holdingEngineID) ||
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
				initialCost = 150 * distance;
			}
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
		} else if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_WATER) {

			if (connection != null && connection.pathInfo.roadList != null && connection.pathInfo.vehicleType == AIVehicle.VT_WATER) {
				travelTimeTo = WaterPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(transportEngineID), true);
				travelTimeFrom = travelTimeTo;
				initialCost = WaterPathBuilder(connection.pathInfo.roadList).GetCostForRoad();
			} else {
				travelTimeTo = distance * Tile.straightRoadLength / maxSpeed;
				travelTimeFrom = travelTimeTo;
			}

			if (connection == null || !connection.pathInfo.build) {

				local useCache = connection == null || !connection.forceReplan;
				local costForFrom = BuildShipYardAction.GetShipYardCost(travelFromNode, cargoID, false, useCache);
				local costForTo = BuildShipYardAction.GetShipYardCost(travelToNode, cargoID, true, useCache);

				if (costForFrom == -1 || costForTo == -1) {
					isInvalid = true;
					return;
				}	
				
				initialCost += costForFrom + costForTo;
			}
		} else if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL) {
			if (connection != null && connection.pathInfo.roadList != null && connection.pathInfo.vehicleType == AIVehicle.VT_RAIL) {
				travelTimeTo = connection.pathInfo.GetTravelTime(transportEngineID, true);
				travelTimeFrom = connection.pathInfo.GetTravelTime(transportEngineID, false);

				if (!connection.pathInfo.build)
					initialCost = RailPathBuilder(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(transportEngineID), null).GetCostForRoad() * 2.5;
			} else {
				travelTimeTo = distance * Tile.straightRoadLength / maxSpeed;
				travelTimeFrom = travelTimeTo;
				initialCost = 150 * distance * 2.5;
			}
		} else {
			Log.logError("Unknown vehicle type: " + AIEngine.GetVehicleType(transportEngineID));
			isInvalid = true;
			world.InitCargoTransportEngineIds();
		}
		travelTime = travelTimeTo + travelTimeFrom;

		// Calculate netto income per vehicle.
		local transportedCargoPerVehiclePerMonth = (World.DAYS_PER_MONTH.tofloat() / travelTime) * AIEngine.GetCapacity(holdingEngineID);
		
		// In case of trains, we have 3 wagons.
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL)
			transportedCargoPerVehiclePerMonth *= 3;
		
		
		// If we refit from passengers to mail, we devide the capacity by 2, to any other cargo type by 4.
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_AIR && AICargo.HasCargoClass(AIEngine.GetCargoType(holdingEngineID), AICargo.CC_PASSENGERS) && 
		    !AICargo.HasCargoClass(cargoID, AICargo.CC_PASSENGERS) && !AICargo.HasCargoClass(cargoID, AICargo.CC_MAIL)) {
			if (AICargo.GetTownEffect(cargoID) == AICargo.TE_GOODS)
				transportedCargoPerVehiclePerMonth *= 0.6;
			else
				transportedCargoPerVehiclePerMonth *= 0.3;
		}
		nrVehicles = (travelFromNode.GetProduction(cargoID) - cargoAlreadyTransported).tofloat() / transportedCargoPerVehiclePerMonth;

		if (nrVehicles > 0.5 && nrVehicles < 1)
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

		brutoCostPerMonth = 0;
		brutoCostPerMonthPerVehicle = World.DAYS_PER_MONTH * AIEngine.GetRunningCost(transportEngineID) / World.DAYS_PER_YEAR;
		initialCostPerVehicle = AIEngine.GetPrice(transportEngineID);
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL)
			initialCostPerVehicle = AIEngine.GetPrice(holdingEngineID) * 3;
		runningTimeBeforeReplacement = World.MONTHS_BEFORE_AUTORENEW;
	}
	
	function ToString() {
		return "Build a connection from " + fromConnectionNode.GetName() + " to " + toConnectionNode.GetName() +
		" transporting " + AICargo.GetCargoLabel(cargoID) + " and build " + nrVehicles + " " + AIEngine.GetName(transportEngineID) + ". Cost for the road: " +
		initialCost + ".";
	}
	
	/**
	 * The utility for a report is the netto profit per month times
 	 * the actual number of months over which this netto profit is 
 	 * gained!
	 */
	function Utility() {
		local totalBrutoIncomePerMonth = brutoIncomePerMonth + (nrVehicles < 0 ? 0 : nrVehicles * brutoIncomePerMonthPerVehicle);
		
		// Check if the connection is subsidised.
		if (Subsidy.IsSubsidised(fromConnectionNode, toConnectionNode, cargoID))
			totalBrutoIncomePerMonth *= GameSettings.GetSubsidyMultiplier();
		
		local totalBrutoCostPerMonth = brutoCostPerMonth + (nrVehicles < 0 ? 0 : nrVehicles * brutoCostPerMonthPerVehicle);
		local totalInitialCost = initialCost + nrVehicles * initialCostPerVehicle;
		local returnValue = (totalBrutoIncomePerMonth - totalBrutoCostPerMonth) * runningTimeBeforeReplacement - totalInitialCost;
		
		if (oldReport != null)
			returnValue -= oldReport.Utility(); 
		return returnValue;
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
		nrVehicles = GetNrVehicles(money);

		local maxBuildableVehicles = GameSettings.GetMaxBuildableVehicles(AIEngine.GetVehicleType(transportEngineID));
		if (nrVehicles > maxBuildableVehicles)
			nrVehicles = maxBuildableVehicles;
		local utility = Utility();
		
		// Restore values.
		utilityForMoneyNrVehicles = nrVehicles;
		nrVehicles = oldNrVehicles;
		
		// Return the utility;
		return utility;
	}
	
	/**
	 * Get the number of vehicles we can buy given the amount of money.
	 * @param money The money to spend, if this value is -1 we have unlimited money to spend.
	 * @return The maximum number of vehicles we can buy for this money.
	 */
	function GetNrVehicles(money) {
		if (nrVehicles < 0)
			return nrVehicles;
		money -= initialCost;
		

		// For the remainder of the money calculate the number of vehicles we could buy.
		if (initialCostPerVehicle == 0)
			return nrVehicles;
		local vehiclesToBuy = (money / initialCostPerVehicle).tointeger();
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
			
		local maxNrVehicles = GetNrVehicles(money);
		return initialCost + initialCostPerVehicle * maxNrVehicles;
	}
	
/*	function ToString() {
		return "Bruto income: " + brutoIncomePerMonth + "; BrutoCost: " + brutoCostPerMonth + "; Running time: " + runningTimeBeforeReplacement + "; Init cost: " + initialCost + ".";
	}*/
}
