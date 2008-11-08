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
	reportTable = null;				// The table where all good reports are stored in.
	ignoreTable = null;				// A table with all connections which should be ignored because the algorithm already found better onces!
	maxNrReports = 5;				// The minimum number of reports this report should have.
	connectionReports = null;		// A bineary heap which contains all connection reports this algorithm should investigate.
		
	constructor(world)
	{
		Advisor.constructor(world);
		reportTable = {};
		ignoreTable = {};
	}
	
	/**
	 * Check which set of industry connections yield the highest profit.
	 */
	function GetReports();

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
function ConnectionAdvisor::Update(loopCounter)
{

	if (loopCounter == 0) {
		// Check if some connections in the reportTable have been build, if so remove them!
		local reportsToBeRemoved = [];
		foreach (report in reportTable)
			if (report.connection.pathInfo.forceReplan || report.connection.pathInfo.build)
				reportsToBeRemoved.push(report);
		
		foreach (report in reportsToBeRemoved)
			reportTable.rawdelete(report.connection.GetUID());
	
		Log.logInfo("ConnectionAdvisor::getReports()");
		connectionReports = BinaryHeap();
		
		Log.logDebug("Update industry connections.");
		UpdateIndustryConnections(world.industry_tree);
	}

	// The report list to construct.
	local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);

	// Try to get the best subset of options.
	local report;
	
	// Keep track of the number of connections we could build, if we had the money.
	local possibleConnections = 0;
	
	local startDate = AIDate.GetCurrentDate();

	while ((report = connectionReports.Pop()) != null &&
		reportTable.len() < maxNrReports + loopCounter &&
		Date.GetDaysBetween(startDate, AIDate.GetCurrentDate()) < World.DAYS_PER_YEAR / 24) {

		Log.logDebug("Considder: " + report.ToString());
		// Check if we already know the path or need to calculate it.
		local connection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);

		// Check if this connection has already been checked.
		foreach (report in reportTable)
			if (report.connection == connection)
				continue;

		// If we haven't calculated yet what it cost to build this report, we do it now.
		local pathfinder = RoadPathFinding(PathFinderHelper());
		pathfinder.costTillEnd = pathfinder.costForNewRoad;
		local pathInfo = null;
		
		
		pathInfo = pathfinder.FindFastestRoad(report.fromConnectionNode.GetProducingTiles(report.cargoID), report.toConnectionNode.GetAcceptingTiles(report.cargoID), true, true, AIStation.STATION_TRUCK_STOP, AIMap.DistanceManhattan(report.fromConnectionNode.GetLocation(), report.toConnectionNode.GetLocation()) * 1.5);
		if (pathInfo == null) {
			Log.logError("No path found from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " Cargo: " + AICargo.GetCargoLabel(report.cargoID));
			continue;
		}
		
		// Check if the industry connection node actually exists else create it, and update it!
		if (connection == null) {
			connection = Connection(report.cargoID, report.fromConnectionNode, report.toConnectionNode, pathInfo);
			report.fromConnectionNode.AddConnection(report.toConnectionNode, connection);
		} else
			connection.pathInfo = pathInfo;		
						
		// Compile the report :)
		report = connection.CompileReport(world, report.engineID);
		if (report == null)
			continue;

		// If the report yields a positive result we add it to the list of possible connections.
		if (report.Utility() > 0) {
		
			if (!connection.pathInfo.build) {
				possibleConnections++;
			}
				
			// Add the report to the list.
			if (reportTable.rawin(connection.GetUID())) {
				
				// Check if the report in the table is actually better.
				local rep = reportTable.rawget(connection.GetUID());
				if (rep.Utility() >= report.Utility()) {
					
					// Add this entry to the ignore table.
					ignoreTable[connection.travelFromNode.GetUID(connection.cargoID) + "_" + connection.travelToNode.GetUID(connection.cargoID)] <- null;
					continue;				
				}
				
				// If the new one is better, add the original one to the ignore list.
				local originalReport = reportTable.rawget(connection.GetUID());
				ignoreTable[originalReport.fromConnectionNode.GetUID(originalReport.cargoID) + "_" + originalReport.toConnectionNode.GetUID(originalReport.cargoID)] <- null;
				Log.logDebug("Replace: " + report.Utility() + " > " + originalReport.Utility());
				reportTable.rawdelete(connection.GetUID());
			}
			
			reportTable[connection.GetUID()] <- report;
			Log.logInfo("[" + reportTable.len() +  "/" + (maxNrReports + loopCounter) + "] " + report.ToString());
		}
	}
	
	// If we find no other possible connections, extend our range!
	if (possibleConnections == 0 && reportTable.len() < maxNrReports + loopCounter)
		world.IncreaseMaxDistanceBetweenNodes();
}

