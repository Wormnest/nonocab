/**
 * Industry node which contains all information about an industry and its connections
 * to other industries.
 */
class TownConnectionNode extends ConnectionNode
{

	constructor(id) {
		ConnectionNode.constructor(TOWN_NODE, id);
	}
	
	/**
	 * Get the location of this node.
	 * @return The tile location of this node.
	 */
	function GetLocation() {
		return AITown.GetLocation(id);
	}
	
	function GetProducingTiles(cargoID) {
		//local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		//Log.logWarning("TownConnectionNode.GetProducingTiles not implemented yet.");
		//return AIList();
		return GetTownTiles(false, cargoID);
	}
	
	function GetAcceptingTiles(cargoID) {
		//local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		//Log.logWarning("TownConnectionNode.GetAcceptingTiles not implemented yet.");
		//return AIList();
		return GetTownTiles(true, cargoID);
	}
	
	function GetName() {
		return AITown.GetName(id);
	}
	
	function GetProduction(cargoID) {
		return AITown.GetMaxProduction(id, cargoID);
	}
}
/**
 * Scans tiles who are within town influence.
 */
function TownConnectionNode::GetTownTiles(isAcceptingCargo, cargoID) {
	local list = AITileList();
	local tile = GetLocation();
	local x = AIMap.GetTileX(tile);
	local y = AIMap.GetTileY(tile);
	local x_min = x;
	local x_max = x;
	local y_min = y;
	local y_max = y;
	
	// detect edges.
	for(local i = 0; i < 4; i++)
	{
		// reset.
		tile = GetLocation();
		x = AIMap.GetTileX(tile);
		y = AIMap.GetTileY(tile);
		
		while(AITile.IsWithinTownInfluence(tile, id))
		{
			if(x > x_max){ x_max = x; }
			if(y > y_max){ y_max = y; }
			if(x < x_min){ x_min = x; }
			if(y < y_min){ y_min = y; }
			
			switch(i)
			{
				case 0: x = x - 1; break;
				case 1: y = y - 1; break;
				case 2: x = x + 1; break;
				case 3: y = y + 1; break;
				default: break;
			}
			tile = AIMap.GetTileIndex(x, y);
		}
	}
	
	local isTownToTown = GetProduction(cargoID) > 0;
	if (isTownToTown)
		isAcceptingCargo = true;

	local stationRadius = (!AICargo.HasCargoClass(cargoID, AICargo.CC_PASSENGERS) ? AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP) : AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP)); 
	local minimalAcceptance = (isTownToTown ? 15 : 8);
	local minimalProduction = (isTownToTown ? 15 : 0);
	
	// loop through square.
	for(x = x_min; x <= x_max; x++) {
		for(y = y_min; y <= y_max; y++) {
			tile = AIMap.GetTileIndex(x, y);
			if(AITile.IsWithinTownInfluence(tile, id)) {
				if (isAcceptingCargo && AITile.GetCargoAcceptance(tile, cargoID, 1, 1, stationRadius) > minimalAcceptance ||
				!isAcceptingCargo && AITile.GetCargoProduction(tile, cargoID, 1, 1, stationRadius) > minimalProduction) {
				
					if (isTownToTown && !Tile.IsBuildable(tile))
						continue;
					list.AddTile(tile);
				}
			}
		}
	}

	if (isTownToTown) {
		list.Valuate(AITile.GetCargoAcceptance, cargoID, 1, 1, stationRadius);
		list.Sort(AIAbstractList.SORT_BY_VALUE, false);
		list.KeepTop(5);
	}
	return list;
}
function TownConnectionNode::GetPopulation()
{
	return AITown.GetPopulation(id);
}

function TownConnectionNode::ToString()
{
	return GetName() + " (" + GetPopulation() + ")";
}
