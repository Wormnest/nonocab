import("queue.binary_heap", "BinaryHeap", 1);

/**
 * Build economy tree with primary economies which require no input
 * to produce on the root level, secundary economies which require
 * input from primary industries as children and so on. The max 
 * depth in OpenTTD is 4;
 *
 * Grain                              }
 * Iron ore        -> Steel           }-> Goods  -> Town
 * Livestock                          }
 */
class ConnectionAdvisor extends Advisor
{
	world = null;				// Pointer to the World class.
	connectionReports = null;
		
	constructor(world)
	{
		this.world = world;
	}
	
	/**
	 * Check which set of industry connections yield the highest profit.
	 */
	function getReports();

	/**
	 * Iterate through the industry tree and update its information.
	 * @industryTree An array with connectionNode instances.
	 */
	function UpdateIndustryConnections(industryTree);
}

/**
 * Construct a report by finding the largest subset of buildable infrastructure given
 * the amount of money available to us, which in turn yields the largest income.
 */
function ConnectionAdvisor::getReports()
{
	Log.logInfo("ConnectionAdvisor::getReports()");
	connectionReports = BinaryHeap();
	
	Log.logDebug("Update industry connections.");
	UpdateIndustryConnections(world.industry_tree);

	// The report list to construct.
	local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		
	// Hold a cache of possible connections.
	local connectionCache = BinaryHeap();

	// Try to get the best subset of options.
	local report;
	
	// Keep track of the number of connections we could build, if we had the money.
	local possibleConnections = 0;
	local newPath = 0;

	while ((report = connectionReports.Pop()) != null) {

		/**
		 * Do an aditional check to prevent this piece of code to check all possible 
		 * connections and just check a reasonable number until we've spend enough
		 * money or till we've spend enough time in this function.
		 */
		//if (possibleConnections > 5 && connectionCache.Count() > 5)
		if (connectionCache.Count() > 4 && newPath > 0)
			break;
			
		// If we haven't calculated yet what it cost to build this report, we do it now.
		local pathfinder = RoadPathFinding();
		local pathInfo = null;
		
		// Check if we already know the path or need to calculate it.
		local connection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
		
		// Use the already calculated pathInfo if it is already calculated and the forceReplan flag isn't set!
		if (connection != null && !connection.pathInfo.forceReplan) {
//		if (connection != null && connection.pathInfo.build) {
			// Use the already build path.
			pathInfo = connection.pathInfo;
		} else {
			// Find a new path.
			pathInfo = pathfinder.FindFastestRoad(report.fromConnectionNode.GetProducingTiles(report.cargoID), report.toConnectionNode.GetAcceptingTiles(report.cargoID), true, true, AIStation.STATION_TRUCK_STOP, world.max_distance_between_nodes * 2);
			newPath++;
			if (pathInfo == null) {
				Log.logError("No path found from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " Cargo: " + AICargo.GetCargoLabel(report.cargoID));
				continue;
			}
		}
		
		// Check if the industry connection node actually exists else create it, and update it!
		if (connection == null) {
			connection = Connection(report.cargoID, report.fromConnectionNode, report.toConnectionNode, pathInfo, false);
			report.fromConnectionNode.AddConnection(report.toConnectionNode, connection);
		} else {
			connection.pathInfo = pathInfo;
		}		
						
		// Compile the report :)
		report = connection.CompileReport(world, report.engineID);
		if (report == null)
			continue;
			
		// Check how much we have to spend:
		local money = Finance.GetMaxMoneyToSpend();
		local maxNrVehicles = report.nrVehicles;
		
		// Check if the road is already build, in that case: micro manage! :)
		if (connection.pathInfo.build) {
			
			// Make sure we don't update a connection to often!
			local currentDate = AIDate.GetCurrentDate();
			if (Date.GetDaysBetween(connection.lastChecked, currentDate) < 15)
				continue;
			
			connection.lastChecked = currentDate;
			report.nrVehicles = 0;
			
			// Now, we have maxNrVehicles as the maximum number of additional vehicles 
			// which is supported by this connection.
			
			// First we check whether the rating is good or bad.
			if (connection.vehiclesOperating.len() == 0 || AIStation.GetCargoRating(connection.travelFromNodeStationID, connection.cargoID) < 67 || AIStation.GetCargoWaiting(connection.travelFromNodeStationID, connection.cargoID) > 100) {
			
				// It's bad so we need more vehicles! :)
				report.nrVehicles = 2;
			} else {
			
				// If our rating is alright, make sure we don't have to many vehicles!
				local tileToCheck = connection.pathInfo.roadList[connection.pathInfo.roadList.len() - 3].tile;
				
				report.nrVehicles = 0;
				local travelToTile = AIStation.GetLocation(connection.travelFromNodeStationID);
				
				// Check if there are any vehicles waiting on this tile and if so, sell them!
				foreach (vehicleGroup in connection.vehiclesOperating) {
					foreach (vehicleID in vehicleGroup.vehicleIDs) {
						if (AIMap.DistanceManhattan(AIVehicle.GetLocation(vehicleID), AIStation.GetLocation(connection.travelFromNodeStationID)) > 2 && 
							AIMap.DistanceManhattan(AIVehicle.GetLocation(vehicleID), AIStation.GetLocation(connection.travelFromNodeStationID)) < 10 &&
							AIVehicle.GetCurrentSpeed(vehicleID) < 10 && 
							AIVehicle.GetAge(vehicleID) > World.DAYS_PER_YEAR / 2 &&
							AIOrder.GetOrderDestination(vehicleID, AIOrder.CURRENT_ORDER) == travelToTile) {
							report.nrVehicles--;
						}
					}
				}
				
				// We always want a little overhead (to be keen ;)).
				if (report.nrVehicles > -2)
					continue;
			}

			// Lets have some fun :)
//			pathInfo = pathfinder.FindFastestRoad(connection.GetLocationsForNewStation(true), connection.GetLocationsForNewStation(false), true, true, AIStation.STATION_TRUCK_STOP, world.max_distance_between_nodes * 2);
//			if (pathInfo != null) {
//				connection.pathInfo = pathInfo;
				
//				BuildRoadAction(connection, false, true, world).Execute();
//			}
		} 
		
		// Check the requirements for a new connection!
		else {
			// With less then 1 vehicle there is no point of making this connection.
			if (maxNrVehicles < 1)
				continue;
	
			// If we can't pay for all vehicle consider a number we can afford and check if it's worth while.
/*			if (report.initialCostPerVehicle * maxNrVehicles > (money - report.initialCostPerVehicle)) {
				local affordableMaxNrVehicles = ((money - report.initialCost) / report.initialCostPerVehicle).tointeger();
				
				if (affordableMaxNrVehicles < 1) {
					if (report.Utility() > 0)
						possibleconnections++;
					continue;
				}				
			}*/
		}
		
		// If the report yields a positive result we add it to the list of possible connections.
		if (report.Utility() > 0) {
		
			if (!connection.pathInfo.build) {
				possibleConnections++;
			}
				
			// Add the report to the list.
			connectionCache.Insert(report, -report.Utility());
			Log.logDebug("Insert " + (connection.pathInfo.build ? "update" : "road") + " from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " in cache. Build " + report.nrVehicles + " vehicles! Utility: " + report.Utility() + ".");
		}
	}
	
	// We have a list with possible connections we can afford, we now apply
	// a subsum algorithm to get the best profit possible with the given money.
	local reports = [];
	local processedProcessingIndustries = {};
	
	//foreach (report in SubSum.GetSubSum(connectionCache, Finance.GetMaxMoneyToSpend())) {
	while ((report = connectionCache.Pop()) != null) {
	
		// The industryConnectionNode gives us the actual connection.
		local connection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
	
		// Check if this industry has already been processed, if this is the
		// case, we won't add it to the reports because we want to prevent
		// an industry from being exploited by different connections which
		// interfere with eachother. i.e. 1 connection should suffise to bring
		// all cargo from 1 producing industry to 1 accepting industry.
		local UID = report.fromConnectionNode.nodeType + report.fromConnectionNode.id + "_" + report.cargoID;
		if (!connection.pathInfo.build) {
			if (processedProcessingIndustries.rawin(UID))
				continue;
		}
			
		Log.logInfo("Report a" + (connection.pathInfo.build ? "n update" : " connection") + " from: " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " with " + report.nrVehicles + " vehicles! Utility: " + report.Utility());
		local actionList = [];
			

		// Give the action to build the road.
		if (connection.pathInfo.build != true)
			actionList.push(BuildRoadAction(connection, true, true, world));
			
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();
		
		// Buy only half of the vehicles needed, build the rest gradualy.
		if (report.nrVehicles > 0)
			vehicleAction.BuyVehicles(report.engineID, report.nrVehicles / 2, connection);
		else if(report.nrVehicles < 0) {
			vehicleAction.SellVehicles(report.engineID, -report.nrVehicles, connection);
			Log.logWarning("Jeej! Sell it :D");
		}
		actionList.push(vehicleAction);
		report.actions = actionList;

		// Create a report and store it!
		reports.push(report);
		processedProcessingIndustries[UID] <- UID;
	}
	
	// If we find no other possible connections, extend our range!
	if (possibleConnections == 0)
		world.IncreaseMaxDistanceBetweenNodes();
	
	Log.logDebug("Return reports " + possibleConnections);
	return reports;
}

function ConnectionAdvisor::UpdateIndustryConnections(industry_tree) {

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

				// Make sure the producing side isn't already served, we don't want more then
				// 1 connection on 1 production facility per cargo type.
				local otherConnections = primIndustryConnectionNode.GetConnections(cargoID);
				local skip = false;
				foreach (otherConnection in otherConnections) {
					if (otherConnection.pathInfo.build && otherConnection != connection) {
						skip = true;
						break;
					}
				}
				
				if (skip)
					continue;

				// Make sure we only check the accepting side for possible connections if
				// and only if it has a connection to it.
				if (connection != null && connection.pathInfo.build)
					checkIndustry = true; 

				local report = ConnectionReport(world, primIndustryConnectionNode, secondConnectionNode, cargoID, world.cargoTransportEngineIds[cargoID], 0);
				connectionReports.Insert(report, -report.Utility());
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

