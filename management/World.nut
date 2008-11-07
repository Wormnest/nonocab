/**
 * World holds the current status of the world as the AI sees it.
 */
class World
{
	static DAYS_PER_MONTH = 30.0;
	static DAYS_PER_YEAR = 364.0;
	static MONTHS_PER_YEAR = 12.0;
	static MONTHS_BEFORE_AUTORENEW = 144; // 12 years
	
	town_list = null;				// List with all towns.
	industry_list = null;			// List with all industries.
	industry_table = null;			// Table with all industries.
	cargo_list = null;				// List with all cargos.
	townConnectionNodes = null;

	cargoTransportEngineIds = null;		// The fastest engine IDs to transport the cargos.

	industry_tree = null;
	industryCacheAccepting = null;
	industryCacheProducing = null;
	
	starting_year = null;
	years_passed = null;
	
	max_distance_between_nodes = null;		// The maximum distance between industries.
	
	// Does this belong here!?!?!
	pathFixer = null;						// The instance to call when paths needs to be fixed.

	/**
	 * Initializes a repesentation of the 'world'.
	 */
	constructor()
	{
		this.townConnectionNodes = [];
		this.starting_year = AIDate.GetYear(AIDate.GetCurrentDate());
		this.years_passed = 0;
		this.town_list = AITownList();
		town_list.Valuate(AITown.GetPopulation);
		town_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
		industry_table = {};
		industry_list = AIIndustryList();
		
		
		// Construct complete industry node list.
		cargo_list = AICargoList();
		cargo_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
		local nr_of_cargoes = cargo_list.Begin();
		industryCacheAccepting = array(nr_of_cargoes + 1);
		industryCacheProducing = array(nr_of_cargoes + 1);
		
		cargoTransportEngineIds = array(4);
		for (local i = 0; i < cargoTransportEngineIds.len(); i++) 
			cargoTransportEngineIds[i] = array(nr_of_cargoes + 1, -1);
	
		industry_tree = [];
	
		// Fill the arrays with empty arrays, we can't use:
		// local industryCacheAccepting = array(cargos.Count(), [])
		// because it will all point to the same empty array...
		foreach (index, value in cargo_list) {
			industryCacheAccepting[index] = [];
			industryCacheProducing[index] = [];
		}		
		
		BuildIndustryTree();
		max_distance_between_nodes = 128;
		InitEvents();
		InitCargoTransportEngineIds();
		
		AICompany.SetAutoRenewMonths(MONTHS_BEFORE_AUTORENEW);
		AICompany.SetAutoRenewStatus(true);
	}
	
	
	/**
	 * Debug purposes only:
	 * Print the constructed industry node.
	 */
	//function PrintTree();
	
	/**
	 * Debug purposes only:
	 * Print a single node in the industry tree.
	 */
	//function PrintNode();	
}

/**
 * Updates the view on the world.
 */
function World::Update()
{
	UpdateEvents();

	if (AIDate.GetYear(AIDate.GetCurrentDate()) - starting_year > 2) {
		IncreaseMaxDistanceBetweenNodes();
		starting_year = AIDate.GetYear(AIDate.GetCurrentDate());
	}
	
	// Check if we have any vehicles to sell! :)
	local vehicleList = AIVehicleList();
	foreach (vehicleID, value in vehicleList) {
		if (AIVehicle.IsStoppedInDepot(vehicleID)) {
			AIVehicle.SellVehicle(vehicleID);
		}
		
		// Check if the vehicle is profitable.
		if (AIVehicle.GetAge(vehicleID) > DAYS_PER_YEAR * 2 && AIVehicle.GetProfitLastYear(vehicleID) < 0)
			AIVehicle.SendVehicleToDepot(vehicleID);
	}
}

/**
 * Manually increase the maximum distance between industries / towns. We need
 * this because sometimes the advisors have already build all possible connections
 * and are eager for more!
 */
function World::IncreaseMaxDistanceBetweenNodes()
{
	if (max_distance_between_nodes > AIMap.GetMapSizeX() + AIMap.GetMapSizeY()) {
//		Log.logDebug("Max distance reached its max!");
		return;
	}
	max_distance_between_nodes += 32;
	Log.logDebug("Increased max distance to: " + max_distance_between_nodes);
}

