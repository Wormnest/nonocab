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
	
	function GetProducingTiles() {
		//local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		//Log.logWarning("TownConnectionNode.GetProducingTiles not implemented yet.");
		//return AIList();
		return GetTownTiles();
	}
	
	function GetAcceptingTiles() {
		//local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		//Log.logWarning("TownConnectionNode.GetAcceptingTiles not implemented yet.");
		//return AIList();
		return GetTownTiles();
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
function TownConnectionNode::GetTownTiles(){
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
			//Log.logDebug("test (" + x + ", " + y + ")");
			tile = AIMap.GetTileIndex(x, y);
		}
	}
	// loop through square.
	for(x = x_min; x <= x_max; x++)
	{
		for(y = y_min; y <= y_max; y++)
		{
			tile = AIMap.GetTileIndex(x, y);
			if(AITile.IsWithinTownInfluence(tile, id))
			{
				list.AddTile(tile);
			}
		}
	}
	Log.logDebug(GetName() + ": x {" + x_min + ", " + x_max + "}, y {" + y_min + ", " + y_max + "}");
	return list;
}
