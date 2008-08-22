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
class ConnectionAdvisor
{
	industryList = null;			// List of primary industry nodes (which only produces and accepts nothing).

	constructor()
	{
		// Construct complete industry node list.
		local industries = AIIndustryList();
		local cargos = AICargoList();
		local industryCacheAccepting = array(cargos.Count());
		local industryCacheProducing = array(cargos.Count());

		industryList = [];

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


		cargos = AICargoList();

		foreach (cargo, value in cargos) {
			print(AICargo.GetCargoLabel(cargo));
			print(industryCacheAccepting[cargo].len());
			print(industryCacheProducing[cargo].len());
		}
	}

	function FillTree(iList) {

		local radius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);

		// Now we have the tree of industries, we now proceed with filling in the blank spots by getting 
		// more information about the differnent connection.
		foreach (primIndustry in industryList) {
			
			// Connect the dots
			local rpf = RoadPathFinding();

			foreach (secondIndustry in primIndustry.industryNodeList) {


				print("Find road from " + AIIndustry.GetName(primIndustry.industryID) + " to " + AIIndustry.GetName(secondIndustry.industryID));
				local pathInfo = rpf.FindFastestRoad(AITileList_IndustryProducing(primIndustry.industryID, radius), AITileList_IndustryAccepting(secondIndustry.industryID, radius));

				primIndustry.costToBuild = rpf.GetCostForRoad(pathInfo.roadList);
				
				local ic = IndustryConnection();
				ic.timeToTravelTo = rpf.GetTime(pathInfo.roadList, 48, true);
				ic.timeToTravelFrom = rpf.GetTime(pathInfo.roadList, 48, false);
print(ic.timeToTravelTo + " " + ic.timeToTravelFrom);
				ic.incomePerRun = AICargo.GetCargoIncome(primIndustry.cargoIdsProducing[0], AIMap.DistanceManhattan(pathInfo.roadList[0].tile, pathInfo.roadList[pathInfo.roadList.len() - 1].tile), ic.timeToTravelTo);
				ic.speed = 48;

				primIndustry.vehiclesOperating.push(ic);
			}
		}
	}

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
		print("Vehcile travel time:" + node.vehiclesOperating.timeToTravelTo);
		print("Vehcile income per run:" + node.vehiclesOperating.incomePerRun);
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
	speed = null;
}
