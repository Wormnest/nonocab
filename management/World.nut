/**
 * World holds the current status of the world as the AI sees it.
 */
class World extends EventListener {
	static DAYS_PER_MONTH = 30.0;
	static DAYS_PER_YEAR = 364.0;
	static MONTHS_PER_YEAR = 12.0;
	static MONTHS_BEFORE_AUTORENEW = 144; // 12 years
	
	town_list = null;			// List with all towns.
	industry_list = null;		// List with all industries.
	industry_table = null;		// Table with all industries.
	cargo_list = null;			// List with all cargos.
	townConnectionNodes = null;		// All connection nodes which are towns (replace later, now in use by AirplaneAdvisor).

	cargoTransportEngineIds = null;		// The fastest engine IDs to transport the cargos.

	industry_tree = null;
	industryCacheAccepting = null;
	industryCacheProducing = null;
	
	starting_year = null;
	years_passed = null;
	
	max_distance_between_nodes = null;		// The maximum distance between industries.
	pathFixer = null;
	
	/**
	 * Initializes a repesentation of the 'world'.
	 */
	constructor(eventManager) {
		townConnectionNodes = [];
		starting_year = AIDate.GetYear(AIDate.GetCurrentDate());
		years_passed = 0;
		town_list = AITownList();
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
		
		max_distance_between_nodes = 128;
		
		//InitEvents();
		eventManager.AddEventListener(this, AIEvent.AI_ET_INDUSTRY_OPEN);
		eventManager.AddEventListener(this, AIEvent.AI_ET_INDUSTRY_CLOSE);
		eventManager.AddEventListener(this, AIEvent.AI_ET_ENGINE_AVAILABLE);
		InitCargoTransportEngineIds();
		
		BuildIndustryTree();
	}
	
	/**
	 * Manually increase the maximum distance between industries / towns. We need
	 * this because sometimes the advisors have already build all possible connections
	 * and are eager for more!
	 */
	function IncreaseMaxDistanceBetweenNodes();

	/**
	 * Insert an industryNode in the industryList.
	 * @industryID The id of the industry which needs to be added.
	 */
	function InsertIndustry(industryID);

	/**
	 * Remove an industryNode from the industryList.
	 * @industryID The id of the industry which needs to be removed.
	 */
	function RemoveIndustry(industryID);

	/**
	 * Debug purposes only:
	 * Print the constructed industry node.
	 */
	function PrintTree();
	
	/**
	 * Debug purposes only:
	 * Print a single node in the industry tree.
	 */
	function PrintNode(node, depth);	
}

/**
 * Updates the view on the world.
 */
