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
	industryList = null;			// List of primary industry nodes (which only produces and accepts nothing).
	cargoTransportEngineIds = null;		// The fastest engine IDs to transport the cargos.

	constructor()
	{
		// Construct complete industry node list.
		local industries = AIIndustryList();
		local cargos = AICargoList();
		local industryCacheAccepting = array(cargos.Count());
		local industryCacheProducing = array(cargos.Count());

		cargoTransportEngineIds = array(cargos.Count(), 0);
		industryList = [];

		// Fill the arrays with empty arrays, we can't use:
		// local industryCacheAccepting = array(cargos.Count(), [])
		// because it will all point to the same empty array...
		for (local i = 0; i < cargos.Count(); i++) {
			industryCacheAccepting[i] = [];
			industryCacheProducing[i] = [];
		}
		

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
				industryList.push(industryNode);
			}
		}

		FillTree(industryList);
	}

	/**
	 * Construct a report by finding the largest subset of buildable infrastructure given
	 * the amount of money available to us, which in turn yields the largest income.
	 */
	function getReports()
	{
		local bestOption = null;
		local bestOptionIndustry = null;
		local bestOptionProfit = 0;

		// We want to implement an efficient subsum problem algorithm, but we'll test by choosing the best one, always.
		foreach (industry in industryList) {
			
			// Check the options for this industry:
			foreach (transport in industry.vehiclesOperating) {
				// Calculate income per vehicle:
				local incomePerVehicle = transport.incomePerRun - ((transport.timeToTravelTo + transport.timeToTravelFrom) * AIEngine.GetRunningCost(transport.engineID) / 364);

				local production;
				// Calculate the number of vehicles which can operate:
				for (local i = 0; i < industry.cargoIdsProducing.len(); i++) {
					if (transport.cargoID == industry.cargoIdsProducing[i]) {
						production = industry.cargoProducing[i];
						break;
					}
				}

				local transportedCargoPerVehiclePerMonth = (30.0 / (transport.timeToTravelTo + transport.timeToTravelFrom)) * AIEngine.GetCapacity(transport.engineID);
				local nrVehicles = production / transportedCargoPerVehiclePerMonth;

				// Calculate the profit per month
				local profitPerMonth = nrVehicles * incomePerVehicle * (30.0 / (transport.timeToTravelTo + transport.timeToTravelFrom));

				print("Transported per month: " + transportedCargoPerVehiclePerMonth + "; #vehicles: " + nrVehicles + "; Profit per month: " + profitPerMonth + "; Income per vehicle: " + incomePerVehicle);

				if (profitPerMonth > bestOptionProfit) {
					bestOption = transport;
					bestOptionIndustry = industry;
					bestOptionProfit = profitPerMonth;
				}
			}
		}

		Utils.logInfo("Build transport from " + AIIndustry.GetName(bestOptionIndustry.industryID) + " to " + AIIndustry.GetName(bestOption.travelToIndustry.industryID) + " and transport " + AICargo.GetCargoLabel(bestOption.cargoID));
	}

	/**
	 * Get the transport times and profits for all primary industries.
	 */
	function FillTree(iList) {
		UpdateCargoTransportEngineIds();

		local radius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);

		// Now we have the tree of industries, we now proceed with filling in the blank spots by getting 
		// more information about the differnent connection.
		foreach (primIndustry in industryList) {
			
			// Connect the dots
			local rpf = RoadPathFinding();

			foreach (secondIndustry in primIndustry.industryNodeList) {


				print("Find road from " + AIIndustry.GetName(primIndustry.industryID) + " to " + AIIndustry.GetName(secondIndustry.industryID));
				local pathInfo = rpf.FindFastestRoad(AITileList_IndustryProducing(primIndustry.industryID, radius), AITileList_IndustryAccepting(secondIndustry.industryID, radius));

				// No path found?
				if (pathInfo == null)
					continue;
				primIndustry.costToBuild = rpf.GetCostForRoad(pathInfo.roadList);


				// Check the transport time for each seperate cargo.
				foreach (cargo in primIndustry.cargoIdsProducing) {

					local maxSpeed = AIEngine.GetMaxSpeed(cargoTransportEngineIds[cargo]);
				
					local ic = IndustryConnection();
					ic.timeToTravelTo = rpf.GetTime(pathInfo.roadList, maxSpeed, true);
					ic.timeToTravelFrom = rpf.GetTime(pathInfo.roadList, maxSpeed, false);
					print(ic.timeToTravelTo + " " + ic.timeToTravelFrom);
					ic.incomePerRun = AICargo.GetCargoIncome(cargo, AIMap.DistanceManhattan(pathInfo.roadList[0].tile, pathInfo.roadList[pathInfo.roadList.len() - 1].tile), ic.timeToTravelTo) * AIEngine.GetCapacity(cargoTransportEngineIds[cargo]);
					ic.cargoID = cargo;
					ic.travelToIndustry = secondIndustry;
					ic.engineID = cargoTransportEngineIds[cargo];

					primIndustry.vehiclesOperating.push(ic);
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
		for (local i = 0; i < cargos.Count(); i++) {
			
			local engineList = AIEngineList(AIVehicle.VEHICLE_ROAD);
			foreach (engine, value in engineList) {
				if (AIEngine.GetCargoType(engine) == cargos[i] &&
					AIEngine.GetMaxSpeed(cargoTransportEngineIds[i]) < AIEngine.GetMaxSpeed(engine)) {
					cargoTransportEngineIds[i] = engine;
				}
			}
		}
	}

	/**
	 * Debug purposes only.
	 */
	function PrintTree() {
		print("PrintTree");
		foreach (primIndustry in industryList) {
			PrintNode(primIndustry, 0);
		}
		print("Done!");
	}

	function PrintNode(node, depth) {
		local string = "";
		for (local i = 0; i < depth; i++) {
			string += "      ";
		}

		print(string + AIIndustry.GetName(node.industryID) + "(" + node.costToBuild + ") -> ");

		foreach (transport in node.vehiclesOperating) {
			print("Vehcile travel time: " + transport.timeToTravelTo);
			print("Vehcile income per run: " + transport.incomePerRun);
			print("Cargo: " + AICargo.GetCargoLabel(transport.cargoID));
		}
		foreach (iNode in node.industryNodeList)
			PrintNode(iNode, depth + 1);
	}

}

/**
 * Industry node which contains all information about an industry.
 */
class IndustryNode
{
	industryID = null;			// The ID of the industry.
	cargoIdsProducing = null;		// The cargo IDs which are produced.
	cargoIdsAccepting = null;		// The cargo IDs which are accepted.

	cargoProducing = null;			// The amount of cargo produced.
	industryNodeList = null;		// All industry which accepts the products this industry produces.


	// Parameters below this line are not filled in the constructor.
	costToBuild = null;			// The cost to build this connection.
	vehiclesOperating = null;		// The vehicles operation on this connection (list of Vehicle IDs).

	constructor() {
		cargoIdsProducing = [];
		cargoIdsAccepting = [];
		cargoProducing = [];
		industryNodeList = [];
		vehiclesOperating = [];
	}
}

/**
 * Information for an individual vehicle which runs a certain connection. All
 * inforamtion is dependend on the actual speed of each individual vehicle.
 */
class IndustryConnection
{
	timeToTravelTo = null;
	timeToTravelFrom = null;
	incomePerRun = null;
	engineID = null;
	cargoID = null;
	travelToIndustry = null;
}
