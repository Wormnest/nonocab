class ConnectionReport extends Report {

	fromConnectionNode = null;	// The node which produces the cargo.
	toConnectionNode = null;	// The node which accepts the produced cargo.
	connection = null;		// The proposed connection.
	isInvalid = null;		// If an error is found during the construction this value is set to true.
	
	cargoID = 0;			// The cargo to transport.
	
	nrRoadStations = 0;		// The number of road stations which need to be build on each side.

	/**
	 * Construct a connection report.
	 * @param world The world.
	 * @param travelFromNode The connection node the connection comes from (the producing side).
	 * @param travelToNode The connection node the connection goes to (the accepting side).
	 * @param engineID The engine which is used (or will be used) for the connection.
	 * @param cargoAlreadyTransported The cargo which is already transpored.
	 */
	constructor(world, travelFromNode, travelToNode, cargoID, engineID, cargoAlreadyTransported) {

		this.engineID = engineID;
		toConnectionNode = travelToNode;
		fromConnectionNode = travelFromNode;
		this.cargoID = cargoID;
		isInvalid = false;
		
		// Calculate the travel times for the prospected engine ID.
		local maxSpeed = AIEngine.GetMaxSpeed(engineID);
		
		// Get the distances (real or estimated).
		local travelTime;
		local travelTimeTo;
		local travelTimeFrom;
		connection = travelFromNode.GetConnection(travelToNode, cargoID);
		local distance = AIMap.DistanceManhattan(travelFromNode.GetLocation(), travelToNode.GetLocation());
		
		if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_ROAD) {
			if (connection != null && connection.pathInfo.roadList != null) {
				travelTimeTo = connection.pathInfo.GetTravelTime(engineID, true);
				travelTimeFrom = connection.pathInfo.GetTravelTime(engineID, false);

				if (!connection.pathInfo.build)
					initialCost = PathBuilder.GetCostForRoad(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID));
			} else {
				travelTimeTo = distance * Tile.straightRoadLength / maxSpeed;
				travelTimeFrom = travelTimeTo;
				initialCost = 150 * distance;
			}
		} else if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_AIR) {

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

				local useCache = connection == null || !connection.forceReplan;
				local costForFrom = BuildAirfieldAction.GetAirportCost(travelFromNode, cargoID, false, useCache);
				local costForTo = BuildAirfieldAction.GetAirportCost(travelToNode, cargoID, true, useCache);

				if (costForFrom == -1 || costForTo == -1)
					isInvalid = true;
					
				initialCost = costForFrom + costForTo;
			}
		} else if (AIEngine.GetVehicleType(engineID) == AIVehicle.VT_WATER) {

			if (connection != null && connection.pathInfo.roadList != null) {
				travelTimeTo = WaterPathFinderHelper.GetTime(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(engineID), true);
				travelTimeFrom = travelTimeTo;
				initialCost = WaterPathBuilder.GetCostForRoad(connection.pathInfo.roadList);
			} else {
				travelTimeTo = distance * Tile.straightRoadLength / maxSpeed;
				travelTimeFrom = travelTimeTo;
			}

			if (connection == null || !connection.pathInfo.build) {

				local useCache = connection == null || !connection.forceReplan;
				local costForFrom = BuildShipYardAction.GetShipYardCost(travelFromNode, cargoID, false, useCache);
				local costForTo = BuildShipYardAction.GetShipYardCost(travelToNode, cargoID, true, useCache);

				if (costForFrom == -1 || costForTo == -1)
					isInvalid = true;
					
				
				initialCost += costForFrom + costForTo;
			}
		}
		travelTime = travelTimeTo + travelTimeFrom;

		// Calculate netto income per vehicle.
		local transportedCargoPerVehiclePerMonth = (World.DAYS_PER_MONTH.tofloat() / travelTime) * AIEngine.GetCapacity(engineID);
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
		brutoCostPerMonthPerVehicle = World.DAYS_PER_MONTH * AIEngine.GetRunningCost(engineID) / World.DAYS_PER_YEAR;
		initialCostPerVehicle = AIEngine.GetPrice(engineID);
		runningTimeBeforeReplacement = World.MONTHS_BEFORE_AUTORENEW;
	}
	
	function ToString() {
		return "Build a connection from " + fromConnectionNode.GetName() + " to " + toConnectionNode.GetName() +
		" transporting " + AICargo.GetCargoLabel(cargoID) + " and build " + nrVehicles + " " + AIEngine.GetName(engineID) + ". Cost for the road: " +
		initialCost + ".";
	}
}
