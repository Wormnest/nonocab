/**
 * Information for a vehicle group which runs a certain connection.
 */
class Connection
{
	// Type of connection.
	static INDUSTRY_TO_INDUSTRY = 1;
	static INDUSTRY_TO_TOWN = 2;
	static TOWN_TO_TOWN = 3;
	static TOWN_TO_SELF = 4;
	
	connectionType = null;		// The type of connection (one of above).
	cargoID = null;				// The type of cargo carried from one node to another.
	travelFromNode = null;		// The node the cargo is carried from.
	travelToNode = null;		// The node the cargo is carried to.
	vehiclesOperating = null;	// List of VehicleGroup instances to keep track of all vehicles on this connection.
	pathInfo = null;			// PathInfo class which contains all information about the path.
	bilateralConnection = null;	// If this is true, cargo is carried in both directions.
	
	constructor(cargo_id, travel_from_node, travel_to_node, path_info, bilateral_connection) {
		cargoID = cargo_id;
		travelFromNode = travel_from_node;
		travelToNode = travel_to_node;
		pathInfo = path_info;
		bilateralConnection = bilateral_connection;
		
		if (travelFromNode.nodeType == ConnectionNode.INDUSTRY_NODE) {
			if (travelToNode.nodeType == ConnectionNode.INDUSTRY_NODE) {
				connectionType = INDUSTRY_TO_INDUSTRY;
			} else {
				connectionType = INDUSTRY_TO_TOWN;
			}
		}
		else {
			if(travelFromNode == travelToNode) {
				connectionType = TOWN_TO_SELF;	
			}
			else{
				connectionType = TOWN_TO_TOWN;
			}
		}
		vehiclesOperating = [];
	}
	
	/**
	 * Based on this connection get a report which tells how many vehicles
	 * of type engineID are supported on top of the already existing fleet of
	 * vehicles.
	 * @param world The world.
	 * @param enginID The engine id to build.
	 * @return A ConnectionReport instance.
	 */
	function CompileReport(world, engineID) {
		// First we check how much we already transport.
		// Check if we already have vehicles who transport this cargo and deduce it from 
		// the number of vehicles we need to build.
		local cargoAlreadyTransported = 0;
		foreach (connection in travelFromNode.connections) {
			if (connection.cargoID == cargoID) {
				foreach (vehicleGroup in connection.vehiclesOperating) {
					cargoAlreadyTransported += vehicleGroup.vehicleIDs.len() * (World.DAYS_PER_MONTH / (vehicleGroup.timeToTravelTo + vehicleGroup.timeToTravelFrom)) * AIEngine.GetCapacity(vehicleGroup.engineID);
				}
			}
		}
	
		return ConnectionReport(world, travelFromNode, travelToNode, cargoID, engineID, cargoAlreadyTransported);
	}			
}