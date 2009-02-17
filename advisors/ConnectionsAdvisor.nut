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
class ConnectionAdvisor extends Advisor { // EventListener

	reportTable = null;			// The table where all good reports are stored in.
	ignoreTable = null;			// A table with all connections which should be ignored because the algorithm already found better onces!
	connectionReports = null;		// A bineary heap which contains all connection reports this algorithm should investigate.
	vehicleType = null;			// The type of vehicles this class advises on.
	connectionManager = null;           // The connection manager which handels events concerning construction and demolishing of connections.
	lastConnectionUpdate = null;		// The last time the connections were updated (UpdateIndustryConnection).		

	constructor(world, vehType, conManager, eventManager) {
		Advisor.constructor(world);
		reportTable = {};
		ignoreTable = {};
		connectionReports = null;
		vehicleType = vehType;
		connectionManager = conManager;
	
		if (eventManager != null) {
			eventManager.AddEventListener(this, AIEvent.AI_ET_INDUSTRY_OPEN);
			eventManager.AddEventListener(this, AIEvent.AI_ET_INDUSTRY_CLOSE);
		}
	}
	
	/**
	 * Check which set of industry connections yield the highest profit.
	 */
	function GetReports();

	/**
	 * Return an action instance which builds the actual connection. This
	 * method will be used in the GetReports function.
	 * @param connection The connection which needs to be build.
	 * @return Instance of Action which builds that connection.
	 */
	function GetBuildAction(connection);

	/**
	 * Return the pathInfo for the given connection. This is used
	 * during the update of the report table.
	 * @param report The partially constructed report so far.
	 * @return Instance of PathInfo which contains the information to build
	 * the path for the connection.
	 */
	function GetPathInfo(report);

	/**
	 * Update the connection reports by iterating over all relevant industries
	 * and towns and store them in the bineary queue 'connectionReports'. The
	 * Update function will use this queue to generate reports, the reports
	 * generates by this function are only estimations. This method will iterate
	 * over ALL towns and industries if it produces a cargo, if a subclass
	 * needs specialized treatment this function can be overloaded.
	 * @param industry_tree An array containing all connection nodes the algorithm
	 * should iterate over and expand to fill the bineary queue.
	 */
	function UpdateIndustryConnections(industry_tree);
}

function ConnectionAdvisor::ProcessIndustryClosedEvent(industryID) {
	// Remove all related reports from the report table.
	foreach (report in reportTable) {
		if (report.fromConnectionNode.nodeType == ConnectionNode.INDUSTRY_NODE && 
			report.fromConnectionNode == industryID ||
			report.toConnectionNode.nodeType == ConnectionNode.INDUSTRY_NODE && 
			report.toConnectionNode == industryID)
			report.isInvalid = true;
	}
	
	// Remove all related connection reports.
	for (local i = 0; i < connectionReports._count; i++) {
		local report = connectionReports._queue[i];
		if (report.fromConnectionNode.nodeType == ConnectionNode.INDUSTRY_NODE && 
			report.fromConnectionNode == industryID ||
			report.toConnectionNode.nodeType == ConnectionNode.INDUSTRY_NODE && 
			report.toConnectionNode == industryID)
			report.isInvalid = true;
	}
	
	//world.worldChanged[vehicleType] = true;
}

function ConnectionAdvisor::ProcessIndustryOpenedEvent(industryID) {
	local industryNode = world.industry_table.rawget(industryID);
	
	// Check if this industry produces or accepts (or both :P).
	if (industryNode.cargoIdsAccepting.len() == 0) {
		Log.logDebug(industryNode.GetName() + " is a root list industry!");
		// It's in the root list.
		local industryNodeArray = [industryNode];
		UpdateIndustryConnections(industryNodeArray);
	} else {
		
		Log.logDebug(industryNode.GetName() + " is a non-Root list industry!");
		// If the industry is not in the root list, we search for
		// industry nodes which can connect to this industry and 
		// already have been build.
		local originalConnectionNodeLists = [];
		local constructedProducingIndustryNodes = [];
		foreach (producingIndustryNode in industryNode.connectionNodeListReversed) {
			//if (producingIndustryNode.activeConnection == null) {
				
				Log.logDebug("Attach: " + producingIndustryNode.GetName() + " to " + industryNode.GetName());
				// Store orginal connection node lists and replace it with the new industry node.
				originalConnectionNodeLists.push(clone producingIndustryNode.connectionNodeList);
				producingIndustryNode.connectionNodeList = [industryNode];
				constructedProducingIndustryNodes.push(producingIndustryNode);
			//}
		}
		
		UpdateIndustryConnections(constructedProducingIndustryNodes);
		
		// Restore original connection node lists..
		foreach (producingIndustryNode in constructedProducingIndustryNodes)
			producingIndustryNode.connectionNodeList = originalConnectionNodeLists.pop();
	}
	/// Add new 
	//world.worldChanged[vehicleType] = true;
}

