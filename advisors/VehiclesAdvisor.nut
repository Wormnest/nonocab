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

function VehiclesAdvisor::Update(loopCounter) {
	
	if (loopCounter == 0) {
		connections = [];
		UpdateIndustryConnections(world.industry_tree);
	}
	reports = [];
	

//	Log.logInfo("Update vehicle advisor");
	foreach (connection in connections) {

		// If the road isn't build we can't micro manage, move on!		
		if (!connection.pathInfo.build) 
			continue;

		// Make sure we don't update a connection to often!
		local currentDate = AIDate.GetCurrentDate();
		if (Date().GetDaysBetween(connection.lastChecked, currentDate) < 15)
			continue;
		
		connection.lastChecked = currentDate;
		local report = connection.CompileReport(world, world.cargoTransportEngineIds[connection.cargoID]);
		report.nrVehicles = 0;
		
		
		// We first check if there is a line of vehicles waiting for the depot:
		local tileToCheck = connection.pathInfo.roadList[connection.pathInfo.roadList.len() - 3].tile;
			
		report.nrVehicles = 0;
		local travelToTile = AIStation().GetLocation(connection.travelFromNodeStationID);
			
		// Check if there are any vehicles waiting on this tile and if so, sell them!
		foreach (vehicleGroup in connection.vehiclesOperating) {
			foreach (vehicleID in vehicleGroup.vehicleIDs) {
				if (AIMap().DistanceManhattan(AIVehicle().GetLocation(vehicleID), travelToTile) > 1 && 
					AIMap().DistanceManhattan(AIVehicle().GetLocation(vehicleID), travelToTile) < 6 &&
					AIVehicle().GetCurrentSpeed(vehicleID) < 10 && 
//					AIVehicle().GetAge(vehicleID) > World.DAYS_PER_YEAR / 2 &&
					AIOrder().GetOrderDestination(vehicleID, AIOrder().CURRENT_ORDER) == travelToTile) {
					report.nrVehicles--;
				}
			}
		}

		// Now we check whether we need more vehicles
		if (connection.vehiclesOperating.len() == 0 || AIStation().GetCargoRating(connection.travelFromNodeStationID, connection.cargoID) < 67 || AIStation.GetCargoWaiting(connection.travelFromNodeStationID, connection.cargoID) > 100) {
			
			// If we have a line of vehicles waiting we also want to buy another station to spread the load.
			if (report.nrVehicles < 0) {

				// build additional station...
				report.nrRoadStations = 2;
				report.nrVehicles = 2;
			} else {
				// build new vehicles!
				report.nrVehicles = 2;
			}
		} 

		// We always want a little overhead (to be keen ;)).
		else if (report.nrVehicles > -2)
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
			
		Log.logInfo("Report a" + (connection.pathInfo.build ? "n update" : " connection") + " from: " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " with " + report.nrVehicles + " vehicles! Utility: " + report.Utility());
		local actionList = [];
						
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();
		
		// Buy only half of the vehicles needed, build the rest gradualy.
		if (report.nrVehicles > 0)
			vehicleAction.BuyVehicles(report.engineID, report.nrVehicles, connection);
		else if(report.nrVehicles < 0)
			vehicleAction.SellVehicles(report.engineID, -report.nrVehicles, connection);

		actionList.push(vehicleAction);

		if (report.nrRoadStations > 1) {
			Log.logWarning("build d3h road! " + report.connection.pathInfo.build);
			actionList.push(BuildRoadAction(report.connection, false, true, world));
		}
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
