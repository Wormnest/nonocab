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
	if (AICargo.HasCargoClass(report.cargoID, AICargo.CC_MAIL))
		return null;
	
	// Check if the airport is actually constructable!
	local bestAirfield = BuildAirfieldAction.GetLargestAirport(false);
	if (bestAirfield == null)
		return null;

	local townToTown = report.fromConnectionNode.nodeType == ConnectionNode.TOWN_NODE && report.toConnectionNode.nodeType == ConnectionNode.TOWN_NODE;
	if (!BuildAirfieldAction.FindSuitableAirportSpot(bestAirfield, report.fromConnectionNode, report.cargoID, false, true, townToTown) == -1 ||
		!BuildAirfieldAction.FindSuitableAirportSpot(bestAirfield, report.toConnectionNode, report.cargoID, true, true, townToTown) == -1)
		return null;
			
	return PathInfo(null, null, 0, AIVehicle.VT_AIR);
}