/**
 * Build a tree of all industry nodes, where we connect each producing
 * industry to an industry which accepts that produced cargo. The primary
 * industries (ie. the industries which only produce cargo) are the root
 * nodes of this tree.
 */
function World::BuildIndustryTree() {

	Log.logDebug("Build industry tree");
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
	foreach (industry, value in industry_list) {
		InsertIndustry(industry);
	}
	
	// Now handle the connections Industry --> Town
	foreach (town, value in town_list) {
		
		local townNode = TownConnectionNode(town);
		
		// Check if this town accepts something an industry creates.
		foreach (cargo, value in cargo_list) {
			if (AITile.GetCargoAcceptance(townNode.GetLocation(), cargo, 1, 1, 1)) {
				
				// Check if we have an industry which actually produces this cargo.
				foreach (connectionNode in industryCacheProducing[cargo]) {
					connectionNode.connectionNodeList.push(townNode);
				}
			}
		
		}

		// Add town <-> town connections, we only store these connections as 1-way directions
		// because they are bidirectional.
		foreach (townConnectionNode in townConnectionNodes) {
			townNode.connectionNodeList.push(townConnectionNode);
			
			foreach (cargo, value in cargo_list) {
				if (AITown.GetMaxProduction(townNode.id, cargo) + AITown.GetMaxProduction(townConnectionNode.id, cargo) > 0) {
					
					local doAdd = true;
					foreach (c in townNode.cargoIdsProducing) {
						if (c == cargo) {
							doAdd = false;
							break;
						}
					}
					
					if (!doAdd)
						continue;

					townNode.cargoIdsProducing.push(cargo);
					townNode.cargoIdsAccepting.push(cargo);
				}
			}
		}

		townConnectionNodes.push(townNode);
		industry_tree.push(townNode);
	}
}

/**
 * Insert an industryNode in the industryList.
 * @industryID The id of the industry which needs to be added.
 */
function World::InsertIndustry(industryID) {

	local industryNode = IndustryConnectionNode(industryID);
	
	// Make sure this industry hasn't already been added.
	if (!industry_table.rawin(industryID))
		industry_table[industryID] <- industryNode;
	else
		return;

	local hasBilateral = false;
	
	// Check which cargo is accepted.
	foreach (cargo, value in cargo_list) {

		local isBilateral = AIIndustry.IsCargoAccepted(industryID, cargo) && AIIndustry.GetProduction(industryID, cargo) != -1;
		if (isBilateral)
			hasBilateral = true;

		if (AIIndustry.GetProduction(industryID, cargo) != -1) {	

			// Save production information.
			industryNode.cargoIdsProducing.push(cargo);

			// Add to cache.
			industryCacheProducing[cargo].push(industryNode);

			// Check for accepting industries for these products.
			foreach (cachedIndustry in industryCacheAccepting[cargo]) {
	
				industryNode.connectionNodeList.push(cachedIndustry);
				if (!isBilateral)
					cachedIndustry.connectionNodeListReversed.push(industryNode);
			}
		}

		// Check if the industry actually accepts something.
		if (AIIndustry.IsCargoAccepted(industryID, cargo)) {
			industryNode.cargoIdsAccepting.push(cargo);

			// Add to cache.
			industryCacheAccepting[cargo].push(industryNode);

			// Check if there are producing plants which this industry accepts.
			if (!isBilateral) {
				foreach (cachedIndustry in industryCacheProducing[cargo]) {
					cachedIndustry.connectionNodeList.push(industryNode);
					industryNode.connectionNodeListReversed.push(cachedIndustry);
				}
			}
		}

	}

	// If the industry doesn't accept anything we add it to the root list.
	if (industryNode.cargoIdsAccepting.len() == 0 || hasBilateral)
		industry_tree.push(industryNode);
}

/**
 * Remove an industryNode from the industryList.
 * @industryID The id of the industry which needs to be removed.
 */
