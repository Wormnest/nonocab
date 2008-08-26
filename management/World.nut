/**
 * World holds the current status of the world as the AI sees it.
 */
class World
{

	town_list = null;				// List with all towns.
	connection_list = null;				// List with all active connections.
	industry_list = null;				// Tree with all industries and their interconnections.

	/**
	 * Initializes a repesentation of the 'world'.
	 */
	constructor()
	{
		town_list = AITownList();
		connection_list = [];
		
		// Construct complete industry node list.
		local industries = AIIndustryList();
		local cargos = AICargoList();
		local industryCacheAccepting = array(cargos.Count());
		local industryCacheProducing = array(cargos.Count());

		industry_list = [];

		// Fill the arrays with empty arrays, we can't use:
		// local industryCacheAccepting = array(cargos.Count(), [])
		// because it will all point to the same empty array...
		for (local i = 0; i < cargos.Count(); i++) {
			industryCacheAccepting[i] = [];
			industryCacheProducing[i] = [];
		}
		
		// For each industry we will determine all possible connections to other
		// industries which accept its goods. We build a tree structure in which
		// the root nodes consist of industry nodes who only produce products but
		// don't accept anything (the so called primary industries). The children
		// of these nodes are indutries which only accept goods which the root nodes
		// produce, and so on.
		//
		// Primary economies -> Secondary economies -> ... -> Towns
		// Town <-> town
		//
		//
		// Every industry is stored in an IndustryNode.
		foreach (industry, value in industries) {

			local industryNode = IndustryNode();
			industryNode.industryID = industry;

			// Check which cargo is accepted.
			foreach (cargo, value in cargos) {

				// Check if the industry actually accepts something.
				if (AIIndustry.IsCargoAccepted(industry, cargo)) {
					industryNode.cargoIdsAccepting.push(cargo);

					// Add to cache.
					industryCacheAccepting[cargo].push(industryNode);

					// Check if there are producing plants which this industry accepts.
					for (local i = 0; i < industryCacheProducing[cargo].len(); i++) {
						industryCacheProducing[cargo][i].industryNodeList.push(industryNode);
					}
				}

				if (AIIndustry.GetProduction(industry, cargo) != -1) {	

					// Save production information.
					industryNode.cargoIdsProducing.push(cargo);
					industryNode.cargoProducing.push(AIIndustry.GetProduction(industry, cargo));

					// Add to cache.
					industryCacheProducing[cargo].push(industryNode);

					// Check for accepting industries for these products.
					for (local i = 0; i < industryCacheAccepting[cargo].len(); i++) {
						industryNode.industryNodeList.push(industryCacheAccepting[cargo][i]);
					}
				}
			}

			// If the industry doesn't accept anything we add it to the root list.
			if (industryNode.cargoIdsAccepting.len() == 0) {
				industry_list.push(industryNode);
			}
		}		
	}



	/**
	 * Debug purposes only.
	 */
	function PrintTree() {
		print("PrintTree");
		foreach (primIndustry in industry_list) {
			PrintNode(primIndustry, 0);
		}
		print("Done!");
	}

	function PrintNode(node, depth) {
		local string = "";
		for (local i = 0; i < depth; i++) {
			string += "      ";
		}

		print(string + AIIndustry.GetName(node.industryID) + " -> ");

		foreach (transport in node.industryConnections) {
			print("Vehcile travel time: " + transport.timeToTravelTo);
			//print("Vehcile income per run: " + transport.incomePerRun);
			print("Cargo: " + AICargo.GetCargoLabel(transport.cargoID));
			print("Cost: " + node.costToBuild);
		}
		foreach (iNode in node.industryNodeList)
			PrintNode(iNode, depth + 1);
	}
}


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
}

/**
 * Information for an individual vehicle which runs a certain connection. All
 * inforamtion is dependend on the actual speed of each individual vehicle.
 */
class IndustryConnection
{
	cargoID = null;				// The type of cargo carried from on industry to another.
	travelFromIndustry = null;		// The industry the cargo is carried from.
	travelToIndustry = null;		// The industry the cargo is carried to.
	vehiclesOperating = null;		// List of VehicleGroup instances to keep track of all vehicles on this connection.
	costToBuild = null;			// The cost to build this connection.
	build = null;				// Only true if this connection has been build.
	
	constructor() {
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