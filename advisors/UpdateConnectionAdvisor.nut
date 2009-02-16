/**
 * This class takes care of upgrading existing connections:
 * - Update airports.
 * - Make routes longer.
 * - Updating to newer engines.
 * - Etc.
 */
class UpdateConnectionAdvisor extends Advisor/*, ConnectionListener */ {
	
	connections = null;					// The table of connections to manage.
	reports = null;
	connectionManager = null;			// Connection manager.
	
	constructor(world, conManager) {
		Advisor.constructor(world);
		connectionManager = conManager;
		connections = [];
		reports = [];
	}
}

// TODO: Subtract the utility of the removed connection.
function UpdateConnectionAdvisor::Update(loopCounter) {
	
	reports = [];

	foreach (connection in connections) {

		// If the road isn't build we can't micro manage, move on!		
		if (!connection.pathInfo.build) {
			Log.logWarning("Not present! " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName());
			assert(false);	
		}
		
		// Only consider road connections at this moment (remove later).
		if (connection.vehicleTypes != AIVehicle.VT_ROAD)
			continue;
			
		local originalReport = connection.CompileReport(world, world.cargoTransportEngineIds[connection.vehicleTypes][connection.cargoID]);
		local bestReport = null;
		local startNode = connection.travelFromNode;
		
		// Now check for alternative options and select the best one.
		foreach (endNode in startNode.connectionNodeList) {
			
			// We don't want to reevaluate the exising connection.
			if (endNode == connection.travelToNode)
				continue;
			
			local report = ConnectionReport(world, startNode, endNode, connection.cargoID, world.cargoTransportEngineIds[connection.vehicleTypes][connection.cargoID], 0);
			
			// Check if the new report is better than the origional.
			if (bestReport == null || report.Utility() > bestReport.Utility())
				bestReport = report;
		}
		
		if (bestReport == null || bestReport.Utility() < originalReport.Utility())
			continue;
			
		local existingConnection = bestReport.fromConnectionNode.GetConnection(bestReport.toConnectionNode, bestReport.cargoID);
		// If we haven't calculated yet what it cost to build this report, we do it now.
		local rca = RoadConnectionAdvisor(world, null, null);
		local pathInfo = rca.GetPathInfo(bestReport);
		if (pathInfo == null)
			continue;

		if (existingConnection == null) {
			existingConnection = Connection(bestReport.cargoID, bestReport.fromConnectionNode, bestReport.toConnectionNode, pathInfo, connectionManager);
			bestReport.fromConnectionNode.AddConnection(bestReport.toConnectionNode, existingConnection);
		} else
			existingConnection.pathInfo = pathInfo;
		bestReport.oldReport = originalReport;
		bestReport.connection = existingConnection;
		reports.push(bestReport);
	}	
}


/**
 * Construct a report by finding the largest subset of buildable infrastructure given
 * the amount of money available to us, which in turn yields the largest income.
 */
function UpdateConnectionAdvisor::GetReports() {
	
	local reportsToReturn = [];
	local report;
	
	foreach (report in reports) {
	
		// The industryConnectionNode gives us the actual connection.
		local connection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
		local oldConnection = report.oldReport.fromConnectionNode.GetConnection(report.oldReport.toConnectionNode, report.oldReport.cargoID);
		//connection.pathInfo.depot = oldConnection.pathInfo.depot;
		//connection.pathInfo.depotOtherEnd = oldConnection.pathInfo.depotOtherEnd;
			
		Log.logDebug("Report an update from: " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " with " + report.nrVehicles + " vehicles! Utility: " + report.Utility());
		local actionList = [];
		
		assert(oldConnection.pathInfo.build);
		
		// Fix report.
		actionList.push(BuildRoadAction(connection, true, true, world));
		actionList.push(TransferVehicles(world, oldConnection, connection));
		actionList.push(DemolishAction(oldConnection, world, false, true, false));
		report.actions = actionList;

		// Create a report and store it!
		reportsToReturn.push(report);
	}
	
	return reportsToReturn;
}

// Functions related to the interface ConnectionListener.
function UpdateConnectionAdvisor::ConnectionRealised(connection) {
	for (local i = 0; i < connections.len(); i++)
		if (connections[i] == connection)
			assert(false);
	connections.push(connection);
	assert(connection.pathInfo.build);
	
	Log.logWarning("Added: " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName());
}

function UpdateConnectionAdvisor::ConnectionDemolished(connection) {
	for (local i = 0; i < connections.len(); i++) {
		if (connections[i] == connection) {
			connections.remove(i);
			break;
		}
	}
	
	Log.logWarning("Removed: " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName());
}
