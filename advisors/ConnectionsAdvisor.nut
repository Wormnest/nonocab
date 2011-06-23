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
class ConnectionAdvisor extends Advisor { // EventListener, ConnectionListener

	reportTable = null;			// The table where all good reports are stored in.
	ignoreTable = null;			// A table with all connections which should be ignored because the algorithm already found better onces!
	connectionReports = null;		// A bineary heap which contains all connection reports this algorithm should investigate.
	vehicleType = null;			// The type of vehicles this class advises on.
	connectionManager = null;           // The connection manager which handels events concerning construction and demolishing of connections.
	lastMaxDistanceBetweenNodes = null;	// Cached last distance between nodes.
	updateList = null;					// List of industry nodes that need regulair updating.
	activeUpdateList = null;            // The part of the update list that needs updating.
	lastUpdate = null;
	needUpdate = null;
	reportTableLength = null;
	closedIndustryList = null;  // Keep track of which industries have recently closed. We won't allow the AI to work on these.

	constructor(world, worldEventManager, vehType, conManager) {
		Advisor.constructor();
		reportTable = {};
		ignoreTable = {};
		updateList = [];
		connectionReports = null;
		vehicleType = vehType;
		connectionManager = conManager;
		lastMaxDistanceBetweenNodes = 0;
		lastUpdate = -100;
		needUpdate = false;
		closedIndustryList = {};
	
		worldEventManager.AddEventListener(this, AIEvent.AI_ET_INDUSTRY_OPEN);
		worldEventManager.AddEventListener(this, AIEvent.AI_ET_INDUSTRY_CLOSE);
		worldEventManager.AddEventListener(this, AIEvent.AI_ET_ENGINE_AVAILABLE);
		
		updateList = clone world.industry_tree;
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

// New industries are automatically picked up by the UpdateIndustryConnections function.
function ConnectionAdvisor::WE_IndustryOpened(industryNode) {
	
	// Only add this industry to the update list if it is in the root list.
	if (industryNode.cargoIdsAccepting.len() == 0 || AIIndustryType.IsRawIndustry(AIIndustry.GetIndustryType(industryNode.id)))
		updateList.push(industryNode);
	needUpdate = true;
}

function ConnectionAdvisor::WE_IndustryClosed(industryNode) {
	local industryID = industryNode.id;
	
	// Remove all related reports from the report table.
	foreach (report in reportTable) {
		if (report.connection.travelFromNode.nodeType == ConnectionNode.INDUSTRY_NODE && 
			report.connection.travelFromNode.id == industryID ||
			report.connection.travelToNode.nodeType == ConnectionNode.INDUSTRY_NODE && 
			report.connection.travelToNode.id == industryID)
			report.isInvalid = true;
	}
	
	closedIndustryList[industryID] <- true;
//	connectionReports = null;
}


/**
 * If a new engine become available and it is the first engine to carry a certain
 * cargo load which hasn't been available until now, update all relevant industries!
 * @param engineID The new available engineID.
 */
function ConnectionAdvisor::WE_EngineReplaced(engineID) {
	
	// Check if this new engine applies to this class.
	if (AIEngine.GetVehicleType(engineID) != vehicleType)
		return;
		
	// Update relevant part of the world.
	needUpdate = true;
}

/**
 * If a connection is realised, we must periodically check the accepting side
 * and see if the production is high enough to allow for a connection.
 * @param connection The realised connection.
 * @note Possible bug, if a connection produces more than 1 product it could be
 * that the 2nd product is ignored.
 */
function ConnectionAdvisor::ConnectionRealised(connection) {
		
	// Remove the start point of the new connection from our lists.
	for (local i = 0; i < updateList.len(); i++) {
		if (connection.travelFromNode == updateList[i]) {
			updateList.remove(i);
			break;
		}
	}
	
	// Check if the accepting side actually produces something and
	// if it isn't a town!
	if (connection.travelToNode.nodeType != ConnectionNode.TOWN_NODE &&
		connection.travelToNode.cargoIdsProducing.len() != 0)
		// Now push the new served connection to the update list.
		updateList.push(connection.travelToNode);

	needUpdate = true;
}

/**
 * If a connection is demolished, we need to reavaluate the producing
 * industry and check if we can restore this connection.
 * @param connection The demolished connection.
 */
function ConnectionAdvisor::ConnectionDemolished(connection) {

	// Remove the end point of the demolished connection from our lists.
	for (local i = 0; i < updateList.len(); i++) {
		if (connection.travelToNode == updateList[i]) {
			updateList.remove(i);
			break;
		}
	}
	
	// Read the old connection node to our update list.
	updateList.push(connection.travelFromNode);
	needUpdate = true;
}

/**
 * Construct a report by finding the largest subset of buildable infrastructure given
 * the amount of money available to us, which in turn yields the largest income.
 */
function ConnectionAdvisor::Update(loopCounter) {

	if (loopCounter == 0) {

		if (!GameSettings.IsBuildable(vehicleType)) {
			disabled = true;
			return;
		} else
			disabled = false;

		// Check if some connections in the reportTable have been build, if so remove them!
		local reportsToBeRemoved = [];
		foreach (report in reportTable)
			if (report.isInvalid || report.connection.pathInfo.build || report.connection.forceReplan)
				reportsToBeRemoved.push(report);
		
		foreach (report in reportsToBeRemoved)
			reportTable.rawdelete(report.connection.GetUID());
	}
	
	// Every time something might have been build, we update all possible
	// reports and consequentially get the latest data from the world.
	if (connectionReports == null || connectionReports.Count() <= reportTableLength / 4) {
		Log.logInfo("(Re)populate active update list.");
		connectionReports = BinaryHeap();
		activeUpdateList = clone updateList;
		UpdateIndustryConnections(activeUpdateList);
		reportTableLength = connectionReports.Count();
		lastUpdate = AIDate.GetCurrentDate();
		closedIndustryList = {};
		Log.logInfo("Done populating!");
	}

	if (disabled)
		return;

	// Try to get the best subset of options.
	local report;
	
	local startDate = AIDate.GetCurrentDate();

	// Always try to get one more then currently available in the report table.
	local minNrReports = (reportTable.len() < 5 ?  5 : reportTable.len() + 1);
	assert(connectionReports != null);
	while ((reportTable.len() < minNrReports || Date.GetDaysBetween(startDate, AIDate.GetCurrentDate()) < Date.DAYS_PER_YEAR / 48) &&
		Date.GetDaysBetween(startDate, AIDate.GetCurrentDate()) < Date.DAYS_PER_YEAR / 24 &&
		(report = connectionReports.Pop()) != null) {

		// Check if the report is flagged invalid or already build / closed in the mean time.		
		if (report.isInvalid || closedIndustryList.rawin(report.connection.travelFromNode.id) || closedIndustryList.rawin(report.connection.travelToNode.id))
			continue;

//		local connection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
		local connection = report.connection;
		assert (connection != null);
		assert (connection.pathInfo != null);
		if (connection.pathInfo.build)
			continue;
		
		Log.logDebug("Considder: " + report.ToString());
			
		local bestReport = report.connection.travelFromNode.GetBestReport(report.connection.cargoID);
		
		// Check if this connection has already been checked.
		if (!connection.forceReplan && reportTable.rawin(connection.GetUID())) {
			local otherCon = reportTable.rawget(connection.GetUID());
			if (otherCon.connection.travelToNode.GetUID(report.connection.cargoID) == connection.travelToNode.GetUID(report.connection.cargoID))
				continue;
		}

		if (bestReport == report)
			connection.forceReplan = false;

		// If we haven't calculated yet what it cost to build this report, we do it now.
		local pathInfo = GetPathInfo(report);
		if (pathInfo == null) {
			if (bestReport == report)
				bestReport = null;
			continue;
		}
		
		// Check if the industry connection node actually exists else create it, and update it! If it exists
		// we must be carefull because an other report may already have clamed it.
		connection.pathInfo = pathInfo;
						
		// Compile the report :)
		report = connection.CompileReport(pathInfo.vehicleType);
		if (report == null || report.isInvalid || report.nrVehicles < 1)
			continue;

		// If a connection already exists, see if it already has a report. If so we can only
		// overwrite it if our report is better or if the original needs a rewrite.
		// If the other is better we restore the original pathInfo and back off.
		if (bestReport && !connection.forceReplan && report.Utility() <= bestReport.Utility())
			continue;
		
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
				ignoreTable[originalReport.connection.travelFromNode.GetUID(originalReport.connection.cargoID) + "_" + originalReport.connection.travelToNode.GetUID(originalReport.connection.cargoID)] <- null;
				Log.logDebug("Replace: " + report.Utility() + " > " + originalReport.Utility());
			}
			
			reportTable[connection.GetUID()] <- report;

			// If an other report already existed, mark it as invalid.
			if (bestReport)
				bestReport.isInvalid = true;

			//connection.travelFromNode.bestReport = report;
			connection.travelFromNode.AddBestReport(report);
			connection.forceReplan = false;
			Log.logInfo("[" + reportTable.len() +  "/" + minNrReports + "] " + report.ToString());
		}
	}
}

