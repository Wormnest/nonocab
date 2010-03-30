/**
 * World holds the current status of the world as the AI sees it.
 */
class World {
	static DAYS_PER_MONTH = 30.0;
	static DAYS_PER_YEAR = 364.0;
	static MONTHS_PER_YEAR = 12.0;
	static MONTHS_BEFORE_AUTORENEW = 144; // 12 years
	
	town_list = null;			// List with all towns.
	industry_list = null;		// List with all industries.
	industry_table = null;		// Table with all industries.
	cargo_list = null;			// List with all cargos.
	townConnectionNodes = null;		// All connection nodes which are towns (replace later, now in use by AirplaneAdvisor).

	/**
	 * Because some engines are only there to hold cargo (e.g. wagons) while others
	 * only move the cargo without holding any (e.g. locomotives), we split these
	 * duties into two separate arrays. Although for the same entry they can contain
	 * the same engine IDs (e.g. for trucks).
	 */
	cargoTransportEngineIds = null;		// The best engine IDs to transport cargo.
	cargoHoldingEngineIds = null;		// The best engine IDs to hold cargo.
	maxCargoID = null;				// The highest cargo ID number

	industry_tree = null;
	industryCacheAccepting = null;
	industryCacheProducing = null;
	
	worldEventManager = null;     // Manager to fire events to all world event listeners.
	
	starting_year = null;
	years_passed = null;
	
	max_distance_between_nodes = null;		// The maximum distance between industries.
	pathFixer = null;
	niceCABEnabled = null;
	
