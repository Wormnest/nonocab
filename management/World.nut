/**
 * World holds the current status of the world as the AI sees it.
 */
class World
{

	town_list = null;				// List with all towns.
	good_town_list = null;			    // List with intressing towns.
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
		this.town_list = AITownList();
		this.good_town_list = [];
		industry_list = AIIndustryList();
		cargoTransportEngineIds = array(AICargoList().Count(), -1);
		BuildIndustryTree();
		InitEvents();
		InitCargoTransportEngineIds();		
	}
}
/**
 * Updates the view on the world.
 */
function World::Update()
{
	UpdateEvents();
	SetGoodTownList();
	UpdateIndustryTree(industry_tree);
}

/**
 * Update the industry tree by updating the production rates
 * of all industries.
 * @param industryTree An array of connection nodes which need to be updated.
 */
function World::UpdateIndustryTree(industryTree)
{
	foreach (connectionNode in industryTree) {
		if (connectionNode.nodeType != ConnectionNode.INDUSTRY_NODE)
			continue;
			
		local i = 0;
		foreach (cargoID in connectionNode.cargoIdsProducing) {
			connectionNode.cargoProducing[i] = AIIndustry.GetProduction(connectionNode.id, cargoID)
		}
		
		Log.logDebug("Update " + connectionNode.GetName());
		
		UpdateIndustryTree(connectionNode.connectionNodeList);
	}
}

/**
 * Build a tree of all industry nodes, where we connect each producing
 * industry to an industry which accepts that produced cargo. The primary
 * industries (ie. the industries which only produce cargo) are the root
 * nodes of this tree.
 */
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

		
		InsertIndustry(industry);
	}
	
	// Now handle the connection Industry --> Town
	foreach (town, value in town_list) {
		
		local townNode = TownConnectionNode(town);
		
		// Check if this town accepts something an industry creates.
		foreach (cargo, value in cargos) {
			if (AITile.GetCargoAcceptance(townNode.GetLocation(), cargo, 1, 1, 1)) {
				
				// Check if we have an industry which actually produces this cargo.
				foreach (industryNode in industryCacheAccepting[cargo]) {
					industryNode.connectionNodeList.push(townNode);
				}
			}
		}
	}
}

/**
 * Insert an industryNode in the industryList.
 * @industryID The id of the industry which needs to be added.
 */
function World::InsertIndustry(industryID)
{
	local cargos = AICargoList();
	local industryNode = IndustryConnectionNode(industryID);
	
	// Check which cargo is accepted.
	foreach (cargo, value in cargos) {

		// Check if the industry actually accepts something.
		if (AIIndustry.IsCargoAccepted(industryID, cargo)) {
			industryNode.cargoIdsAccepting.push(cargo);

			// Add to cache.
			industryCacheAccepting[cargo].push(industryNode);

			// Check if there are producing plants which this industry accepts.
			for (local i = 0; i < industryCacheProducing[cargo].len(); i++) {
				industryCacheProducing[cargo][i].connectionNodeList.push(industryNode);
			}
		}

		if (AIIndustry.GetProduction(industryID, cargo) != -1) {	

			// Save production information.
			industryNode.cargoIdsProducing.push(cargo);
			industryNode.cargoProducing.push(AIIndustry.GetProduction(industryID, cargo));

			// Add to cache.
			industryCacheProducing[cargo].push(industryNode);

			// Check for accepting industries for these products.
			for (local i = 0; i < industryCacheAccepting[cargo].len(); i++) {
				industryNode.connectionNodeList.push(industryCacheAccepting[cargo][i]);
			}
		}
	}

	// If the industry doesn't accept anything we add it to the root list.
	if (industryNode.cargoIdsAccepting.len() == 0) {
		industry_tree.push(industryNode);
	}	
}

/**
 * Remove an industryNode from the industryList.
 * @industryID The id of the industry which needs to be removed.
 */
function World::RemoveIndustry(industryID) {
	Log.logWarning("World::RemoveIndustry is not yet implemented!");
}

/**
 * Check all available vehicles to transport all sorts of cargos and save
 * the max speed of the fastest transport for each cargo.
 *
 * Update the engine IDs for each cargo type and select the fastest engines.
 */
