/**
 * Industry node which contains all information about an industry and its connections
 * to other industries.
 */
class TownConnectionNode extends ConnectionNode
{

	excludeList = null;			// List of all nodes where no station may be build!

	constructor(id) {
		ConnectionNode.constructor(TOWN_NODE, id);
		excludeList = {};
	}
	
	/**
	 * Get the location of this node.
	 * @return The tile location of this node.
	 */
	function GetLocation() {
		return AITown.GetLocation(id);
	}
	
	function GetProducingTiles(cargoID) {
		return GetTownTiles(false, cargoID);
	}
	
	function GetAcceptingTiles(cargoID) {
		return GetTownTiles(true, cargoID);
	}
	
	function GetName() {
		return AITown.GetName(id);
	}
	
	function GetProduction(cargoID) {
		local productionLastMonth = AITown.GetLastMonthProduction(id, cargoID);
		if (productionLastMonth == 0)
			return AITown.GetMaxProduction(id, cargoID) / 2;
		return productionLastMonth;
	}

	function IsAccepted(cargoID) {
		local stationRadius = (!AICargo.HasCargoClass(cargoID, AICargo.CC_PASSENGERS) ? AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP) : AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP)); 
		return AITile.GetCargoAcceptance(AITown.GetLocation(id), cargoID, 1, 1, stationRadius) > 7;
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
	
	local isTownToTown = AITown.GetMaxProduction(id, cargoID) > 0;
	if (isTownToTown)
		isAcceptingCargo = true;

	local stationRadius = (!AICargo.HasCargoClass(cargoID, AICargo.CC_PASSENGERS) ? AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP) : AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP)); 
	local minimalAcceptance = (isTownToTown ? 15 : 7);
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
		if (excludeList.rawin("" + cargoID))
			list.RemoveList(excludeList["" + cargoID]);
		list.Valuate(AITile.GetCargoAcceptance, cargoID, 1, 1, stationRadius);
		list.Sort(AIAbstractList.SORT_BY_VALUE, false);
		list.KeepTop(1);
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
