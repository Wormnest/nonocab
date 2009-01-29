/**
 * This class handles all new aircraft connections. For the moment we only focus on 
 * town <-> town connections, see UpdateIndustryConnections for more details.
 */
class AircraftAdvisor extends ConnectionAdvisor {

	constructor (world, vehicleAdvisor) {
		ConnectionAdvisor.constructor(world, AIVehicle.VT_AIR, vehicleAdvisor);
	}
}

function AircraftAdvisor::GetBuildAction(connection) {
	return BuildAirfieldAction(connection, world, vehicleAdvisor);
}

function AircraftAdvisor::GetPathInfo(report) {
	return PathInfo(null, 0);
}

/**
 * We implement our own update industry connection function, becaus we only consider town <-> town
 * connections for airplanes. Other connections will be explored if this function is commented out,
 * but so far I've never seen an aircraft which carries other cargo other then passengers and mail.
 * Trains will be far better at this job :).

function AircraftAdvisor::UpdateIndustryConnections(industry_tree) {

	foreach (from in world.townConnectionNodes) {
		foreach (to in from.connectionNodeList) {
			
			// See if we need to add or remove some vehicles.
			// Take a guess at the travel time and profit for each cargo type.
			foreach (cargoID in from.cargoIdsProducing) {

				if (!AICargo.HasCargoClass(cargoID, AICargo.CC_PASSENGERS))
					continue;

				// Check if we even have an engine to transport this cargo.
				local engineID = world.cargoTransportEngineIds[vehicleType][cargoID];
				if (engineID == -1)
					continue;

				// Check if this connection already exists.
				local connection = from.GetConnection(to, cargoID);

				// Make sure we only check the accepting side for possible connections if
				// and only if it has a connection to it.
				if (connection != null && connection.pathInfo.build)
					continue;

				// Check if this connection isn't in the ignore table.
				if (ignoreTable.rawin(from.GetUID(cargoID) + "_" + to.GetUID(cargoID)))
					continue;

				if (connection == null) {

					local skip = false;

					// Make sure the producing side isn't already served, we don't want more then
					// 1 connection on 1 production facility per cargo type.
					local otherConnections = from.GetConnections(cargoID);
					foreach (otherConnection in otherConnections) {
						if (otherConnection.pathInfo.build && otherConnection != connection) {
							skip = true;
							break;
						}
					}
				
					if (skip)
						continue;
				}
				local report = ConnectionReport(world, from, to, cargoID, engineID, 0);
				if (report.Utility() > 0)
					connectionReports.Insert(report, -report.Utility());
			}
		}
	}
} */
