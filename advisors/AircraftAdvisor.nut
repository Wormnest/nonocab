/**
 * This class handles all new aircraft connections. For the moment we only focus on 
 * town <-> town connections, see UpdateIndustryConnections for more details.
 */
class AircraftAdvisor extends ConnectionAdvisor {

	constructor (world, connectionManager) {
		ConnectionAdvisor.constructor(world, AIVehicle.VT_AIR, connectionManager);
	}
}

function AircraftAdvisor::GetBuildAction(connection) {
	return BuildAirfieldAction(connection, world);
}

function AircraftAdvisor::GetPathInfo(report) {
	
	// We don't do mail! :X
	if (AICargo.HasCargoClass(report.connection.cargoID, AICargo.CC_MAIL))
		return null;
	
	local townToTown = report.connection.travelFromNode.nodeType == ConnectionNode.TOWN_NODE && report.connection.travelToNode.nodeType == ConnectionNode.TOWN_NODE;
	if (!BuildAirfieldAction.FindSuitableAirportSpot(report.connection.travelFromNode, report.connection.cargoID, false, true, townToTown) ||
		!BuildAirfieldAction.FindSuitableAirportSpot(report.connection.travelToNode, report.connection.cargoID, true, true, townToTown))
		return null;
			
	return PathInfo(null, null, 0, AIVehicle.VT_AIR);
}
