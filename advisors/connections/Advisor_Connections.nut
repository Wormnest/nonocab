import("queue.binary_heap", "BinaryHeap", 1);

/**
 * Build economy tree with primary economies which require no input
 * to produce on the root level, secundary economies which require
 * input from primary industries as children and so on. The max 
 * depth in OpenTTD is 4;
 *
 * Grain                              }
 * Iron ore        -> Steel           }-> Goods  -> Town
 * Livestock                          }
 */
class ConnectionAdvisor extends Advisor
{
	world = null;				// Pointer to the World class.
	cargoTransportEngineIds = null;		// The fastest engine IDs to transport the cargos.
	connectionReports = null;
	
	industry_tree = null;
	industryCacheAccepting = null;
	industryCacheProducing = null;
	
	constructor(world)
	{
		this.world = world;		
		cargoTransportEngineIds = array(AICargoList().Count(), -1);
		connectionReports = BinaryHeap();
		
		BuildIndustryTree();
		UpdateIndustryConnections();
	}
	
	/**
	 * Build a tree of all industry nodes, where we connect each producing
	 * industry to an industry which accepts that produced cargo. The primary
	 * industries (ie. the industries which only produce cargo) are the root
	 * nodes of this tree.
	 */
	function BuildIndustryTree();
	
	/**
	 * Iterate through the industry tree and update its information.
	 */
	function UpdateIndustryConnections();
	
	/**
	 * Check which set of industry connections yield the highest profit.
	 */
	function getReports();
	
	/**
	 * Update the engine IDs for each cargo type and select the fastest engines.
	 */
	function UpdateCargoTransportEngineIds();
	
	/**
	 * Debug purposes only:
	 * Print the constructed industry node.
	 */
	function PrintTree();
	
