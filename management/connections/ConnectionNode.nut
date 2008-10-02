/**
 * Industry node which contains all information about an industry and its connections
 * to other industries.
 */
class ConnectionNode
{
	static INDUSTRY_NODE = "i";
	static TOWN_NODE = "t";
	
	nodeType = null;				// The type of node (one of above).
	id = null;						// The ID of the town or industry.
	cargoIdsProducing = null;		// The cargo IDs which are produced.
	cargoIdsAccepting = null;		// The cargo IDs which are accepted.

	connectionNodeList = null;		// All nodes which accepts the products this node produces.
	connectionNodeListReversed = null;	// All nodes which this noded accepts cargo from.

	connections = null;				// Running connections to other nodes.

	constructor(nodeType, id) {
		this.nodeType = nodeType;
		this.id = id;
		cargoIdsProducing = [];
		cargoIdsAccepting = [];
		connectionNodeList = [];
		connectionNodeListReversed = [];
		connections = {};
	}
	/**
	 * Get the location of this node.
	 * @return The tile location of this node.
	 */
	function GetLocation();
	function GetProducingTiles(cargoID);
	function GetAcceptingTiles(cargoID);
	function GetName();	
}
	
/**
 * Add a new connection from this industry to one of its children.
 */
function ConnectionNode::AddConnection(connectionNode, connection) {
	connections[connectionNode.nodeType + connectionNode.id + "_" + connection.cargoID] <- connection;
}

/**
 * Return the connection between this node and another.
 * @param connectionNode A ConnectionNode instance.
 * @return null if the connection doesn't exists, else the connection.
 */
function ConnectionNode::GetConnection(connectionNode, cargoID) {
	if (connections.rawin(connectionNode.nodeType + connectionNode.id + "_" + cargoID))
		return connections.rawget(connectionNode.nodeType + connectionNode.id + "_" + cargoID);
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
