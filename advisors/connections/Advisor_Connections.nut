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

	while ((report = connectionReports.Pop()) != null) {

		/**
		 * Do an aditional check to prevent this piece of code to check all possible 
		 * connections and just check a reasonable number until we've spend enough
		 * money or till we've spend enough time in this function.
		 */
		//if (possibleConnections > 5 && connectionCache.Count() > 5)
		if (connectionCache.Count() > 10)
			break;
			
		// If we haven't calculated yet what it cost to build this report, we do it now.
		local pathfinder = RoadPathFinding();
		local pathInfo = null;
		
		// Check if we already know the path or need to calculate it.
		local otherConnection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
		
		// Use the already calculated pathInfo if it is already calculated and the forceReplan flag isn't set!
//		if (otherConnection != null && !otherConnection.pathInfo.forceReplan) {
		if (otherConnection != null && otherConnection.pathInfo.build) {
			// Use the already build path.
			pathInfo = otherConnection.pathInfo;
		} else {
			// Find a new path.
			pathInfo = pathfinder.FindFastestRoad(report.fromConnectionNode.GetProducingTiles(report.cargoID), report.toConnectionNode.GetAcceptingTiles(report.cargoID), true, true, AIStation.STATION_TRUCK_STOP, world.max_distance_between_nodes * 2);
			if (pathInfo == null) {
				Log.logError("No path found from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " Cargo: " + AICargo.GetCargoLabel(report.cargoID));
				continue;
			}
		}
		
		// Check if the industry connection node actually exists else create it, and update it!
		if (otherConnection == null) {
			otherConnection = Connection(report.cargoID, report.fromConnectionNode, report.toConnectionNode, pathInfo, false);
			report.fromConnectionNode.AddConnection(report.toConnectionNode, otherConnection);
		} else {
			otherConnection.pathInfo = pathInfo;
		}		
						
		// Compile the report :)
		report = otherConnection.CompileReport(world, report.engineID);
		
		// Check how much we have to spend:
		local money = Finance.GetMaxMoneyToSpend();
		local maxNrVehicles = report.nrVehicles;
		
		// Check if we need to sell vehicles.
		if (maxNrVehicles < 0) {
		
			Log.logWarning("Selling vehicles not implemented yet!\n");
			continue;
			if (pathInfo.build && maxNrVehicles < -1) {
				Log.logWarning("Sell " + maxNrVehicles + " vehicles on the connection from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + "!");
			} else {
				continue;
			}
		}
		
		// Actually buy vehicles!
		else {
	
			// If we can't pay for all vehicle consider a number we can afford and check if it's worth while.
			if (report.costPerVehicle * maxNrVehicles > (money - report.costForRoad)) {
				local affordableMaxNrVehicles = ((money - report.costForRoad) / report.costPerVehicle).tointeger();
				
				if (!pathInfo.build && affordableMaxNrVehicles < 5) {
					continue;
				}				
			}
		
			if (!pathInfo.build && maxNrVehicles < 5 || maxNrVehicles == 0) {
				continue;
			}					
						
						/*
			// Calculate the number of road stations which need to be build
			local daysBetweenVehicles = ((timeToTravelTo + timeToTravelFrom) + 2 * 5) / maxNrVehicles.tofloat();
			local numberOfRoadStations = 5 / daysBetweenVehicles;
			if (numberOfRoadStations < 1) numberOfRoadStations = 1;
			else numberOfRoadStations = numberOfRoadStations.tointeger();
			*/
		}
		
		// If we need to build the path in question or we can add at least 2 vehicles we don't expand our search tree.
		if (report.Utility() > 0) {
		
			if (money > report.costForRoad + report.costPerVehicle) {
				possibleConnections++;
			}
				
			// Add the report to the list.
			connectionCache.Insert(report, -report.Utility());
			Log.logDebug("Insert road from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " in cache. Build " + report.nrVehicles + " vehicles! Utility: " + report.Utility() + ".");
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
			
		Log.logInfo("Report a connection from: " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " with " + report.nrVehicles + " vehicles! Utility: " + report.Utility());
		local actionList = [];
			

		// Give the action to build the road.
		if (connection.pathInfo.build != true)
			actionList.push(BuildRoadAction(connection, true, true, world));
			
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();
		if (report.nrVehicles > 0)
			vehicleAction.BuyVehicles(report.engineID, report.nrVehicles, connection);
		else if(report.nrVehicles < 0)
			vehicleAction.SellVehicles(report.engineID, -report.nrVehicles, connection);
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
				if (connection != null)
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

