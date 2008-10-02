class ConnectionReport extends Report {

	engineID = 0;					// The vehicles to build.
	roadList = null;				// The road to build.

	fromConnectionNode = null;	// The node which produces the cargo.
	toConnectionNode = null;	// The node which accepts the produced cargo.
	
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
		local connection = travelFromNode.GetConnection(travelToNode, cargoID);
		local manhattanDistance = AIMap.DistanceManhattan(travelFromNode.GetLocation(), travelToNode.GetLocation());
		
		if (connection != null) {
			travelTime = connection.pathInfo.GetTravelTime(maxSpeed, true) + connection.pathInfo.GetTravelTime(maxSpeed, false);
			roadList = connection.pathInfo.roadList;
			initialCost = PathBuilder.GetCostForRoad(connection.pathInfo.roadList);
		} else { 
			travelTime = 2 * (manhattanDistance * RoadPathFinding.straightRoadLength / maxSpeed);
			initialCost = 500 * manhattanDistance;
		}

		// Calculate netto income per vehicle.
		local transportedCargoPerVehiclePerMonth = (World.DAYS_PER_MONTH / travelTime) * AIEngine.GetCapacity(engineID);
		nrVehicles = ((AIIndustry.GetLastMonthProduction(travelFromNode.id, cargoID) - cargoAlreadyTransported) / transportedCargoPerVehiclePerMonth).tointeger();

		brutoIncomePerMonth = 0;
		brutoIncomePerMonthPerVehicle = AICargo.GetCargoIncome(cargoID, manhattanDistance, travelTime.tointeger()) * transportedCargoPerVehiclePerMonth;
		brutoCostPerMonth = 0;
		brutoCostPerMonthPerVehicle = World.DAYS_PER_MONTH * AIEngine.GetRunningCost(engineID) / World.DAYS_PER_YEAR;
		initialCostPerVehicle = AIEngine.GetPrice(engineID);
		runningTimeBeforeReplacement = World.MONTHS_BEFORE_AUTORENEW;
		
		/*
		// Calculate the number of road stations which need to be build
		local daysBetweenVehicles = ((timeToTravelTo + timeToTravelFrom) + 2 * 5) / maxNrVehicles.tofloat();
		local numberOfRoadStations = 5 / daysBetweenVehicles;
		if (numberOfRoadStations < 1) numberOfRoadStations = 1;
		else numberOfRoadStations = numberOfRoadStations.tointeger();*/	
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