function World::Update()
{
	//UpdateEvents();

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
function World::IncreaseMaxDistanceBetweenNodes() {
	if (max_distance_between_nodes > AIMap.GetMapSizeX() + AIMap.GetMapSizeY())
		return;

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

	// We want to preprocess all industries which can be build near water.
	local stationRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	
	// Now handle the connections Industry --> Town
	foreach (town, value in town_list) {
		
		local townNode = TownConnectionNode(town);
		local isNearWater = townNode.isNearWater;
		
		// Check if this town accepts something an industry creates.
		foreach (cargo, value in cargo_list) {
			if (AITile.GetCargoAcceptance(townNode.GetLocation(), cargo, 1, 1, 1)) {
				
				// Check if this town is near to water.
				if (!isNearWater) {
					local townTiles = townNode.GetAcceptingTiles(cargo, stationRadius, 1, 1);
					townTiles.Valuate(AITile.IsCoastTile);
					townTiles.KeepValue(1);
					if (townTiles.Count() > 0)
						townNode.isNearWater = true;
					isNearWater = true;
				}

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

				// Check if this town is near to water.
				if (!isNearWater && AITown.GetMaxProduction(townNode.id, cargo) > 0) {
					local townTiles = townNode.GetAcceptingTiles(cargo, stationRadius, 1, 1);
					townTiles.Valuate(AITile.IsCoastTile);
					townTiles.KeepValue(1);
					if (townTiles.Count() > 0) {
						townTiles.isNearWater = true;
					}
					isNearWater = true;
				}

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
		assert(false);

	local hasBilateral = false;

	// We want to preprocess all industries which can be build near water.
	local isNearWater = industryNode.isNearWater;
	local stationRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	
	// Check which cargo is accepted.
	foreach (cargo, value in cargo_list) {


		local canHandleCargo = false;
		local isBilateral = AIIndustry.IsCargoAccepted(industryID, cargo) && AIIndustry.GetLastMonthProduction(industryID, cargo) != -1;
		if (isBilateral)
			hasBilateral = true;

		if (AIIndustry.GetLastMonthProduction(industryID, cargo) != -1) {	
			canHandleCargo = true;
			// Save production information.
			industryNode.cargoIdsProducing.push(cargo);

			// Add to cache.
			industryCacheProducing[cargo].push(industryNode);

			// Check for accepting industries for these products.
			foreach (cachedIndustry in industryCacheAccepting[cargo]) {
	
				// Make sure we don't add industires double!
				local skip = false;
				foreach (node in industryNode.connectionNodeList) {
					if (node == cachedIndustry) {
						skip = true;
						break;
					}
				}
				if (skip)
					continue;
					
				industryNode.connectionNodeList.push(cachedIndustry);
				if (!isBilateral)
					cachedIndustry.connectionNodeListReversed.push(industryNode);
			}
		}

		// Check if the industry actually accepts something.
		if (AIIndustry.IsCargoAccepted(industryID, cargo)) {
			canHandleCargo = true;
			industryNode.cargoIdsAccepting.push(cargo);

			// Add to cache.
			industryCacheAccepting[cargo].push(industryNode);

			// Check if there are producing plants which this industry accepts.
			if (!isBilateral) {
				foreach (cachedIndustry in industryCacheProducing[cargo]) {
					
					// Make sure we don't add industires double!
					local skip = false;
					foreach (node in industryNode.connectionNodeListReversed) {
						if (node == cachedIndustry) {
							skip = true;
							break;
						}
					}
					if (skip)
						continue;
										
					cachedIndustry.connectionNodeList.push(industryNode);
					industryNode.connectionNodeListReversed.push(cachedIndustry);
				}
			}
		}

		// Check if this town is near to water.
		if (canHandleCargo && !isNearWater) {
			local industryTiles = industryNode.GetAcceptingTiles(cargo, stationRadius, 1, 1);
			industryTiles.AddList(industryNode.GetProducingTiles(cargo, stationRadius, 1, 1));
			industryTiles.Valuate(AITile.IsCoastTile);
			industryTiles.KeepValue(1);
			if (industryTiles.Count() > 0) {
				industryNode.isNearWater = true;
			}
			isNearWater = true;
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
		assert(false);
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
		// Remove all connections which are already build!
		foreach (connection in producingIndustryNode.GetAllConnections())
			if (connection.pathInfo.build && connection.travelFromNode == producingIndustryNode)
				connection.Demolish(true, true, true);		
		
		for (local i = 0; i < producingIndustryNode.connectionNodeList.len(); i++) {
			if (producingIndustryNode.connectionNodeList[i].nodeType == industryNode.nodeType &&
				producingIndustryNode.connectionNodeList[i].id == industryNode.id) {					
					producingIndustryNode.connectionNodeList.remove(i);
					break;
			}
		}
	}
	
	// Remove all connections which are already build!
	foreach (connection in industryNode.GetAllConnections()) {
		if (connection.pathInfo.build) {
			// If there are more connections dropping cargo off at
			// the end destination, we don't destroy those road stations!
			local demolishDestinationRoadStations = true;
			if (connection.vehicleTypes == AIVehicle.VT_ROAD && 
				connection.travelToNode.reverseActiveConnections.len() > 1)
				demolishDestinationRoadStations = false;

			connection.Demolish(true, demolishDestinationRoadStations, true);
		}
	}
			
	industry_table.rawdelete(industryID);
}

/**
 * Check all available vehicles to transport all sorts of cargos and save
 * the max speed of the fastest transport for each cargo.
 *
 * Update the engine IDs for each cargo type and select the fastest engines
 * which can cary the most (speed * capacity).
 */
function World::InitCargoTransportEngineIds() {
	
	foreach (cargo, value in cargo_list) {

		local engineList = AIEngineList(AIVehicle.VT_ROAD);
		engineList.Valuate(AIEngine.GetRoadType);
		engineList.KeepValue(AIRoad.ROADTYPE_ROAD);
		engineList.AddList(AIEngineList(AIVehicle.VT_AIR));
		engineList.AddList(AIEngineList(AIVehicle.VT_WATER));
		foreach (engine, value in engineList) {
			local vehicleType = AIEngine.GetVehicleType(engine);
			if ((AIEngine.GetCargoType(engine) == cargo || AIEngine.CanRefitCargo(engine, cargo)) && 
				AIEngine.GetMaxSpeed(cargoTransportEngineIds[vehicleType][cargo]) * AIEngine.GetCapacity(cargoTransportEngineIds[vehicleType][cargo]) < AIEngine.GetMaxSpeed(engine) * AIEngine.GetCapacity(engine)) {
				cargoTransportEngineIds[vehicleType][cargo] = engine;
			}
		}
	}
}

// Handle events:
function World::ProcessNewEngineAvailableEvent(engineID) {
	local vehicleType = AIEngine.GetVehicleType(engineID);
	
	// We skip trams for now.
	if (vehicleType == AIVehicle.VT_ROAD && AIEngine.GetRoadType(engineID) != AIRoad.ROADTYPE_ROAD)
		return;
	
	foreach (cargo, value in cargo_list) {
		local oldEngineID = cargoTransportEngineIds[vehicleType][cargo];
		
		if ((AIEngine.GetCargoType(engineID) == cargo || AIEngine.CanRefitCargo(engineID, cargo)) && 
			(oldEngineID == - 1 || AIEngine.GetMaxSpeed(oldEngineID) * AIEngine.GetCapacity(oldEngineID) < AIEngine.GetMaxSpeed(engineID) * AIEngine.GetCapacity(engineID))) {
				
			Log.logInfo("Replaced " + AIEngine.GetName(oldEngineID) + " with " + AIEngine.GetName(engineID));
			cargoTransportEngineIds[vehicleType][cargo] = engineID;
		}
	}
}				

function World::ProcessIndustryOpenedEvent(industryID) {
	industry_list = AIIndustryList();
	InsertIndustry(industryID);
	Log.logInfo("New industry: " + AIIndustry.GetName(industryID) + " added to the world!");
}			

function World::ProcessIndustryClosedEvent(industryID) {
	industry_list = AIIndustryList();
	RemoveIndustry(industryID);
	Log.logInfo("Industry: " + AIIndustry.GetName(industryID) + " removed from the world!");
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


