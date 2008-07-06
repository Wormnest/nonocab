require("pathfinding.nut");
require("utils.nut");
require("industry.nut");
require("collections.nut");
require("tiles.nut");

class NoCAP extends AIController {
      	stop = false;
      	company = null;
      	townList = null;
	map = null;
	road = null;

      	constructor() {	
		this.company = AICompany();
		this.townList = AITownList();
		this.map = AIMap();
		this.road = AIRoad();
	}

	function Start();
	function Stop();
	function PrintAllTowns();
	function BuildARoad();
}

function NoCAP::Start()
{
	/**
	 * Set the name of our AI :)
	 */
	this.Sleep(1);

	print("Lets go!");

	local cargos = AICargoList();
	for(local i = cargos.Begin(); cargos.HasNext(); i = cargos.Next()) {
		print("Cargo: " + i + " " + AICargo.GetCargoLabel(i));
	}

	if(!this.company.SetCompanyName("NoCAP")) 
	{
		local i = 2;
		while(!this.company.SetCompanyName("NoCAP #" + i))
		{
			i = i + 1;
		}
	}

	// Get max loan!
	while(true) {
		local comp = AICompany();
		comp.SetLoanAmount(comp.GetMaxLoanAmount());

		local indus = IndustryManager();
		indus.UpdateIndustry(this);
        	this.Sleep(500);
	}
}

function NoCAP::Stop()
{
	this.stop = true;
}

function NoCAP::PrintAllTowns()
{
	for(local i = townList.Begin(); townList.HasNext(); i = townList.Next())
	{
		print("Town's name: " + AITown.GetName(i));
		print("Town's population: " + AITown.GetPopulation(i));
		print("Town's location:" + AITown.GetLocation(i));
	}
}

function NoCAP::TestIndustry()
{
	local indus = IndustryManager();
	local road = AIRoad();
	local cargo = AICargo();

	for(local i = 0; i < indus.industryInfoList.len(); i++)
	{
		
		// Look for the first affordable road! :)
		for(local k = 0; k < indus.cargoNumbers.len(); k++) {
			local industryID = indus.industryInfoList[i].industryID;
			print(AIIndustry.GetName(industryID) + " Accepts " + cargo.GetCargoLabel(k) + ": " + AITile.GetCargoAcceptance(AIIndustry.GetLocation(industryID), k, 1, 1, 1) + " and Produces: " + AITile.GetCargoProduction(AIIndustry.GetLocation(industryID), k, 1, 1, 1));
			local list = indus.GetTilesAroundIndustry(industryID);
		
			if(list.nrElements == 0)
				list = indus.GetTilesAroundIndustry(industryID);

			if(list.nrElements == 0)
				continue;	
			
			print("Build road for: " + AIIndustry.GetName(industryID) + " " + list.nrElements);
			for(local j = 0; j < list.nrElements; j++) {
				local tileList = Tile.GetTilesAround(list.elements[j], false, null);
				for(local a = 0; a < tileList.len(); a++) {
					road.BuildRoadFull(list.elements[j], tileList[a]);
				}
			}
		}
	}
}

function NoCAP::BuildARoad()
{
	local mapX = this.map.GetMapSizeX();
	local mapY = this.map.GetMapSizeY();
	print("Map size: " + this.map.GetMapSize());
	print("Map size X: " + mapX);
	print("Map size Y: " + mapY);
/*
	// Try to build in the left top corner:
	local topLeftTile = map.GetTileIndex(5, 5);
	local path = RoadPathFinding(this.map, this.road);
	local myPath2 = path.FindFastestRoad(topLeftTile, 200 + 210 * mapY, 1);
	myPath2.roadCost = path.GetCostForRoad(myPath2.roadList, this);

	print("********* CREATE ROAD! **************");
	print("Path info: " + myPath2.travelDistance + " " + myPath2.rawTravelTime + " " + myPath2.roadCost);
	path.CreateRoad(myPath2.roadList, this);
*/
	print("((((((((((((INDUSTRIES))))))))))))))))))");
	local indus = IndustryManager();
	indus.CreateBestRoad(this.map, this.road, this);
}


/**
 * Lets sleep for a little while :)
 */
function NoCAP::Pause(time)
{
	this.Sleep(time);
}

