/**
 * Industry node which contains all information about an industry and its connections
 * to other industries and / or towns.
 */
class ConnectionNode
{
	static INDUSTRY_NODE = "i";
	static TOWN_NODE = "t";
	
	nodeType = null;                        // The type of node (one of above).
	id = null;                              // The ID of the town or industry.
	cargoIdsProducing = null;               // The cargo IDs which are produced.
	cargoIdsAccepting = null;               // The cargo IDs which are accepted.

	connectionNodeList = null;              // All nodes which accept the cargos this node produces.
	connectionNodeListReversed = null;      // All nodes which this node accepts cargo from.

	connections = null;                     // Running connections to other nodes.
	isNearWater = false;			// Is this node near water?

	bestReports = null;			// The best report to serve this connection node.
	activeConnections = null;	// The connections which serves this connection node.
	reverseActiveConnections = null;	// The connections this connection node is served by.
	isInvalid = null;

	/**
	 * Construct a new connection node with the given ID an type.
	 * @param nodeType Determines whether this node is a town or industry.
	 * @param id The ID of the industry or town.
	 */
	constructor(nodeType, id) {
		this.nodeType = nodeType;
		this.id = id;
		cargoIdsProducing = [];
		cargoIdsAccepting = [];
		activeConnections = [];
		reverseActiveConnections = [];
		connectionNodeList = [];
		connectionNodeListReversed = [];
		connections = {};
		bestReports = [];
		isInvalid = false;
	}

	/**
	 * Get the location of this node.
	 * @return The tile location of this node.
	 */
	function GetLocation();
	function GetProducingTiles(cargoID, stationRadius, stationSizeX, stationSizeY);
	function GetAcceptingTiles(cargoID, stationRadius, stationSizeX, stationSizeY);
	function GetAllProducingTiles(cargoID, stationRadius, stationSizeX, stationSizeY) { return GetProducingTiles(cargoID, stationRadius, stationSizeX, stationSizeY); }
	function GetAllAcceptingTiles(cargoID, stationRadius, stationSizeX, stationSizeY) { return GetAcceptingTiles(cargoID, stationRadius, stationSizeX, stationSizeY); }
	function GetName();	
}
	
/**
 * Add a new connection from this industry to one of its children.
 */
function ConnectionNode::AddConnection(connectionNode, connection) {
	if (connections.rawin(connectionNode.GetUID(connection.cargoID)))
		assert(false);
	connections[connectionNode.GetUID(connection.cargoID)] <- connection;
}

/**
 * Return the connection between this node and another.
 * @param connectionNode A ConnectionNode instance.
 * @return null if the connection doesn't exists, else the connection.
 */
function ConnectionNode::GetConnection(connectionNode, cargoID) {
	if (connections.rawin(connectionNode.GetUID(cargoID)))
		return connections.rawget(connectionNode.GetUID(cargoID));
	return null;
}
	
/**
 * Return an array of connections.
 * @param cargoID The type of cargo of those connections.
 * @return An array with connections which transport the given cargoID.
 */
function ConnectionNode::GetConnections(cargoID) {
	local connectionArray = [];
	
	foreach (connection in connections)
		if (connection.cargoID == cargoID)
			connectionArray.push(connection);
	
	return connectionArray;
}

/**
 * Return the array of all connections.
 * @return The array with connections which transport the given cargoID.
 */
function ConnectionNode::GetAllConnections() {
	return connections;
}

/**
 * Return the best report for a certain cargo type.
 * @param cargoID The cargo ID of which we want the best report from.
 * @return The best report transporting the given cargo ID. Null if no
 * report is found.
 */
function ConnectionNode::GetBestReport(cargoID) {
	foreach (report in bestReports)
		if (report.connection.cargoID == cargoID)
			return report;
	return null;
}

/**
 * Add a best report to the list of best reports, if a report already
 * exists for the same cargo we replace it.
 * @param report The new best report.
 */
function ConnectionNode::AddBestReport(report) {
	for (local i = 0; i < bestReports.len(); i++) {
		if (bestReports[i].connection.cargoID == report.connection.cargoID) {
			bestReports[i] = report;
			return;
		}
	}
	bestReports.push(report);
}

/**
 * Get the unique name of this connectionNode which is used for a connection
 * to this node with a certain cargoID.
 * @param cargoID The cargo ID which is transported to this connection node.
 * @return The string which is unique for this connection.
 */
function ConnectionNode::GetUID(cargoID) {
	return nodeType + id + "_" + cargoID;
}

/**
 * Get the town or industry ID from the UID.
 * @param UID The UID from which to get the ID.
 * @return the town or industry ID or -1 if it's not a valid UID.
 */
function ConnectionNode::GetIDFromUID(UID)
{
	local underscore = UID.find("_");
	if (underscore == null)
		return -1;
	return UID.slice(1,underscore).tointeger();
}

/**
 * Get node type from UID.
 * @param UID The UID from which to get the ID.
 * @return The nodeType.
 */
function ConnectionNode::GetNodeTypeFromUID(UID)
{
	return UID.slice(0,1);
}