	/**
	 * Debug purposes only:
	 * Print a single node in the industry tree.
	 */
	function PrintNode();
}
	
	
function ConnectionAdvisor::BuildIndustryTree() {
	// Construct complete industry node list.
	local industries = world.industry_list;
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

function ConnectionAdvisor::UpdateIndustryConnections() {
	UpdateCargoTransportEngineIds();

	// Upon initialisation we look at all possible connections in the world and try to
	// find the most prommising once in terms of cost to build to profit ratio. We can't
	// however get perfect information by calculating all possible routes as that will take
	// us way to much time.
	//
	// Therefore we try to get an indication by taking the Manhattan distance between two
	// industries and see what the profit would be if we would be able to build a straight
	// road and let and vehicle operate on it.
	//
	// The next step would be to look at the most prommising connection nodes and do some
	// actual pathfinding on that selection to find the best one(s).
	foreach (primIndustry in industry_tree) {

		foreach (secondIndustry in primIndustry.industryNodeList) {

			// Check if this connection already exists.
			if (primIndustry.industryConnections.rawin("" + secondIndustry)) {

				// See if we need to add or remove some vehicles.

			} else {
				local manhattanDistance = AIMap.DistanceManhattan(AIIndustry.GetLocation(primIndustry.industryID), 
					AIIndustry.GetLocation(secondIndustry.industryID));

				// Take a guess at the travel time and profit for each cargo type.
				foreach (cargo in primIndustry.cargoIdsProducing) {

					local maxSpeed = AIEngine.GetMaxSpeed(cargoTransportEngineIds[cargo]);
					local travelTime = manhattanDistance * RoadPathFinding.straightRoadLength / maxSpeed;
					local incomePerRun = AICargo.GetCargoIncome(cargo, manhattanDistance, travelTime.tointeger()) * AIEngine.GetCapacity(cargoTransportEngineIds[cargo]);

					local report = ConnectionReport();
					report.profitPerMonthPerVehicle = (30.0 / travelTime) * incomePerRun;
					report.engineID = cargoTransportEngineIds[cargo];
					report.fromIndustryNode = primIndustry;
					report.toIndustryNode = secondIndustry;
					report.cargoID = cargo;

					connectionReports.Insert(report, -report.profitPerMonthPerVehicle);
				}
			}
		}
	}
}

/**
 * Construct a report by finding the largest subset of buildable infrastructure given
 * the amount of money available to us, which in turn yields the largest income.
 */
function ConnectionAdvisor::getReports()
{
	// The report list to construct.
	local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
	
	// The number of connections which we've compared.
	local comparedConnections = 0;
	
	// Check how much we have to spend:
	local money = AICompany.GetBankBalance(AICompany.MY_COMPANY);
	
	// Hold a cache of possible connections.
	local connectionCache = BinaryHeap();

	// Try to get the best subset of options.
	local report;
	while ((report = connectionReports.Pop()) != null) {

		/**
		 * Do an aditional check to prevent this piece of code to check all possible 
		 * connections and just check a reasonable number until we've spend enough
		 * money or till we've spend enough time in this function.
		 */
		if (comparedConnections > 10 && connectionCache.Count() > 0 ||	// We've compared at least 10 connections and found at leat 1 report
		money < 20000 && comparedConnections > 15 || // We've compared at leats 15 connections and we're low on money 
		comparedConnections > 20) {	// We've compared at least 20 connections.
			break;
		}
		
		comparedConnections++;

		// If the report is already fully calculated, check if we can afford it and execute it!
		if (report.cost != 0 && report.cost < money) {

			local otherIndustry = report.fromIndustryNode.GetIndustryConnection(report.toIndustryNode.industryID);
			if (otherIndustry != null && otherIndustry.build == true) {
				// Check if we need to add / remove vehicles to this connection.

			} else {
				
				connectionCache.Insert(report, -report.Utility());
				// The cost has already been calculated, so we can build it immediatly.
				report.print();
				money -= report.cost;
			}
		} else if (report.cost == 0) {

			// The actionlist to construct.
			local actionList = [];

			// If we haven't calculated yet what it cost to build this report, we do it now.
			local pathfinder = RoadPathFinding();
			local pathList = pathfinder.FindFastestRoad(AITileList_IndustryProducing(report.fromIndustryNode.industryID, radius), AITileList_IndustryAccepting(report.toIndustryNode.industryID, radius));

			if (pathList == null) {
				print("No path found from " + AIIndustry.GetName(report.fromIndustryNode.industryID) + " to " + AIIndustry.GetName(report.toIndustryNode.industryID));
				continue;
			}
			// Now we know the prices, check how many vehicles we can build and what the actual income per vehicle is.
			local timeToTravelTo = pathfinder.GetTime(pathList.roadList, AIEngine.GetMaxSpeed(report.engineID), true);
			local timeToTravelFrom = pathfinder.GetTime(pathList.roadList, AIEngine.GetMaxSpeed(report.engineID), false);

			// Calculate bruto income per vehicle per run.
			local incomePerRun = AICargo.GetCargoIncome(report.cargoID, 
				AIMap.DistanceManhattan(pathList.roadList[0].tile, pathList.roadList[pathList.roadList.len() - 1].tile), 
				timeToTravelTo) * AIEngine.GetCapacity(report.engineID);


			// Calculate netto income per vehicle.
			local incomePerVehicle = incomePerRun - ((timeToTravelTo + timeToTravelFrom) * AIEngine.GetRunningCost(report.engineID) / 364);

			local productionPerMonth;
			// Calculate the number of vehicles which can operate:
			for (local i = 0; i < report.fromIndustryNode.cargoIdsProducing.len(); i++) {

				if (report.cargoID == report.fromIndustryNode.cargoIdsProducing[i]) {
					productionPerMonth = report.fromIndustryNode.cargoProducing[i];
					break;
				}
			}

			local transportedCargoPerVehiclePerMonth = (30.0 / (timeToTravelTo + timeToTravelFrom)) * AIEngine.GetCapacity(report.engineID);
			report.nrVehicles = productionPerMonth / transportedCargoPerVehiclePerMonth;

			// Calculate the profit per month per vehicle
			report.profitPerMonthPerVehicle = incomePerVehicle * (30.0 / (timeToTravelTo + timeToTravelFrom));
			report.cost = pathfinder.GetCostForRoad(pathList) + report.nrVehicles * AIEngine.GetPrice(report.engineID);

			// If we can afford it, add it to the possible connection list.
			if (report.cost < money) {
				connectionCache.Insert(report, -report.Utility());
				
				// Check if the industry connection node actually exists else create it, and update it!
				local industryConnectionNode = report.fromIndustryNode.GetIndustryConnection(report.toIndustryNode);
				if (industryConnectionNode == null) {
					industryConnectionNode = IndustryConnection(report.fromIndustryNode, report.toIndustryNode);
					report.fromIndustryNode.AddIndustryConnection(report.toIndustryNode, industryConnectionNode);
				}
				
				industryConnectionNode.pathInfo = pathList;
			}
		}
	}
	
	// We have a list with possible connections we can afford, we now apply
	// a subsum algorithm to get the best profit possible with the given money.
	local reports = [];
	
	local possibleConnection;
	while ((possibleConnection = connectionCache.Pop()) != null) {
		
		// Check if we can afford it.
		if (money > possibleConnection.cost) {
			
			local actionList = [];
			
			// The industryConnectionNode gives us the actual connection.
			local industryConnectionNode = possibleConnection.fromIndustryNode.GetIndustryConnection(possibleConnection.toIndustryNode.industryID);

			// Give the action to build the road.
			actionList.push(BuildIndustryRoadAction(industryConnectionNode, true, true));
			
			// Add the action to build the vehicles.
			local vehicleAction = ManageVehiclesAction();
			vehicleAction.BuyVehicles(possibleConnection.engineID, possibleConnection.nrVehicles, industryConnectionNode);
			actionList.push(vehicleAction);
			
			// Create a report and store it!
			reports.push(Report(possibleConnection.ToString(), possibleConnection.cost, possibleConnection.Profit(), actionList));
		}
	}
	
	return reports;
}

/**
 * Check all available vehicles to transport all sorts of cargos and save
 * the max speed of the fastest transport for each cargo.
 */
function ConnectionAdvisor::UpdateCargoTransportEngineIds() {

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

/**
 * Debug purposes only.
 */
function ConnectionAdvisor::PrintTree() {
	Log.logDebug("PrintTree");
	foreach (primIndustry in industry_tree) {
		PrintNode(primIndustry, 0);
	}
	Log.logDebug("Done!");
}

function ConnectionAdvisor::PrintNode(node, depth) {
	local string = "";
	for (local i = 0; i < depth; i++) {
		string += "      ";
	}

	print(string + AIIndustry.GetName(node.industryID) + " -> ");

	foreach (transport in node.industryConnections) {
		Log.logDebug("Vehcile travel time: " + transport.timeToTravelTo);
		//print("Vehcile income per run: " + transport.incomePerRun);
		Log.logDebug("Cargo: " + AICargo.GetCargoLabel(transport.cargoID));
		Log.logDebug("Cost: " + node.costToBuild);
	}
	foreach (iNode in node.industryNodeList)
		PrintNode(iNode, depth + 1);
}	



