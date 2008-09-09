/**
 * World holds the current status of the world as the AI sees it.
 */
class World
{

	town_list = null;				// List with all towns.
	industry_list = null;			// List with all industries.

	cargoTransportEngineIds = null;		// The fastest engine IDs to transport the cargos.

	industry_tree = null;
	industryCacheAccepting = null;
	industryCacheProducing = null;

	/**
	 * Initializes a repesentation of the 'world'.
	 */
	constructor()
	{
		town_list = AITownList();
		industry_list = AIIndustryList();
		cargoTransportEngineIds = array(AICargoList().Count(), -1);
		BuildIndustryTree();
	}
	
	function Update() {}
	
	
	/**
	 * Build a tree of all industry nodes, where we connect each producing
	 * industry to an industry which accepts that produced cargo. The primary
	 * industries (ie. the industries which only produce cargo) are the root
	 * nodes of this tree.
	 */
	function BuildIndustryTree();

		
	/**
	 * Update the engine IDs for each cargo type and select the fastest engines.
	 */
	function UpdateCargoTransportEngineIds();
}

function World::BuildIndustryTree() {
	// Construct complete industry node list.
	local industries = industry_list;
	local cargos = AICargoList();
	industryCacheAccepting = array(cargos.Count());
	industryCacheProducing = array(cargos.Count());

	industry_tree = [];

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
			industry_tree.push(industryNode);
		}
	}
}

/**
 * Check all available vehicles to transport all sorts of cargos and save
 * the max speed of the fastest transport for each cargo.
 */
function World::UpdateCargoTransportEngineIds() {

	local cargos = AICargoList();
	local i = 0;
	foreach (cargo, value in cargos) {

		local engineList = AIEngineList(AIVehicle.VEHICLE_ROAD);
		foreach (engine, value in engineList) {
			if (AIEngine.GetCargoType(engine) == cargo&& 
				AIEngine.GetMaxSpeed(cargoTransportEngineIds[i]) < AIEngine.GetMaxSpeed(engine)) {
				cargoTransportEngineIds[i] = engine;
			}
		}
		i++;
	}
}
