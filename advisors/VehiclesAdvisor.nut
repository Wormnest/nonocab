/**
 * This class is responsible of maintaining already build exising by
 * advising to sell or buy vehicles.
 */
class VehiclesAdvisor extends Advisor {

	connections = null;					// The table of connections to manage.
	reports = null;
	
	constructor(world) {
		Advisor.constructor(world);
		connections = {};
		reports = [];
	}
	
	/**
	 * Add a connection to the list of connections to check.
	 * @param connection The new connection to check.
	 * @param callingObject The object which made the call, this can't be the thread itself!!!
	 */
	function AddConnection(connection, callingObject);
	
	/**
	 * Check already build connections and sell / buy vehicles where needed.
	 */
	function getReports();	
}

/**
 * Get the number of vehicles waiting in front of road stations, in the road stations
 * and if a connection has any vehicles at all.
 * @param stationLocation The station to check out.
 * @param connection The connection this station is part of.
 * @return A tuple containing: 
 * - The number of vehicles waiting in or in front of the station multiplied by -1.
 * - The number of vehicles which are waiting and in the road station or depot; this > -nrVehicles.
 * - A boolean which denotes if any vehicles are detected for this connection.
 */
function VehiclesAdvisor::GetVehiclesWaiting(stationLocation, connection) {

		local nrVehicles = 0;
		local nrVehiclesInStation = 0;
		local hasVehicles = false;
		local isAir = false;
			
		// Check if there are any vehicles waiting on this tile and if so, sell them!
		foreach (vehicleGroup in connection.vehiclesOperating) {
			foreach (vehicleID in vehicleGroup.vehicleIDs) {
				hasVehicles = true;

				if (!isAir && AIVehicle.GetVehicleType(vehicleID) == AIVehicle.VEHICLE_AIR)
					isAir = true;

				if (AIMap().DistanceManhattan(AIVehicle().GetLocation(vehicleID), stationLocation) > 0 && 
					AIMap().DistanceManhattan(AIVehicle().GetLocation(vehicleID), stationLocation) < (isAir ? 30 : 15) &&
					(AIVehicle().GetCurrentSpeed(vehicleID) < 10 || isAir) &&
					AIVehicle.GetState(vehicleID) == AIVehicle.VS_RUNNING &&
					AIOrder().GetOrderDestination(vehicleID, AIOrder().CURRENT_ORDER) == stationLocation) {
					nrVehicles--;
					
					if (AITile.IsStationTile(AIVehicle.GetLocation(vehicleID)))
						nrVehiclesInStation++;
				}
			}
		}

		if (isAir && nrVehicles > -2)
			nrVehicles = 0;
		
		return [nrVehicles, nrVehiclesInStation, hasVehicles];
}

function VehiclesAdvisor::Update(loopCounter) {
	
	if (loopCounter == 0) {
		connections = [];
		UpdateIndustryConnections(world.industry_tree);
	}
	reports = [];

	foreach (connection in connections) {

		// If the road isn't build we can't micro manage, move on!		
		if (!connection.pathInfo.build) 
			continue;

		// Make sure we don't update a connection to often!
		local currentDate = AIDate.GetCurrentDate();
		if (Date().GetDaysBetween(connection.lastChecked, currentDate) < 15)
			continue;
		
		connection.lastChecked = currentDate;
		local report = connection.CompileReport(world, world.cargoTransportEngineIds[connection.vehicleTypes][connection.cargoID]);
		report.nrVehicles = 0;
		
		local stationDetails = GetVehiclesWaiting(AIStation().GetLocation(connection.travelFromNodeStationID), connection);
		report.nrVehicles = stationDetails[0];
		local nrVehiclesInStation = stationDetails[1];
		local hasVehicles = stationDetails[2];
		local dropoffOverLoad = false;

		local stationOtherDetails = GetVehiclesWaiting(AIStation().GetLocation(connection.travelToNodeStationID), connection);
			
		// If the other station has more vehicles, check that station.
		if (stationOtherDetails[0] < report.nrVehicles) {
			report.nrVehicles = stationOtherDetails[0];
			nrVehiclesInStation = stationOtherDetails[1];
			hasVehicles = stationOtherDetails[2];

			if (!connection.bilateralConnection)
				dropoffOverLoad = true;
		}
		
		// If we have multiple stations we want to take this into account. Each station
		// is allowed to have 1 vehicle waiting in them. So we subtract the number of
		// road stations from the number of vehicles waiting.
		if (connection.pathInfo.nrRoadStations < nrVehiclesInStation)
			report.nrVehicles += nrVehiclesInStation - connection.pathInfo.nrRoadStations;

		// Now we check whether we need more vehicles
		local production = AIStation.GetCargoWaiting(connection.travelFromNodeStationID, connection.cargoID);
		local rating = AIStation().GetCargoRating(connection.travelFromNodeStationID, connection.cargoID);

		if (connection.bilateralConnection) {
			local productionOtherEnd = AIStation.GetCargoWaiting(connection.travelToNodeStationID, connection.cargoID);
			local ratingOtherEnd = AIStation().GetCargoRating(connection.travelToNodeStationID, connection.cargoID);

			if (productionOtherEnd < production)
				production = productionOtherEnd;
			if (ratingOtherEnd > rating)
				rating = ratingOtherEnd;
		}

		if (!hasVehicles || rating < 60 || production > 100 || dropoffOverLoad) {
			
			// If we have a line of vehicles waiting we also want to buy another station to spread the load.
			if (report.nrVehicles < 0)
				// build additional station...
				report.nrRoadStations = 2;

			if (production < 200) 
				report.nrVehicles = 1;
			else if (production < 300)
				report.nrVehicles = 2;
			else if (production < 400)
				report.nrVehicles = 3;
			else
				report.nrVehicles = 4;
		} 
		
		// If we want to sell vehicle but the road isn't old enough, don't!
		else if (report.nrVehicles < 0 && Date.GetDaysBetween(AIDate.GetCurrentDate(), connection.pathInfo.buildDate) < 60)
			continue;

		// If we want to build vehicles make sure we can actually build them!
		if (report.nrVehicles > 0 && !GameSettings.GetMaxBuildableVehicles(AIEngine.GetVehicleType(report.engineID)))
			continue;

		if (report.nrVehicles != 0)
			reports.push(report);
	}
}

