/**
 * Information for a vehicle group which runs a certain connection.
 */
class Connection
{
	// Type of connection.
	static INDUSTRY_TO_INDUSTRY = 1;
	static INDUSTRY_TO_TOWN = 2;
	static TOWN_TO_TOWN = 3;
	
	connectionType = null;		// The type of connection (one of above).
	cargoID = null;				// The type of cargo carried from one node to another.
	travelFromNode = null;		// The node the cargo is carried from.
	travelToNode = null;		// The node the cargo is carried to.
	vehiclesOperating = null;	// List of VehicleGroup instances to keep track of all vehicles on this connection.
	pathInfo = null;			// PathInfo class which contains all information about the path.
	bilateralConnection = null;	// If this is true, cargo is carried in both directions.
	
	constructor(fromNode, toNode, type) {
		connectionType = type;
		travelFromNode = fromNode;
		travelToNode = toNode;
		vehiclesOperating = [];
	}
}