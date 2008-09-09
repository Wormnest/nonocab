/**
 * Industry node which contains all information about an industry and its connections
 * to other industries.
 */
class IndustryNode
{
	industryID = null;			// The ID of the industry.
	cargoIdsProducing = null;		// The cargo IDs which are produced.
	cargoIdsAccepting = null;		// The cargo IDs which are accepted.

	cargoProducing = null;			// The amount of cargo produced.
	industryNodeList = null;		// All industry which accepts the products this industry produces.

	industryConnections = null;		// Running connections to other industries.

	constructor() {
		cargoIdsProducing = [];
		cargoIdsAccepting = [];
		cargoProducing = [];
		industryNodeList = [];
		industryConnections = {};
	}
	
	/**
	 * Add a new connection from this industry to one of its children.
	 */
	function AddIndustryConnection(industryNode, industryConnection) {
		industryConnections["" + industryNode.industryID] <- industryConnection;
	}
	
	/**
	 * Return the connection between two industries (if it exists).
	 */
	function GetIndustryConnection(industryID) {
		if (industryConnections.rawin("" + industryID))
			return industryConnections.rawget("" + industryID);
		return null;
	}
}