/**
 * Construct a report by finding the largest subset of buildable infrastructure given
 * the amount of money available to us, which in turn yields the largest income.
 */
function VehiclesAdvisor::GetReports() {
	
	// Use a binary heap to sort all reports.
	local connectionReports = BinaryHeap();
	foreach (report in reports)
		connectionReports.Insert(report, -report.Utility());
		
	local reportsToReturn = [];
	local report;
	
	while ((report = connectionReports.Pop()) != null) {
	
		// The industryConnectionNode gives us the actual connection.
		local connection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
			
		Log.logInfo("Report an update from: " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " with " + report.nrVehicles + " vehicles! Utility: " + report.Utility());
		local actionList = [];
						
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();

		if (report.nrRoadStations > 1) {
			if (connection.vehicleTypes == AIVehicle.VEHICLE_ROAD)
				actionList.push(BuildRoadAction(report.connection, false, true, world));
			else if (connection.vehicleTypes == AIVehicle.VEHICLE_AIR)
				actionList.push(BuildAirfieldAction(report.connection, world));
		}
		
		// Buy only half of the vehicles needed, build the rest gradualy.
		if (report.nrVehicles > 0) {
			// If we want to buy aircrafts, make sure the airports are of the correct type!
			// Big airplanes have a 5% chance to crash, so we want to avoid that!
			if (AIEngine.GetVehicleType(report.engineID) == AIVehicle.VEHICLE_AIR && 
				AIEngine.GetPlaneType(report.engineID) == AIAirport.PT_BIG_PLANE &&
				(AIAirport.GetAirportType(connection.pathInfo.roadList[0].tile) == AIAirport.AT_SMALL ||
				AIAirport.GetAirportType(connection.pathInfo.roadList[0].tile) == AIAirport.AT_COMMUTER))
				
				actionList.push(BuildAirfieldAction(report.connection, world));
			vehicleAction.BuyVehicles(report.engineID, report.nrVehicles, connection);
		}
		else if(report.nrVehicles < 0)
			vehicleAction.SellVehicles(report.engineID, -report.nrVehicles, connection);

		actionList.push(vehicleAction);

		report.actions = actionList;

		// Create a report and store it!
		reportsToReturn.push(report);
	}
	
	return reportsToReturn;
}

function VehiclesAdvisor::UpdateIndustryConnections(industry_tree) {

	// Upon initialisation we look at all possible connections in the world and try to
	// find the most prommising once in terms of cost to build to profit ratio. We can't
	// however get perfect information by calculating all possible routes as that will take
	// us way to much time.
	//
	// Therefore we try to get an indication by taking the Manhattan distance between two
	// industries and see what the profit would be if we would be able to build a straight
	// road and let and vehicle operate on it.
	//
	// The next step would be to look at the most prommising connection nodes and do some
	// actual pathfinding on that selection to find the best one(s).
	local industriesToCheck = {};
	foreach (primIndustryConnectionNode in industry_tree) {

		foreach (secondConnectionNode in primIndustryConnectionNode.connectionNodeList) {

			local manhattanDistance = AIMap.DistanceManhattan(primIndustryConnectionNode.GetLocation(), secondConnectionNode.GetLocation());
	
			if (manhattanDistance > world.max_distance_between_nodes) continue;			
			
			local checkIndustry = false;
			
			// See if we need to add or remove some vehicles.
			// Take a guess at the travel time and profit for each cargo type.
			foreach (cargoID in primIndustryConnectionNode.cargoIdsProducing) {

				// Check if this connection already exists.
				local connection = primIndustryConnectionNode.GetConnection(secondConnectionNode, cargoID);

				if (connection == null || !connection.pathInfo.build)
					continue;

				if (!connection.bilateralConnection)
					checkIndustry = true; 
				connections.push(connection);
			}
			
			if (checkIndustry) {
				if (!industriesToCheck.rawin(secondConnectionNode))
					industriesToCheck[secondConnectionNode] <- secondConnectionNode;
			}
		}
	}
	
	// Also check for other connection starting from this node.
	if (industriesToCheck.len() > 0)
		UpdateIndustryConnections(industriesToCheck);
}


function VehiclesAdvisor::HaltPlanner() {
	return reports.len() > 0;
} 
