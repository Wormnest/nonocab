class ConnectionReport extends Report {

	profitPerMonthPerVehicle = 0;	// The utility value.
	engineID = 0;					// The vehicles to build.
	nrVehicles = 0;					// The number of vehicles to build.
	roadList = null;				// The road to build.

	fromConnectionNode = null;	// The node which produces the cargo.
	toConnectionNode = null;	// The node which accepts the produced cargo.
	
	cargoID = 0;			// The cargo to transport.
	costForRoad = 0;		// The cost to build the road.
	costPerVehicle = 0;		// The cost per vehicle.
	
	nrRoadStations = 0;	// The number of road stations which need to be build on each side.
	
	/**
	 * Get the maximum vehicles which this connection supports.
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
			costForRoad = PathBuilder.GetCostForRoad(connection.pathInfo.roadList);
		} else { 
			travelTime = 2 * (manhattanDistance * RoadPathFinding.straightRoadLength / maxSpeed);
			costForRoad = 500 * manhattanDistance;
		}
			
		// Calculate netto income per vehicle.
		local incomePerRun = AICargo.GetCargoIncome(cargoID, manhattanDistance, travelTime.tointeger()) * AIEngine.GetCapacity(world.cargoTransportEngineIds[cargoID]);
		local transportedCargoPerVehiclePerMonth = (World.DAYS_PER_MONTH / travelTime) * AIEngine.GetCapacity(engineID);
		local incomePerVehicle = incomePerRun - ((travelTime) * (AIEngine.GetRunningCost(engineID) / World.DAYS_PER_YEAR));
		local maxNrVehicles = (1 + ((AIIndustry.GetProduction(travelFromNode.id, cargoID) - cargoAlreadyTransported) / transportedCargoPerVehiclePerMonth)).tointeger();

		profitPerMonthPerVehicle = (World.DAYS_PER_MONTH / travelTime) * incomePerRun;
		
		nrVehicles = maxNrVehicles;
		costPerVehicle = AIEngine.GetPrice(engineID);		
	}	

	/**
	 * Get the utility function, this is the total profit generated before the vehicles
	 * are autorenewed.
	 */
	function Utility() {
		local initialCost = costForRoad + costPerVehicle * nrVehicles;
		local profitPerMonth = profitPerMonthPerVehicle * nrVehicles;
		local timeToBreakPoint = initialCost / profitPerMonth;
		
		local netProfit = (World.MONTHS_BEFORE_AUTORENEW - timeToBreakPoint) * profitPerMonth;
		local netProfitPerMonth = netProfit / World.MONTHS_BEFORE_AUTORENEW;
	//	Log.logInfo("Report details:");
	//	Print(); 
	//	Log.logInfo("Initial cost: " + initialCost + "; profit per month: " + profitPerMonth + "; timeToBreakPoint: " + timeToBreakPoint + "; net profit: " + netProfit + ";  net profit per month: " + netProfitPerMonth);
		return netProfitPerMonth;
		
		//return profitPerMonthPerVehicle * nrVehicles / initialCost;
	}
	
	function Profit() {
		return Utility();
		//return profitPerMonthPerVehicle * nrVehicles;
	}
	
	function Print() {
		Log.logDebug(ToString());
	}
	
	function ToString() {
		return "Build a road from " + fromConnectionNode.GetName() + " to " + toConnectionNode.GetName() +
		" transporting " + AICargo.GetCargoLabel(cargoID) + " and build " + nrVehicles + " vehicles. Cost for the road: " +
		costForRoad + " income per month per vehicle: " + profitPerMonthPerVehicle;
	}
}
