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

/**
 * Information for an individual vehicle which runs a certain connection. All
 * inforamtion is dependend on the actual speed of each individual vehicle.
 */
class IndustryConnection
{
	cargoID = null;				// The type of cargo carried from on industry to another.
	travelFromIndustryNode = null;		// The industry the cargo is carried from.
	travelToIndustryNode = null;		// The industry the cargo is carried to.
	vehiclesOperating = null;		// List of VehicleGroup instances to keep track of all vehicles on this connection.
	costToBuild = null;			// The cost to build this connection.
	build = null;				// Only true if this connection has been build.
	
	constructor(fromIndustry, toIndustry) {
		travelFromIndustryNode = fromIndustry;
		travelToIndustryNode = toIndustry;
		vehiclesOperating = [];
		build = false;
	}
}

/**
 * In order to build and maintain connections between industries we keep track
 * of all vehicles on those connections and their status.
 */
class VehicleGroup
{
	timeToTravelTo = null;			// Time in days it takes all vehicles in this group to 
						// travel from the accepting industry to the producing
						// industry.
	timeToTravelFrom = null;		// Time in days it takes all vehicles in this group to 
						// travel from the producing industry to the accepting
						// industry.
	incomePerRun = null;			// The average income per vehicle per run.
	engineID = null;			// The engine ID of all vehicles in this group.
	industryConnection = null;		// The industry connection all vehicles in this group
						// are operating on.
	vehicleIDs = null;			// All vehicles IDs of this group.
	
	constructor() {
		vehicleIDs = [];
	}
}