/**
 * Construct a report by finding the largest subset of buildable infrastructure given
 * the amount of money available to us, which in turn yields the largest income.
 */
function ConnectionAdvisor::Update(loopCounter) {

	local currentDate = AIDate.GetCurrentDate();
	if (loopCounter == 0) {

		if (!GameSettings.IsBuildable(vehicleType)) {
			disabled = true;
			return;
		} else
			disabled = false;

		// Check if some connections in the reportTable have been build, if so remove them!
		local reportsToBeRemoved = [];
		foreach (report in reportTable)
			if (report.isInvalid || report.connection.pathInfo.build)
				reportsToBeRemoved.push(report);
		
		foreach (report in reportsToBeRemoved)
			reportTable.rawdelete(report.connection.GetUID());
	
		if (world.worldChanged[vehicleType] || connectionReports == null || Date.GetDaysBetween(currentDate, lastConnectionUpdate) > world.DAYS_PER_YEAR) {
			connectionReports = BinaryHeap();
		
			Log.logDebug("Update industry connections.");
			UpdateIndustryConnections(world.industry_tree);
			world.worldChanged[vehicleType] = false;
			lastConnectionUpdate = AIDate.GetCurrentDate();
			Log.logDebug("Done...");
		}
	}

	if (disabled)
		return;

	// Try to get the best subset of options.
	local report;
	
	local startDate = AIDate.GetCurrentDate();

	// Always try to get one more then currently available in the report table.
	local minNrReports = (reportTable.len() < 5 ?  5 : reportTable.len() + 1);

	while (reportTable.len() < minNrReports &&
		Date.GetDaysBetween(startDate, AIDate.GetCurrentDate()) < World.DAYS_PER_YEAR / 24 &&
		(report = connectionReports.Pop()) != null) {
		
		if (report.isInvalid)
			continue;

		// Check if we already know the path or need to calculate it.
		local connection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
		if (connection != null && connection.pathInfo != null && connection.pathInfo.build)
			assert(false);
		
		Log.logDebug("Considder: " + report.ToString());
			
		local bestReport = report.fromConnectionNode.GetBestReport(report.cargoID);

		// Check if this connection has already been checked.
		if (connection != null && !connection.forceReplan && reportTable.rawin(connection.GetUID())) {
			local otherCon = reportTable.rawget(connection.GetUID());
			if (otherCon.connection.travelToNode.GetUID(report.cargoID) == connection.travelToNode.GetUID(report.cargoID))
				continue;
		}

		if (connection != null && bestReport == report)
			connection.forceReplan = false;

		// If we haven't calculated yet what it cost to build this report, we do it now.
		local pathInfo = GetPathInfo(report);
		if (pathInfo == null) {
			if (connection != null && bestReport == report)
				bestReport = null;
			continue;
		}

		// Check if the industry connection node actually exists else create it, and update it! If it exists
		// we must be carefull because an other report may already have clamed it.
		local oldPathInfo;
		if (connection == null) {
			connection = Connection(report.cargoID, report.fromConnectionNode, report.toConnectionNode, pathInfo, connectionManager);
			report.fromConnectionNode.AddConnection(report.toConnectionNode, connection);
		} else {
			oldPathInfo = clone connection.pathInfo;
			connection.pathInfo = pathInfo;
		}
						
		// Compile the report :)
		report = connection.CompileReport(world, report.engineID);
		if (report == null || report.isInvalid || report.nrVehicles < 1)
			continue;

		// If a connection already exists, see if it already has a report. If so we can only
		// overwrite it if our report is better or if the original needs a rewrite.
		// If the other is better we restore the original pathInfo and back off.
		if (bestReport && !connection.forceReplan && report.Utility() <= bestReport.Utility()) {
			if (oldPathInfo)
				connection.pathInfo = oldPathInfo;
			continue;
		}

		// If the report yields a positive result we add it to the list of possible connections.
		if (report.Utility() > 0) {
		
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

			// If an other report already existed, mark it as invalid.
			if (bestReport)
				bestReport.isInvalid = true;

			//connection.travelFromNode.bestReport = report;
			bestReport = report;
			connection.forceReplan = false;
			Log.logInfo("[" + reportTable.len() +  "/" + minNrReports + "] " + report.ToString());
		}
	}
	
	// If we find no other possible connections, extend our range!
	if (connectionReports.Count() == 0 && (vehicleType == AIVehicle.VT_ROAD || vehicleType == AIVehicle.VT_RAIL))
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
//		if (connection != null && connection.pathInfo != null && connection.pathInfo.build)
//			assert(false);

		if (connection.forceReplan || report.isInvalid) {
			// Only mark a connection as invalid if it's the same report!
			if (connection.travelFromNode.GetBestReport(report.cargoID) == report)
				connection.forceReplan = true;
			continue;
		}
	
		// Check if this industry has already been processed, if this is the
		// case, we won't add it to the reports because we want to prevent
		// an industry from being exploited by different connections which
		// interfere with eachother. i.e. 1 connection should suffise to bring
		// all cargo from 1 producing industry to 1 accepting industry.
		if (processedProcessingIndustries.rawin(connection.GetUID()))
			continue;
			
		// Update report.
		report = connection.CompileReport(world, world.cargoTransportEngineIds[vehicleType][connection.cargoID]);
		if (report == null || connection.forceReplan || report.isInvalid || report.nrVehicles < 1) {
			// Only mark a connection as invalid if it's the same report!
			if (connection.travelFromNode.GetBestReport(report.cargoID) == report)
				connection.forceReplan = true;
			continue;
		}
			
		local actionList = [];
			
		// Give the action to build the road.
		actionList.push(GetBuildAction(connection));
			
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();
		
		// Buy only half of the vehicles needed, build the rest gradualy.
		if (report.nrVehicles != 1)
			report.nrVehicles = report.nrVehicles / 2;
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
	local maxDistanceConstraints = vehicleType != AIVehicle.VT_AIR;
	local maxDistanceMultiplier = 1;
	if (vehicleType == AIVehicle.VT_WATER)
		maxDistanceMultiplier = 0.75;

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

		// See if we need to add or remove some vehicles.
		// Take a guess at the travel time and profit for each cargo type.
		foreach (cargoID in primIndustryConnectionNode.cargoIdsProducing) {

			// Make sure we don't serve any industry twice!
			local skip = false;
			foreach (activeConnection in primIndustryConnectionNode.activeConnections) {
				if (activeConnection.cargoID == cargoID) {
					if (!activeConnection.bilateralConnection)
						industriesToCheck[activeConnection.travelToNode] <- activeConnection.travelToNode;
					skip = true;
					break;
				}
			}
			
			if (skip)
				continue;

			foreach (secondConnectionNode in primIndustryConnectionNode.connectionNodeList) {
				local manhattanDistance = AIMap.DistanceManhattan(primIndustryConnectionNode.GetLocation(), secondConnectionNode.GetLocation());
		
				// Check if the nodes are not to far away (we restrict it by an extra 
				// percentage to avoid doing unnecessary work by envoking the pathfinder
				// where this isn't necessary.
				if (maxDistanceConstraints && manhattanDistance * maxDistanceMultiplier > world.max_distance_between_nodes) continue;			
				
				// Check if this connection isn't in the ignore table.
				if (ignoreTable.rawin(primIndustryConnectionNode.GetUID(cargoID) + "_" + secondConnectionNode.GetUID(cargoID)))
					continue;

				// Check if we even have an engine to transport this cargo.
				local engineID = world.cargoTransportEngineIds[vehicleType][cargoID];
				if (engineID == -1)
					continue;

				// Check if the connection is actually profitable.
				local report = ConnectionReport(world, primIndustryConnectionNode, secondConnectionNode, cargoID, engineID, 0);
				if (report.Utility() > 0)
					connectionReports.Insert(report, -report.Utility());
			}
		}
	}
	
	// Also check for other connection starting from this node.
	if (industriesToCheck.len() > 0)
		UpdateIndustryConnections(industriesToCheck);
}
