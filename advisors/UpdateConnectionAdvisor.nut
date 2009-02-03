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
	
	constructor(world) {
		Advisor.constructor(world);
		connections = [];
		reports = [];
	}
}

function UpdateConnectionAdvisor::Update(loopCounter) {
	
	reports = [];

	foreach (connection in connections) {

		// If the road isn't build we can't micro manage, move on!		
		assert (connection.pathInfo.build);
		
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
			
		Log.logDebug("Report an update from: " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " with " + report.nrVehicles + " vehicles! Utility: " + report.Utility());
		local actionList = [];
	
		// Fix report.

		// Create a report and store it!
		reportsToReturn.push(report);
	}
	
	return reportsToReturn;
}

// Functions related to the interface ConnectionListener.
function UpdateConnectionAdvisor::ConnectionRealised(connection) {
	connections.push(connection);
}

function UpdateConnectionAdvisor::ConnectionDemolished(connection) {
	for (local i = 0; i < connections.len(); i++) {
		if (connections[i] == connection) {
			connection.remove(i);
			break;
		}
	}
}
