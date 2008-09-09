class BuildRoadAction extends Action
{
	pathList = null;
	buildDepot = false;
	buildRoadStations = false;
	directions = null;
	
	constructor(pathList, buildDepot, buildRoadStations)
	{
		this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
		this.pathList = pathList;
		this.buildDepot = buildDepot;
		this.buildRoadStations = buildRoadStations;
		Action.constructor(null);
	}
}

function BuildRoadAction::Execute()
{
	local abc = AIExecMode();
	if (!RoadPathFinding.CreateRoad(pathList))
		Log.logError("Failed to build a road");
	
	if (buildRoadStations) {
		local len = pathList.roadList.len();
		local a = pathList.roadList[0];
		AIRoad.BuildRoadStation(pathList.roadList[0].tile, pathList.roadList[1].tile, true, false, true);
		AIRoad.BuildRoadStation(pathList.roadList[len - 1].tile, pathList.roadList[len - 2].tile, true, false, true);
	}
	
	if (buildDepot) {
		for (local i = 2; i < pathList.roadList.len() - 1; i++) {
			
			foreach (direction in directions) {
				if (Tile.IsBuildable(pathList.roadList[i].tile + direction) && AIRoad.CanBuildConnectedRoadPartsHere(pathList.roadList[i].tile, pathList.roadList[i].tile + direction, pathList.roadList[i + 1].tile)) {
					
					local test = AITestMode();
					if (AIRoad.BuildRoadDepot(pathList.roadList[i].tile + direction, pathList.roadList[i].tile)) {
						local test2 = AIExecMode();
						AIRoad.BuildRoad(pathList.roadList[i].tile + direction, pathList.roadList[i].tile);
						AIRoad.BuildRoadDepot(pathList.roadList[i].tile + direction, pathList.roadList[i].tile);
						pathList.depot = pathList.roadList[i].tile + direction;
						return;
					}
				}
			}
		}
	}
	
	CallActionHandlers();
}