function World::InitCargoTransportEngineIds() {

	local cargos = AICargoList();
	foreach (cargo, value in cargos) {

		local engineList = AIEngineList(AIVehicle.VEHICLE_ROAD);
		foreach (engine, value in engineList) {
			if (AIEngine.GetCargoType(engine) == cargo && 
				AIEngine.GetMaxSpeed(cargoTransportEngineIds[cargo]) < AIEngine.GetMaxSpeed(engine)) {
				cargoTransportEngineIds[cargo] = engine;
			}
		}
	}
	
	// Check
	for(local i = 0; i < cargoTransportEngineIds.len(); i++) {
		Log.logDebug("Use engine: " + AIEngine.GetName(cargoTransportEngineIds[i]) + " for cargo: " + AICargo.GetCargoLabel(i));
	}
}

/**
 * Enable the event system and mark which events we want to be notified about.
 */
function World::InitEvents() {
	AIEventController.DisableAllEvents();
	AIEventController.EnableEvent(AIEvent.AI_ET_ENGINE_AVAILABLE);
	AIEventController.EnableEvent(AIEvent.AI_ET_INDUSTRY_OPEN);
	AIEventController.EnableEvent(AIEvent.AI_ET_INDUSTRY_CLOSE);
}

/**
 * Check all events which are waiting and handle them properly.
 */
function World::UpdateEvents() {
	while (AIEventController.IsEventWaiting()) {
		local e = AIEventController.GetNextEvent();
		switch (e.GetEventType()) {
			
			/**
			 * As a new engine becomes available, consider if we want to use it.
			 */
			case AIEvent.AI_ET_ENGINE_AVAILABLE:
				local newEngineID = AIEventEngineAvailable.Convert(e).GetEngineID();
				local cargoID = AIEngine.GetCargoType(newEngineID);
				local oldEngineID = cargoTransportEngineIds[cargoID];
				
				if (AIEngine.GetMaxSpeed(newEngineID) > AIEngine.GetMaxSpeed(oldEngineID)) {
					Log.logInfo("Replaced " + AIEngine.GetName(oldEngineID) + " with " + AIEngine.GetName(newEngineID));
					cargoTransportEngineIds[cargoID] = newEngineID;
				}
				break;
				
			/**
			 * Add a new industry to the industry list.
			 */
			case AIEvent.AI_ET_INDUSTRY_OPEN:
				industry_list = AIIndustryList();
				local industryID = AIEventIndustryOpen.Convert(e).GetIndustryID();
				InsertIndustry(industryID);
				Log.logInfo("New industry: " + AIIndustry.GetName(industryID) + " added to the world!");
				break;
				
			/**
			 * Remove a new industry to the industry list.
			 */
			case AIEvent.AI_ET_INDUSTRY_CLOSE:
				industry_list = AIIndustryList();
				local industryID = AIEventIndustryClose.Convert(e).GetIndustryID();
				RemoveIndustry(industryID);
				break;
		}
	}
}


/**
 * Analizes all available towns and updates the list with good ones.  
 */
function World::SetGoodTownList()
{
	local MINIMUM_CITY_SIZE = 512;
	local MINIMUM_PASS_PRODUCTION = 50;
	local MINIMUM_MAIL_PRODUCTION = 50;
	local MINIMUM_ARMO_PRODUCTION = 25;
	
	Log.logInfo("Add new towns.");
	
	// TODO rest for debuging;
	// CN: ik heb geen idee waarom Is InArray faalt. Daarom, tijderlijk elke keer opnieuw :S
	this.good_town_list = [];
	
	Log.logInfo("There are " + this.town_list.Count() + " available towns.");

	foreach(town, value in this.town_list)
	{
		//Log.logDebug(town);
		//Log.logDebug(value);
		// Only check cities who are big enough.
		if(AITown.GetPopulation(town) > MINIMUM_CITY_SIZE &&
			/*!IsInArray(this.good_town_list, town) && */(
			// If we have a statue they should like us
			AITown.HasStatue(town) ||
			// we like to deliver something anyway.
			AITown.GetMaxProduction(town, AICargo.CC_PASSENGERS ) > MINIMUM_PASS_PRODUCTION ||
			AITown.GetMaxProduction(town, AICargo.CC_MAIL) > MINIMUM_MAIL_PRODUCTION ||
			AITown.GetMaxProduction(town, AICargo.CC_ARMOURED) > MINIMUM_ARMO_PRODUCTION
			))
		{
			Log.logDebug(AITown.GetName(town) + " (" +
			AITown.GetPopulation(town) +
				"), Pass: " + AITown.GetMaxProduction(town, AICargo.CC_PASSENGERS) +
				", Mail: " + AITown.GetMaxProduction(town, AICargo.CC_MAIL) +
				", Armo: " + AITown.GetMaxProduction(town, AICargo.CC_ARMOURED));
			this.good_town_list.push(town);
		}
	}
	Log.logInfo("There are " + this.good_town_list.len() + " good towns.");
}