function ConnectionAdvisor::GetReports() {

	// We have a list with possible connections we can afford, we now apply
	// a subsum algorithm to get the best profit possible with the given money.
	local reports = [];
	local processedProcessingIndustries = {};
	
	foreach (report in reportTable) {

		// The industryConnectionNode gives us the actual connection.
		//local connection = report.connectfromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
		local connection = report.connection;

		// If the connection is already build, don't add it!
		local isAlreadyTransportingCargo = false;
		foreach (activeConnection in report.connection.travelFromNode.activeConnections) {
			if (activeConnection.cargoID == report.connection.cargoID) {
				isAlreadyTransportingCargo = true;
				break;
			}
		}

		if (isAlreadyTransportingCargo)
			continue;

		if (connection.forceReplan || report.isInvalid) {
			// Only mark a connection as invalid if it's the same report!
			if (connection.travelFromNode.GetBestReport(connection.cargoID) == report)
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
		report = connection.CompileReport(vehicleType);
		if (report == null)
			continue;

		if (report.isInvalid || report.nrVehicles < 1 || report.Utility() < 0) {
			// Only mark a connection as invalid if it's the same report!
			if (connection.travelFromNode.GetBestReport(connection.cargoID) == report)
				connection.forceReplan = true;
			continue;
		}
			
		local actionList = [];
			
		// Give the action to build the road.
		actionList.push(GetBuildAction(connection));
			
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();

		// TODO: Change this for trains.
		vehicleAction.BuyVehicles(report.transportEngineID, report.nrVehicles, report.holdingEngineID, report.nrWagonsPerVehicle, connection);
		
		actionList.push(vehicleAction);
		report.actions = actionList;

		// Create a report and store it!
		reports.push(report);
		processedProcessingIndustries[connection.GetUID()] <- connection.GetUID();
	}
	
	return reports;
}

function ConnectionAdvisor::UpdateIndustryConnections(connectionNodeList) {

	local startTicks = AIController.GetTick();
	local processedConnections = {};

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
	for (local i = connectionNodeList.len() - 1; i > -1; i--) {
		
		if (AIController.GetTick() - startTicks > 1000) {
			Log.logDebug("Time's up! " + connectionNodeList.len());
			break;
		}
		i = AIBase.RandRange(connectionNodeList.len());
		local fromConnectionNode = connectionNodeList[i];
		
		if (vehicleType == AIVehicle.VT_WATER && !fromConnectionNode.isNearWater ||
			fromConnectionNode.isInvalid) {
			connectionNodeList.remove(i);
			continue;
		}
		
		// See if we need to add or remove some vehicles.
		// Take a guess at the travel time and profit for each cargo type.
		foreach (cargoID in fromConnectionNode.cargoIdsProducing) {

			// Check if this building produces enough (yet) to be considered.
			if (fromConnectionNode.nodeType == ConnectionNode.INDUSTRY_NODE &&
				fromConnectionNode.GetProduction(cargoID) == 0)
				continue;

			// Make sure we don't serve any industry twice!
			local skip = false;
			foreach (activeConnection in fromConnectionNode.activeConnections) {
				if (activeConnection.cargoID == cargoID) {
					skip = true;
					break;
				}
			}
			
			if (skip)
				continue;

			foreach (toConnectionNode in fromConnectionNode.connectionNodeList) {
				if (vehicleType == AIVehicle.VT_WATER && !toConnectionNode.isNearWater ||
					toConnectionNode.isInvalid)
					continue;

				// Check if this connection isn't in the ignore table.
				if (ignoreTable.rawin(fromConnectionNode.GetUID(cargoID) + "_" + toConnectionNode.GetUID(cargoID)))
					continue;

				// Check if the connection is actually profitable.
				local connection = fromConnectionNode.GetConnection(toConnectionNode, cargoID);
				if (connection == null) {
					local pathInfo = PathInfo(null, null, 0, AIVehicle.VT_INVALID);
					connection = Connection(cargoID, fromConnectionNode, toConnectionNode, pathInfo, connectionManager);
					fromConnectionNode.AddConnection(toConnectionNode, connection);
				}
				connection.pathInfo.vehicleType = AIVehicle.VT_INVALID;
				local report = connection.CompileReport(vehicleType);
				
				if (report != null && !report.isInvalid && report.Utility() > 0) {

					// Calculate how long this engine can travel in 100 days.
					// speed (in km/h) * #days * 24 (km/day) / (tile length / 24).
					local maxDistance = (AIEngine.GetMaxSpeed(report.transportEngineID).tofloat() * 100 * (AIEngine.GetReliability(report.transportEngineID).tofloat() / 100)) / Tile.straightRoadLength;
					local manhattanDistance = AIMap.DistanceManhattan(fromConnectionNode.GetLocation(), toConnectionNode.GetLocation());

					// Check if the nodes are not to far away (we restrict it by an extra 
					// percentage to avoid doing unnecessary work by envoking the pathfinder
					// where this isn't necessary.
					if (manhattanDistance > maxDistance)
						continue;
					
					// For airlines we can very accurately estimate the travel times and
					// income, so we can already prune connections here since we know
					// that connections with lower utility values will (almost certain)
					// be worse than those with higher values.
					if (fromConnectionNode.nodeType == ConnectionNode.INDUSTRY_NODE &&
						vehicleType == AIVehicle.VT_AIR) {
						local uid = fromConnectionNode.GetUID(cargoID);
						if (processedConnections.rawin(uid)) {
							local existingConnection = processedConnections.rawget(uid);
							if (existingConnection.Utility() >= report.Utility())
								continue;
						}
						
						processedConnections[uid] <- report;
					}
											
					connectionReports.Insert(report, -report.Utility());
				}
			}
		}
		
		// Remove this item from our update list once we're done.
		connectionNodeList.remove(i);
	}
	
	Log.logDebug("Ticks: " + (AIController.GetTick() - startTicks) + " found connections: " + connectionReports.Count());
}