function World::RemoveIndustry(industryID) {
	
	
	if (!industry_table.rawin(industryID)) {
		Log.logWarning("Industry removed which wasn't in our tree!");
	}
	
	local industryNode = industry_table.rawget(industryID);
	
	// Remove the industry from the caches.
	foreach (cargo in industryNode.cargoIdsProducing) {
		for (local i = 0; i < industryCacheProducing[cargo].len(); i++) {
			local producingIndustryNode = industryCacheProducing[cargo][i];
			if (producingIndustryNode.id == industryNode.id) {
				industryCacheProducing[cargo].remove(i);
				break;
			}
		}
	}
	
	foreach (cargo in industryNode.cargoIdsAccepting) {
		for (local i = 0; i < industryCacheAccepting[cargo].len(); i++) {
			local acceptingIndustryNode = industryCacheAccepting[cargo][i];
			if (acceptingIndustryNode.id == industryNode.id) {
				industryCacheAccepting[cargo].remove(i);
				break;
			}
		}
	}
	
	// Remove the industry from the root list (if it's there).
	if (industryNode.cargoIdsAccepting.len() == 0) {
		for (local i = 0; i < industry_tree.len(); i++) {
			if (industry_tree[i].id == industryNode.id) {
				industry_tree.remove(i);
				break;
			}
		}
	}
	
	// Now we need to remove this industry from all industry nodes which produces
	// cargo this industry used to accept.
	foreach (producingIndustryNode in industryNode.connectionNodeListReversed) {
		for (local i = 0; i < producingIndustryNode.connectionNodeList.len(); i++) {
			if (producingIndustryNode.connectionNodeList[i].nodeType == industryNode.nodeType &&
				producingIndustryNode.connectionNodeList[i].id == industryNode.id) {
					producingIndustryNode.connectionNodeList.remove(i);
					break;
			}
		}
	}
}

/**
 * Check all available vehicles to transport all sorts of cargos and save
 * the max speed of the fastest transport for each cargo.
 *
 * Update the engine IDs for each cargo type and select the fastest engines.
 */
function World::InitCargoTransportEngineIds() {

	foreach (cargo, value in cargo_list) {

		local engineList = AIEngineList(AIVehicle.VEHICLE_ROAD);
		engineList.AddList(AIEngineList(AIVehicle.VEHICLE_AIR));
		foreach (engine, value in engineList) {
			local vehicleType = AIEngine.GetVehicleType(engine);
			if (AIEngine.GetCargoType(engine) == cargo && 
				AIEngine.GetMaxSpeed(cargoTransportEngineIds[vehicleType][cargo]) < AIEngine.GetMaxSpeed(engine)) {
				cargoTransportEngineIds[vehicleType][cargo] = engine;
			}
		}
	}
	
	// Check
	foreach (element in cargoTransportEngineIds) {
		for(local i = 0; i < element.len(); i++) {
			Log.logDebug("Use engine: " + AIEngine.GetName(element[i]) + " for cargo: " + AICargo.GetCargoLabel(i));
		}
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
				local vehicleType = AIEngine.GetVehicleType(newEngineID);
				local oldEngineID = cargoTransportEngineIds[vehicleType][cargoID];
				
				if (AIEngine.GetMaxSpeed(newEngineID) > AIEngine.GetMaxSpeed(oldEngineID)) {
					Log.logInfo("Replaced " + AIEngine.GetName(oldEngineID) + " with " + AIEngine.GetName(newEngineID));
					cargoTransportEngineIds[vehicleType][cargoID] = newEngineID;
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
 * Debug purposes only.
 */
function World::PrintTree() {
	Log.logDebug("PrintTree");
	foreach (primIndustry in industry_tree) {
		PrintNode(primIndustry, 0);
	}
	Log.logDebug("Done!");
}

function World::PrintNode(node, depth) {
	local string = "";
	for (local i = 0; i < depth; i++) {
		string += "      ";
	}

	Log.logDebug(string + node.GetName() + " -> ");

	foreach (transport in node.connections) {
		Log.logDebug("Vehcile travel time: " + transport.timeToTravelTo);
		Log.logDebug("Cargo: " + AICargo.GetCargoLabel(transport.cargoID));
		Log.logDebug("Cost: " + node.costToBuild);
	}
	foreach (iNode in node.connectionNodeList)
		PrintNode(iNode, depth + 1);
}	


