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
	
	constructor(world)
	{
		this.world = world;		
		cargoTransportEngineIds = array(AICargoList().Count(), -1);
		connectionReports = BinaryHeap();
		
		UpdateIndustryConnections();
	}
	
	function UpdateIndustryConnections() {
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
		foreach (primIndustry in world.industry_list) {
			
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
	function getReports()
	{
	
		local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
	
		// Check how much we have to spend:
		local money = AICompany.GetBankBalance(AICompany.MY_COMPANY);
		
		// Try to get the best subset of options.
		local report;
		while ((report = connectionReports.Pop()) != null) {
			
			// If the report is already fully calculated, check if we can afford it and execute it!
			if (report.cost != 0 && report.cost < money) {
				report.print();
				money -= report.cost;
			} else if (report.cost == 0) {
			
				// If we haven't calculated yet what it cost to build this report, we do it now.
				local pathfinder = RoadPathFinding();
				local pathList = pathfinder.FindFastestRoad(AITileList_IndustryProducing(report.fromIndustryNode.industryID, radius), AITileList_IndustryAccepting(report.toIndustryNode.industryID, radius));
				
				if (pathList == null) {
					print("No path found from " + AIIndustry.GetName(report.fromIndustryID) + " to " + AIIndustry.GetName(report.toIndustryID));
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
				report.cost = pathfinder.GetCostForRoad(pathList.roadList) + report.nrVehicles * AIEngine.GetPrice(report.engineID);
				
				if (report.cost < money) {
					report.Print();
					print("Extra information: Time to travel to: " + timeToTravelTo + ". Time to travel from: " + timeToTravelFrom);
					print("Extra information: incomePerRun: " + incomePerRun + ". Income per vehicle: " + incomePerVehicle);
					money -= report.cost;
				}
			}
		}
	}

	/**
	 * Check all available vehicles to transport all sorts of cargos and save
	 * the max speed of the fastest transport for each cargo.
	 */
	function UpdateCargoTransportEngineIds() {

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
		
		for (local i = 0; i < cargoTransportEngineIds.len(); i++) {
			print("Engines : " + cargoTransportEngineIds[i]);
			print("Capacity : " + AIEngine.GetCapacity(cargoTransportEngineIds[i]));
			print("Cargo : " + AICargo.GetCargoLabel(AIEngine.GetCargoType(cargoTransportEngineIds[i])));
		}
	}
}

class ConnectionReport {

	profitPerMonthPerVehicle = 0;	// The utility value.
	engineID = 0;			// The vehicles to build.
	nrVehicles = 0;			// The number of vehicles to build.
	roadList = null;		// The road to build.

	fromIndustryNode = null;		// The industry which produces the cargo.
	toIndustryNode = null;			// The industry which accepts the produced cargo.
	
	cargoID = 0;			// The cargo to transport.
	
	cost = 0;			// The cost of this operation.
	
	function Print() {
		print("Build a road from " + AIIndustry.GetName(fromIndustryNode.industryID) + " to " + AIIndustry.GetName(toIndustryNode.industryID) +
		" transporting " + AICargo.GetCargoLabel(cargoID) + " and build " + nrVehicles + " vehicles. Cost: " +
		cost + " income per month per vehicle: " + profitPerMonthPerVehicle);
	}
}
