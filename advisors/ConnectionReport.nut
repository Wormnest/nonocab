class ConnectionReport extends Report {

	engineID = 0;			// The vehicles to build.

	fromConnectionNode = null;	// The node which produces the cargo.
	toConnectionNode = null;	// The node which accepts the produced cargo.
	connection = null;		// The proposed connection.
	
	cargoID = 0;			// The cargo to transport.
	
	nrRoadStations = 0;	// The number of road stations which need to be build on each side.
	
	/**
	 * Construct a connection report.
	 * @param world The world.
	 * @param travelFromNode The connection node the connection comes from (the producing side).
	 * @param travelToNode The connection node the connection goes to (the accepting side).
	 * @param engineID The engine which is used (or will be used) for the connection.
	 * @param cargoAlreadyTransported The cargo which is already transpored.
	 * @return The number of vehicles of that type which can be 
	 */
	constructor(world, travelFromNode, travelToNode, cargoID, engineID, cargoAlreadyTransported) {

		this.engineID = engineID;
		toConnectionNode = travelToNode;
		fromConnectionNode = travelFromNode;
		this.cargoID = cargoID;
		
		// Calculate the travel times for the prospected engine ID.
		local maxSpeed = AIEngine.GetMaxSpeed(engineID);
		
		// Get the distances (real or guessed).
		local travelTime;
		local travelTimeTo;
		local travelTimeFrom;
		connection = travelFromNode.GetConnection(travelToNode, cargoID);
		local manhattanDistance = AIMap.DistanceManhattan(travelFromNode.GetLocation(), travelToNode.GetLocation());
		
		if (connection != null && connection.pathInfo.roadList != null) {
			travelTimeTo = connection.pathInfo.GetTravelTime(maxSpeed, true);
			travelTimeFrom = connection.pathInfo.GetTravelTime(maxSpeed, false);
			initialCost = PathBuilder.GetCostForRoad(connection.pathInfo.roadList);
		} else { 
			travelTimeTo = manhattanDistance * RoadPathFinding.straightRoadLength / maxSpeed;
			travelTimeFrom = manhattanDistance * RoadPathFinding.straightRoadLength / maxSpeed;
			initialCost = 150 * manhattanDistance;
		}
		travelTime = travelTimeTo + travelTimeFrom;

		// Calculate netto income per vehicle.
		local transportedCargoPerVehiclePerMonth = (World.DAYS_PER_MONTH / travelTime) * AIEngine.GetCapacity(engineID);
		nrVehicles = ((travelFromNode.GetProduction(cargoID) - cargoAlreadyTransported) / transportedCargoPerVehiclePerMonth).tointeger();

		brutoIncomePerMonth = 0;
		brutoIncomePerMonthPerVehicle = AICargo.GetCargoIncome(cargoID, manhattanDistance, travelTimeTo.tointeger()) * transportedCargoPerVehiclePerMonth;

		if (connection != null && connection.bilateralConnection || travelToNode.nodeType == ConnectionNode.TOWN_NODE && travelFromNode.nodeType == ConnectionNode.TOWN_NODE) {
			// Also calculate the route in the other direction.
			local nrVehiclesOtherDirection = ((travelToNode.GetProduction(cargoID) - cargoAlreadyTransported) / transportedCargoPerVehiclePerMonth).tointeger();

			if (nrVehiclesOtherDirection > nrVehicles)
				nrVehicles = nrVehiclesOtherDirection;
			brutoIncomePerMonthPerVehicle += AICargo.GetCargoIncome(cargoID, manhattanDistance, travelTimeFrom.tointeger()) * transportedCargoPerVehiclePerMonth;
		}

		brutoCostPerMonth = 0;
		brutoCostPerMonthPerVehicle = World.DAYS_PER_MONTH * AIEngine.GetRunningCost(engineID) / World.DAYS_PER_YEAR;
		initialCostPerVehicle = AIEngine.GetPrice(engineID);
		runningTimeBeforeReplacement = World.MONTHS_BEFORE_AUTORENEW;
	}
	
	function Print() {
		Log.logDebug(ToString());
	}
	
	function ToString() {
		return "Build a road from " + fromConnectionNode.GetName() + " to " + toConnectionNode.GetName() +
		" transporting " + AICargo.GetCargoLabel(cargoID) + " and build " + nrVehicles + " vehicles. Cost for the road: " +
		initialCost + ".";
	}
}