	/**
	 * Initializes a repesentation of the 'world'.
	 */
	constructor(niceCAB) {
		niceCABEnabled = niceCAB;
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
		maxCargoID = cargo_list.Begin();
		industryCacheAccepting = array(maxCargoID + 1);
		industryCacheProducing = array(maxCargoID + 1);

		InitCargoTransportEngineIds();
	
		industry_tree = [];
	
		// Fill the arrays with empty arrays, we can't use:
		// local industryCacheAccepting = array(cargos.Count(), [])
		// because it will all point to the same empty array...
		foreach (index, value in cargo_list) {
			industryCacheAccepting[index] = [];
			industryCacheProducing[index] = [];
		}
		
		max_distance_between_nodes = 128;
		InitCargoTransportEngineIds();
		
		//BuildIndustryTree();
		worldEventManager = WorldEventManager(this);
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

function World::LoadData(data, connectionManager) {

	foreach (sd in data["activeConnections"]) {
		Log.logInfo(sd["travelToNode"] + " " + sd["travelFromNode"] + " " + AICargo.GetCargoLabel(sd["cargoID"]));
	}
	
	local openList = clone industry_tree;
	local activeConnections = [];

	local closedList = {};

	// Add all connections from the root list to the closed list.
	foreach (connectionNode in openList)
		closedList[connectionNode.nodeType + connectionNode.id] <- true;

	while (openList.len() != 0) {
		local connectionFromNode = openList.remove(0);
		foreach (connectionToNode in connectionFromNode.connectionNodeList) {
			foreach (connectionSaveData in data["activeConnections"]) {
				foreach (cargoID in connectionFromNode.cargoIdsProducing) {
					if (connectionToNode.GetUID(cargoID) == connectionSaveData["travelToNode"] &&
					connectionFromNode.GetUID(cargoID) == connectionSaveData["travelFromNode"] &&
					cargoID == connectionSaveData["cargoID"]) {
						local existingConnection = Connection(cargoID, connectionFromNode, connectionToNode, null, connectionManager);
						existingConnection.LoadData(connectionSaveData);
						connectionFromNode.AddConnection(connectionToNode, existingConnection);


						if (!closedList.rawin(connectionToNode.nodeType + connectionToNode.id))
							openList.push(connectionToNode);
						closedList[connectionToNode.nodeType + connectionToNode.id] <- true;

						Log.logInfo("Loaded connection from " + connectionFromNode.GetName() + " to " + connectionToNode.GetName() + " carrying " + AICargo.GetCargoLabel(cargoID));
						activeConnections.push(existingConnection);
						break;
					}
				}
			}
		}
	}
	
	starting_year = data["starting_year"];
	years_passed = data["years_passed"];
	max_distance_between_nodes = data["max_distance_between_nodes"];
	return activeConnections;
}

function World::SaveData(saveTable) {
	/**
	 * Only safe data of constructed connections.
	 */
	local activeConnections = [];
	local openList = clone industry_tree;
	local closedList = {};

	// Add all connections from the root list to the closed list.
	foreach (connectionNode in openList)
		closedList[connectionNode.nodeType + connectionNode.id] <- true;
	
	while (openList.len() != 0) {
		foreach (connection in openList.remove(0).activeConnections) {

			activeConnections.push(connection.SaveData());
			Log.logInfo("Saved connection from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() + " carrying " + AICargo.GetCargoLabel(connection.cargoID));
			
			if (!closedList.rawin(connection.travelToNode.nodeType + connection.travelToNode.id))
				openList.push(connection.travelToNode);
			closedList[connection.travelToNode.nodeType + connection.travelToNode.id] <- true;
		}
	}
	
	saveTable["activeConnections"] <- activeConnections;
	saveTable["starting_year"] <- starting_year;
	saveTable["years_passed"] <- years_passed;

	saveTable["max_distance_between_nodes"] <- max_distance_between_nodes;		// The maximum distance between industries.
	return saveTable;
}

/**
 * Updates the view on the world.
 */
function World::Update()
{
	worldEventManager.ProcessEvents();

	if (AIDate.GetYear(AIDate.GetCurrentDate()) - starting_year > 2) {
		IncreaseMaxDistanceBetweenNodes();
		starting_year = AIDate.GetYear(AIDate.GetCurrentDate());
	}
	
	// Check if we have any vehicles to sell! :)
	local vehicleList = AIVehicleList();
	foreach (vehicleID, value in vehicleList) {
		if (AIVehicle.IsStoppedInDepot(vehicleID)) {
			
			// If the vehicle is very old, we assume it needs to be replaced
			// by a new vehicle.
			if (AIVehicle.GetAgeLeft(vehicleID) <= 0) {
				local currentEngineID = AIVehicle.GetEngineType(vehicleID);
				local vehicleType = AIVehicle.GetVehicleType(vehicleID);
				
				// Check the type of cargo the vehicle was carrying.
				local mostCargo = 0;
				local currentCargoID = -1;
				foreach (index, value in cargo_list) {
					if (AIVehicle.GetCapacity(vehicleID, index) > mostCargo)
						currentCargoID = index;
				}
				
				// Check what the best engine at the moment is.
				local replacementEngineID = cargoTransportEngineIds[vehicleType][currentCargoID];
				
				if (AIEngine.IsValidEngine(replacementEngineID)) {
					
					local doReplace = true;
					// Don't replace an airplane if the airfield is very small.
					if (vehicleType == AIVehicle.VT_AIR) {
						if (AIEngine.GetPlaneType(AIVehicle.GetEngineType(vehicleID)) !=
							AIEngine.GetPlaneType(replacementEngineID))
							doReplace = false;
					}
					
					// Don't replace trains, ever!
					// TODO: Be smarter about this.
					else if (vehicleType == AIVehicle.VT_RAIL) {
						doReplace = false;
					}
					
					if (doReplace) {
						// Create a new vehicle.
						local newVehicleID = AIVehicle.BuildVehicle(AIVehicle.GetLocation(vehicleID), replacementEngineID);
						if (AIVehicle.IsValidVehicle(newVehicleID)) {
							
							// Let is share orders with the vehicle.
							AIOrder.ShareOrders(newVehicleID, vehicleID);
							AIVehicle.StartStopVehicle(newVehicleID);
						} else {
							// If we failed, simply try again next time.
							continue;
						}
					}
				}
			}
			
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
		return false;

	max_distance_between_nodes += 32;
	Log.logDebug("Increased max distance to: " + max_distance_between_nodes);
	return true;
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
	Log.logInfo("Build industry list.");
	foreach (industry, value in industry_list)
		InsertIndustry(industry);
	Log.logInfo("Build industry list - done.");
	
	// We want to preprocess all industries which can be build near water.
	local stationRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	
	Log.logInfo("Build town list.");
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
				foreach (connectionNode in industryCacheProducing[cargo])
					connectionNode.connectionNodeList.push(townNode);
				
				// Add this town to the accepting cache for future industries.
				industryCacheAccepting[cargo].push(townNode);
				
				townNode.cargoIdsProducing.push(cargo);
				townNode.cargoIdsAccepting.push(cargo);
			}
		}

		// Add town <-> town connections, we only store these connections as 1-way directions
		// because they are bidirectional.
		foreach (townConnectionNode in townConnectionNodes)
			townNode.connectionNodeList.push(townConnectionNode);

		townConnectionNodes.push(townNode);
		industry_tree.push(townNode);
	}
	
	Log.logInfo("Build town list - done.");
}

/**
 * Insert an industryNode in the industryList.
 * @industryID The id of the industry which needs to be added.
 */
function World::InsertIndustry(industryID) {

	local industryNode = IndustryConnectionNode(industryID, niceCABEnabled);
	
	// Make sure this industry hasn't already been added.
	//if (!industry_table.rawin(industryID))
		industry_table[industryID] <- industryNode;
	//else
	//	assert(false);

	local hasBilateral = false;
	local isPrimaryIndustry = false;

	// We want to preprocess all industries which can be build near water.
	local isNearWater = industryNode.isNearWater;
	local stationRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	local ignoreProducersList = {};
	local ignoreAccepterssList = {};
	
	// Check which cargo is accepted.
	foreach (cargo, value in cargo_list) {
		
		local acceptsCargo = AIIndustry.IsCargoAccepted(industryID, cargo);
		local producesCargo = AIIndustry.GetLastMonthProduction(industryID, cargo) != -1;
		local isBilateral =  acceptsCargo && producesCargo;
		if (isBilateral)
			hasBilateral = true;
		if (!isPrimaryIndustry)
			isPrimaryIndustry = AIIndustryType.IsRawIndustry(AIIndustry.GetIndustryType(industryID));

		if (producesCargo) {
			
			// Save production information.
			industryNode.cargoIdsProducing.push(cargo);

			// Add to cache.
			industryCacheProducing[cargo].push(industryNode);

			// Check for accepting industries for these products.
			foreach (cachedIndustry in industryCacheAccepting[cargo]) {

				// Make sure we don't add industires double!
				if (ignoreProducersList.rawin(cachedIndustry)) continue;
				
				ignoreProducersList[cachedIndustry] <- null;
				industryNode.connectionNodeList.push(cachedIndustry);
				if (!isBilateral)
					cachedIndustry.connectionNodeListReversed.push(industryNode);
			}
		}

		// Check if the industry actually accepts something.
		if (acceptsCargo) {
			industryNode.cargoIdsAccepting.push(cargo);

			// Add to cache.
			industryCacheAccepting[cargo].push(industryNode);

			// Check if there are producing plants which this industry accepts.
			if (!isBilateral) {
				foreach (cachedIndustry in industryCacheProducing[cargo]) {
					
					// Make sure we don't add industires double!
					if (ignoreAccepterssList.rawin(cachedIndustry)) continue;

					ignoreAccepterssList[cachedIndustry] <- null;
					cachedIndustry.connectionNodeList.push(industryNode);
					industryNode.connectionNodeListReversed.push(cachedIndustry);
				}
			}
		}

		// Check if this industry is near to water.
		if ((acceptsCargo || producesCargo) && !isNearWater) {
			if (AIIndustry.IsBuiltOnWater(industryNode.id))
				industryNode.isNearWater = true;
			else {
				local industryTiles = acceptsCargo ? industryNode.GetAcceptingTiles(cargo, stationRadius, 1, 1) : industryNode.GetProducingTiles(cargo, stationRadius, 1, 1);
				industryTiles.Valuate(AITile.IsCoastTile);
				industryTiles.KeepValue(1);
				if (industryTiles.Count() > 0)
					industryNode.isNearWater = true;
			}
			isNearWater = true;
		}
	}

	// If the industry doesn't accept anything we add it to the root list.
	if (industryNode.cargoIdsAccepting.len() == 0 || hasBilateral || isPrimaryIndustry)
		industry_tree.push(industryNode);
}

/**
 * Remove an industryNode from the industryList.
 * @industryID The id of the industry which needs to be removed.
 */
function World::RemoveIndustry(industryID) {
	
	
	if (!industry_table.rawin(industryID)) {
		Log.logWarning("Industry removed which wasn't in our tree!");
		//assert(false);
		return null;
	}
	
	local industryNode = industry_table.rawget(industryID);
	
	// Remove the industry from the caches.
	foreach (cargo in industryNode.cargoIdsProducing) {
		for (local i = 0; i < industryCacheProducing[cargo].len(); i++) {
			if (industryCacheProducing[cargo][i].id == industryNode.id) {
				industryCacheProducing[cargo].remove(i);
				break;
			}
		}
	}
	
	foreach (cargo in industryNode.cargoIdsAccepting) {
		for (local i = 0; i < industryCacheAccepting[cargo].len(); i++) {
			if (industryCacheAccepting[cargo][i].id == industryNode.id) {
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
	
	// We add all connection to demolish in a tupple, because if we call the Demolish
	// function it will remove an element from the array and this will screw up the
	// iterators below resulting in a run-time error. After all connections which must
	// be destroyed are identified they will be demolished out side the iterators.
	local toDemolishList = [];
	foreach (connection in industryNode.reverseActiveConnections)
		// Remove all connections which are already build!
		foreach (fromConnnection in connection.travelFromNode.activeConnections)
			if (fromConnnection.travelToNode == industryNode)
				toDemolishList.push([fromConnnection, true]);
	
	// Remove all connections which are already build!
	foreach (connection in industryNode.activeConnections) {
		// If there are more connections dropping cargo off at
		// the end destination, we don't destroy those road stations!
		local demolishDestinationRoadStations = true;
		if (connection.vehicleTypes == AIVehicle.VT_ROAD && 
			connection.travelToNode.reverseActiveConnections.len() > 1)
			demolishDestinationRoadStations = false;

		toDemolishList.push([connection, demolishDestinationRoadStations]);
	}

	foreach (connectionTuple in toDemolishList)
		connectionTuple[0].Demolish(true, connectionTuple[1], false);

	industry_table.rawdelete(industryID);
	industryNode.isInvalid = true;
	return industryNode;
}

/**
 * Check all available vehicles to transport all sorts of cargos and save
 * the max speed of the fastest transport for each cargo.
 *
 * Update the engine IDs for each cargo type and select the fastest engines
 * which can cary the most (speed * capacity).
 */
function World::InitCargoTransportEngineIds() {
	
	cargoTransportEngineIds = array(4);
	cargoHoldingEngineIds = array(4);
	
	for (local i = 0; i < cargoTransportEngineIds.len(); i++) {
		cargoTransportEngineIds[i] = array(maxCargoID + 1, -1);
		cargoHoldingEngineIds[i] = array(maxCargoID + 1, -1);
	}
	
	local engineList = AIEngineList(AIVehicle.VT_ROAD);
	engineList.Valuate(AIEngine.GetRoadType);
	engineList.KeepValue(AIRoad.ROADTYPE_ROAD);
	engineList.AddList(AIEngineList(AIVehicle.VT_AIR));
	engineList.AddList(AIEngineList(AIVehicle.VT_WATER));
	engineList.AddList(AIEngineList(AIVehicle.VT_RAIL));
	
	// Handle initializing new engines by using the event method
	// already present :).
	foreach (engine, value in engineList)
		ProcessNewEngineAvailableEvent(engine);
}

/**
 * Handle the insertion of a new engine.
 * @param engineID The new engine ID.
 * @return true If the new engine replaced other onces, otherwise false.
 */
function World::ProcessNewEngineAvailableEvent(engineID) {
	if (!AIEngine.IsValidEngine(engineID))
		return false;

	local vehicleType = AIEngine.GetVehicleType(engineID);

	if (vehicleType == AIVehicle.VT_RAIL) {
		// Check if this train can run on a newer rail type.
		if (AIRail.GetCurrentRailType() < AIEngine.GetRailType(engineID)) {
			AIRail.SetCurrentRailType(AIEngine.GetRailType(engineID));

			// Also update the wagons we can use. These are not updated automatically!
			local newWagons = AIEngineList(AIVehicle.VT_RAIL);
			newWagons.Valuate(AIEngine.IsWagon);
			newWagons.KeepValue(1);
			newWagons.Valuate(AIEngine.CanRunOnRail, AIRail.GetCurrentRailType());
			newWagons.KeepValue(1);
			newWagons.Valuate(AIEngine.HasPowerOnRail, AIRail.GetCurrentRailType());
			newWagons.KeepValue(1);

			foreach (wagon, value in newWagons)
				ProcessNewEngineAvailableEvent(wagon);
		}

		if (!AIEngine.CanRunOnRail(engineID, AIRail.GetCurrentRailType()) ||
		    !AIEngine.HasPowerOnRail(engineID, AIRail.GetCurrentRailType()))
			return false;
	}

	// We skip trams for now.
	if (vehicleType == AIVehicle.VT_ROAD && AIEngine.GetRoadType(engineID) != AIRoad.ROADTYPE_ROAD)
		return false;
		
	local engineReplaced = false;

	foreach (cargo, value in cargo_list) {
		local oldEngineID = cargoTransportEngineIds[vehicleType][cargo];
		local newEngineID = -1;
		
		if ((AIEngine.GetCargoType(engineID) == cargo || AIEngine.CanRefitCargo(engineID, cargo) || (!AIEngine.IsWagon(engineID) && AIEngine.CanPullCargo(engineID, cargo)))) {
			
			// Different case for trains as the wagons cannot transport themselves and the locomotives
			// are unable to carry any cargo (ignorable cases aside).
			if (vehicleType == AIVehicle.VT_RAIL) {
				if (AIEngine.IsWagon(engineID)) {
					// We only judge a weagon on its merrit to transport cargo.
					if (AIEngine.GetCapacity(cargoHoldingEngineIds[vehicleType][cargo]) < AIEngine.GetCapacity(engineID) ||
					    AIEngine.GetRailType(engineID) > AIEngine.GetRailType(cargoHoldingEngineIds[vehicleType][cargo])) {
						cargoHoldingEngineIds[vehicleType][cargo] = engineID;
						Log.logInfo("Replaced " + AIEngine.GetName(oldEngineID) + " with " + AIEngine.GetName(engineID) + " to carry: " + AICargo.GetCargoLabel(cargo));
						newEngineID = engineID;
						engineReplaced = true;
					}						
				} else {
					// We only judge a locomotive on its merrit to transport weagons (don't care about the
					// accidental bit of cargo it can move around).
					if (AIEngine.GetMaxSpeed(cargoTransportEngineIds[vehicleType][cargo]) < AIEngine.GetMaxSpeed(engineID) ||
					    AIEngine.GetRailType(engineID) > AIEngine.GetRailType(cargoTransportEngineIds[vehicleType][cargo])) {
						cargoTransportEngineIds[vehicleType][cargo] = engineID;
						Log.logInfo("Replaced " + AIEngine.GetName(oldEngineID) + " with " + AIEngine.GetName(engineID) + " to transport: " + AICargo.GetCargoLabel(cargo));
						newEngineID = engineID;
						engineReplaced = true;
					}
				}
			} else if (AIEngine.GetMaxSpeed(cargoTransportEngineIds[vehicleType][cargo]) * AIEngine.GetCapacity(cargoTransportEngineIds[vehicleType][cargo]) < AIEngine.GetMaxSpeed(engineID) * AIEngine.GetCapacity(engineID)) {
				cargoTransportEngineIds[vehicleType][cargo] = engineID;
				cargoHoldingEngineIds[vehicleType][cargo] = engineID;
				newEngineID = engineID;
				Log.logInfo("Replaced " + AIEngine.GetName(oldEngineID) + " with " + AIEngine.GetName(engineID) + " to transport and carry: " + AICargo.GetCargoLabel(cargo));
				engineReplaced = true;
			}
			
			// If we have replaced an engine, we want to upgrade all groups with an old engine to the new one.
			if (newEngineID != -1) {
				// Only set autoreplace if the types of vehicles are compatible.
				local vehicleTypesAreCompatible = true;
				
				// Don't replace little air planes with bigger ones!
				if (vehicleType == AIVehicle.VT_AIR &&
					AIEngine.GetPlaneType(oldEngineID) != AIEngine.GetPlaneType(newEngineID))
					vehicleTypesAreCompatible = false;
				
				// Don't replace trains if the new one cannot run on the olds rails.
				if (vehicleType == AIVehicle.VT_RAIL) {
					local railType = AIEngine.GetRailType(oldEngineID);
					if (!AIEngine.HasPowerOnRail(newEngineID, railType) ||
						!AIEngine.CanRunOnRail(newEngineID, railType))
						vehicleTypesAreCompatible = false;
				}
				
				if (vehicleTypesAreCompatible)
					AIGroup.SetAutoReplace(AIGroup.GROUP_ALL, oldEngineID, newEngineID);
			}
		}
	}
	return engineReplaced;
}				

/**
 * Handle the event where an industry is opened in the world. We add it to
 * the data structures and return the stored node.
 * @param industryID The new industry ID.
 * @return The stored industry node.
 */
function World::ProcessIndustryOpenedEvent(industryID) {
	industry_list = AIIndustryList();
	Log.logInfo("New industry: " + AIIndustry.GetName(industryID) + " added to the world!");
	InsertIndustry(industryID);
	return industry_table[industryID];
}			

/**
 * Handle the event where an industry is closed in the world. We remove it from
 * the data structures and return the deleted node.
 * @param industryID The removed industry ID.
 * @return The removed industry node.
 */
function World::ProcessIndustryClosedEvent(industryID) {
	industry_list = AIIndustryList();
	Log.logInfo("Industry: " + AIIndustry.GetName(industryID) + " removed from the world!");
	return RemoveIndustry(industryID);
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


