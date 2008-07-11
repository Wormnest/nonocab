
////////////////////////// INDUSTRIES ////////////////////////////////////////////////////
/**
 * Apart from pathfinding we need industries to connect!
 */
class IndustryManager
{
	industryInfoList = null;
	industryPaths = null;

	constructor() {

		// Store info about ALL industries
		local industries = AIIndustryList();
		local industryVector = Vector(10);
		for(local i = industries.Begin(); industries.HasNext(); i = industries.Next()) {
			industryVector.Add(IndustryInfo(i));
		}

		industryInfoList = industryVector.ToArray();

		industryPaths = {};
	}

	function UpdateIndustry();	// Lets review our economy and build / destroy / update where needed! :)
}

/**
 * Find industries which can be connected and build roads between them!
 */
function IndustryManager::UpdateIndustry() {
	// Find best industries to match up! :)
	// O(N^2 / 2) time algorithm :/
	for(local i = 0; i < industryInfoList.len() - 1; i++) {

		local industry1 = industryInfoList[i];	// Could be overwritten below
		for(local j = i + 1; j < industryInfoList.len(); j++) {
			local industry2 = industryInfoList[j];

			// Check if we're already running this route (if so, review it! :))
			if(industryPaths.rawin(industry1.industryID + "-" + industry2.industryID)) {
				// Do review stuff...
			} 

			else {
				// Check if this is a possibility :)
				// Check if one of the factories is making what the other can produce (if not, we continue!)
				local fromIndustry = null;
				local toIndustry = null;

				local cargoVector = Vector(5);
				foreach(val in industry1.production) {
					if(industry2.Requires(val)) {
						cargoVector.Add(val);
					}
				}

				// We assume one way dependencies, if factory1 produces
				// cargo required by factory2, factory2 doesn't prodcues
				// cargo required by factory1!
				if(cargoVector.nrElements == 0) {
					foreach(val in industry2.production) {
						if(industry1.Requires(val)) {
							cargoVector.Add(val);
						}
					}

					fromIndustry = industry2;
					toIndustry = industry1;
				} else {
					fromIndustry = industry1;
					toIndustry = industry2;
				}

				if(cargoVector.nrElements == 0)
					continue;


				// Fist check if we can actually afford the road :)
				local pathInfo = null;

				local pathFinder = RoadPathFinding(AIMap(), AIRoad());
				{
					local test = AITestMode();

					print("Find path from " + AIIndustry.GetName(fromIndustry.industryID) + " to " + AIIndustry.GetName(toIndustry.industryID));

					pathInfo = pathFinder.FindFastestRoad(fromIndustry.tilesAroundProducing, toIndustry.tilesAroundAccepting);

					if(!pathInfo)
						continue;
					print("FOUND PATH! " + pathInfo.roadList.len());
					
					

					local accounter = AIAccounting();
					pathFinder.CreateRoad(pathInfo.roadList);
					pathInfo.roadCost = accounter.GetCosts();
				}
				
				local exec = AIExecMode();
				// Check if we can build this (and if we can, do so!)
				local comp = AICompany();
				print("Cost of the road: " + pathInfo.roadCost);
		
				// Calculate if it's affordable :)
				if(pathInfo.roadCost < comp.GetBankBalance(AICompany.MY_COMPANY)) {
					if(!pathFinder.CreateRoad(pathInfo.roadList)) {
						print("[FATAL ERROR] Path creating failed!!!!");

						// You may want to do some more work here ;)
					}

					print("Build! " + pathInfo.roadList.len());

					// Build begin and end stations
					local roadAI = AIRoad();
					AISign.BuildSign(pathInfo.roadList[0].tile, "Begin");
					AISign.BuildSign(pathInfo.roadList[pathInfo.roadList.len() - 1].tile, "End");
					/*if(!roadAI.BuildRoadStation(pathInfo.roadList[0].tile, pathInfo.roadList[1].tile, true, false))
						print("[FATAL ERROR] Failed to build road station!");
					if(roadAI.BuildRoadStation(pathInfo.roadList[pathInfo.roadList.len() - 1].tile, pathInfo.roadList[pathInfo.roadList.len() - 2].tile, true, false))
						print("[FATAL ERROR] Failed to build road station!");
*/
					// Build a road depod :)
					local buildDepot = null;
					for(local roads = 4; roads < pathInfo.roadList.len(); roads++) {
						local depotTiles = Tile.GetTilesAround(pathInfo.roadList[roads].tile);
						
						// Try building one here! :)
						foreach(tile in depotTiles) {
							if(AITile.IsBuildable(tile) && !AIRoad.IsRoadTile(tile)) {
								AIRoad.BuildRoad(pathInfo.roadList[roads].tile, tile);
								AIRoad.BuildRoadDepot(tile, pathInfo.roadList[roads].tile);
								buildDepot = tile;
								break;
							}
						}
						if(buildDepot)
							break;
					}
				}
			}
		}
	}
}

/**
 * Store all info about a certain industry.
 */
class IndustryInfo
{
	tilesAroundProducing = null;		// Tiles around a building, that produce
	tilesAroundAccepting = null;		// Tiles around a building, that accepts
	industryID = null;		// The ID of the industry
	production = null;		// What does this industry produces?
	requirements = null;		// What does this industry accept as cargo?

	constructor(industryID) {
		this.industryID = industryID;
		this.tilesAroundAccepting = AITileList_IndustryAccepting(industryID, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));
		this.tilesAroundProducing = AITileList_IndustryProducing(industryID, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));

		// Get production and requirements of this industry
		production = Vector(3);
		requirements = Vector(2);

		local cargoList = AICargoList();
		for(local i = cargoList.Begin(); cargoList.HasNext(); i = cargoList.Next()) {
			if(AIIndustry.GetProduction(industryID, i) > 0) {
				production.Add(i);
			}

			if(AIIndustry.IsCargoAccepted(industryID, i)) {
				requirements.Add(i);
			}				
		}

		production = production.ToArray();
		requirements = requirements.ToArray();
	}

	/**
	 * Check if this industry produces certain cargo.
	 */
	function Produces(cargo_id) {
		return IsInArray(production, cargo_id);
	}

	/**
	 * Check if this industry requires certain cargo.
	 */
	function Requires(cargo_id) {
		return IsInArray(requirements, cargo_id);
	}
}

/**
 * Class for keeping paths between industries and vehicles in one
 * place :).
 */
class IndustryPath {
	vehicles = null;		// Vehicle ID's
	industry_from = null;		// IndustryInfo instances
	industry_to = null;
	roads = null;			// PathInfo instances

	constructor(industry_from, industry_to, roads) {
		this.industry_from = industry_from;
		this.industry_to = industry_to;
		this.roads = roads;
	}
}