function ConnectionAdvisor::GetReports() {
	
	// We have a list with possible connections we can afford, we now apply
	// a subsum algorithm to get the best profit possible with the given money.
	local reports = [];
	local processedProcessingIndustries = {};
	
	foreach (report in reportTable) {
	
		// The industryConnectionNode gives us the actual connection.
		local connection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
	
		// Check if this industry has already been processed, if this is the
		// case, we won't add it to the reports because we want to prevent
		// an industry from being exploited by different connections which
		// interfere with eachother. i.e. 1 connection should suffise to bring
		// all cargo from 1 producing industry to 1 accepting industry.
		if (processedProcessingIndustries.rawin(connection.GetUID()))
			continue;
			
		// Update report.
		report = connection.CompileReport(world, world.cargoTransportEngineIds[AIVehicle.VEHICLE_ROAD][connection.cargoID]);
			
		Log.logInfo("Report a road connection from: " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " with " + report.nrVehicles + " vehicles! Utility: " + report.Utility());
		local actionList = [];
			
		// Give the action to build the road.
		actionList.push(BuildRoadAction(connection, true, true, world));
			
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();
		
		// TEST!
		report.nrVehicles = report.nrVehicles / 2;
		
		// Buy only half of the vehicles needed, build the rest gradualy.
		vehicleAction.BuyVehicles(report.engineID, report.nrVehicles, connection);
		
		actionList.push(vehicleAction);
		report.actions = actionList;

		// Create a report and store it!
		reports.push(report);
		processedProcessingIndustries[connection.GetUID()] <- connection.GetUID();
	}
	
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

				// Check if we even have an engine to transport this cargo.
				local engineID = world.cargoTransportEngineIds[AIVehicle.VEHICLE_ROAD][cargoID];
				if (engineID == -1)
					continue;

				// Check if this connection already exists.
				local connection = primIndustryConnectionNode.GetConnection(secondConnectionNode, cargoID);

				// Check if this connection isn't in the ignore table.
				if (ignoreTable.rawin(primIndustryConnectionNode.GetUID(cargoID) + "_" + secondConnectionNode.GetUID(cargoID)))
					continue;

				// Make sure we only check the accepting side for possible connections if
				// and only if it has a connection to it.
				if (connection != null && connection.pathInfo.build) {

					// Don't check bilateral connections because all towns are already in the
					// root list!
					if (!connection.bilateralConnection)
						checkIndustry = true;
					continue;
				}

				if (connection == null) {

					local skip = false;

					// Make sure the producing side isn't already served, we don't want more then
					// 1 connection on 1 production facility per cargo type.
					local otherConnections = primIndustryConnectionNode.GetConnections(cargoID);
					foreach (otherConnection in otherConnections) {
						if (otherConnection.pathInfo.build && otherConnection != connection) {
							skip = true;
							break;
						}
					}
				
					if (skip)
						continue;
				}
				local report = ConnectionReport(world, primIndustryConnectionNode, secondConnectionNode, cargoID, engineID, 0);
				if (report.Utility() > 0)
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

/*function ConnectionAdvisor::HaltPlanner() {
	return Finance.GetMaxMoneyToSpend() > 250000 && reportTable.len() > 5;
}
*/
