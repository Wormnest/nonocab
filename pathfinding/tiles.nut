/**
 * This class provides static functions which provide information and perform
 * searches for tiles in the world map.
 */
class Tile {

	// Types of tile.
	static NONE   = 0;
	static BRIDGE = 1;
	static TUNNEL = 2;
	static ROAD   = 3;

	/**
	 * Search for all tiles which are reachable from the given tile, either by road or
	 * by building bridges and tunnels or exploiting existing onces.
	 * @param currentAnnotatedTile An instance of AnnotatedTile from where to search from.
	 * @return An array of structs which hold all information about all tiles reachable
	 * from the given tile: 
	 * [0] = TileIndex
	 * [1] = Direction from parent (TileIndex - Parent.TileIndex)
	 * [2] = Type (i.e. TUNNEL, BRIDGE, or ROAD)
	 * [3] = Utility costs
	 * [4] = *TUNNEL and BRIDGE types only*Already built	 
	 */
	static function GetNeighbours(currentAnnotatedTile);
	
	/**
	 * Get all the tile IDs from the tiles directly adjacent to the given tile ID.
	 * @param currentTile Tile ID.
	 * @return An array with the tile IDs of all tiles around it.
	 * @remark This function does not boundary checking and cannot be used safely on 
	 * border tiles.
	 */
	static function GetTilesAround(currentTile);
	
	/**
	 * Search for all bridges which can be build.
	 * @param startTile The start location for the bridge.
	 * @param direction The direction the bridge must head.
	 * @return An array of tile IDs of all possible end points.
	 */
	static function GetBridges(startTile, direction);
	
	/**
	 * Search for all tunnels which can be build.
	 * @param startTile The start location for the tunnel.
	 * @param direction The direction the tunnel must head.
	 * @return An array of tile IDs of all possible end points.
	 */	
	static function GetTunnels(startTile, direction);
	
	/**
	 * Determine whether the road will be sloped.
	 * @param startNode The node to build from.
	 * @param direction The direction to build to.
	 * @return True if the road will be sloped when building
	 * from the startNode in the given direction, false otherwise.
	 */
	static function IsSlopedRoad(startNode, direction);
	
	/**
	 * Determine if the tile is buildable.
	 * @param node The tile ID to check.
	 * @return True if the tile is buildable, false otherwise.
	 */
	static function IsBuildable(tile);
}

function Tile::GetTilesAround(currentTile) {
	return [currentTile -1, currentTile +1, currentTile - AIMap.GetMapSizeX(), currentTile + AIMap.GetMapSizeX()];
}

function Tile::GetNeighbours(currentAnnotatedTile) {

	local tileArray = [];

	local offsets;
	
	/**
	 * If the tile we want to build from is a bridge or tunnel, the only acceptable way 
	 * to go is foreward. If we fail to do so the pathfinder will try to build invalid
	 * roadpieces by building over the endpoints of bridges and tunnels.
	 */
	if (currentAnnotatedTile.type == Tile.ROAD)
		offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
	else {
		offsets = [currentAnnotatedTile.direction];
	}
	

	foreach (offset in offsets) {
		
		// Don't build in the wrong direction.
		if (offset == -currentAnnotatedTile.direction)
			continue;
		
		local nextTile = currentAnnotatedTile.tile + offset;

		// Check if we can actually build this piece of road or if the slopes render this impossible.
		if (!AIRoad.CanBuildConnectedRoadPartsHere(currentAnnotatedTile.tile, currentAnnotatedTile.parentTile.tile, nextTile) && !AIRoad.AreRoadTilesConnected(currentAnnotatedTile.tile, nextTile))
			continue;
		
		local isBridgeOrTunnelEntrance = false;
		
		// Check if we can exploit excising bridges and tunnels.
		if (AITile.HasTransportType(nextTile, AITile.TRANSPORT_ROAD)) {
			local type = Tile.NONE;
			local otherEnd;
			if (AIBridge.IsBridgeTile(nextTile)) {
				type = Tile.BRIDGE;
				otherEnd = AIBridge.GetOtherBridgeEnd(nextTile);
			} else if (AITunnel.IsTunnelTile(nextTile)) {
				type = Tile.TUNNEL;
				otherEnd = AITunnel.GetOtherTunnelEnd(nextTile);
			}
			
			if (type != Tile.NONE) {
				local direction = otherEnd - nextTile;
				
				// Make sure we're heading in the same direction as the bridge or tunnel we try
				// to connect to, else we end up with false road pieces which try to connect to the
				// side of a bridge.
				if (-direction >= AIMap.GetMapSizeX()                 && offset == -AIMap.GetMapSizeX() ||	// North
				     direction < AIMap.GetMapSizeX() && direction > 0 && offset ==  1 ||			// West
				     direction >= AIMap.GetMapSizeX() 	 	      && offset ==  AIMap.GetMapSizeX() ||	// South
				    -direction < AIMap.GetMapSizeX() && direction < 0 && offset == -1) {			// East
				    	tileArray.push([otherEnd, offset, type, 0, true]);
				    	isBridgeOrTunnelEntrance = true;
				}
			}
		}


		/** 
		 * If it is neither a tunnel or a bridge, we try to build one
		 * our selves.
		 */
		if (!isBridgeOrTunnelEntrance) {

			foreach (bridge in Tile.GetBridges(nextTile, offset)) {
				tileArray.push([bridge, offset, Tile.BRIDGE, 0, false]);
			}
			
			foreach (tunnel in Tile.GetTunnels(nextTile, currentAnnotatedTile.tile)) {
				tileArray.push([tunnel, offset, Tile.TUNNEL, 0, false]);
			}

			
			// Besides the tunnels and bridges, we also add the tiles
			// adjacent to the currentTile.
			tileArray.push([nextTile, offset, Tile.ROAD, 0]);
		}
	}

	return tileArray;
}

function Tile::GetBridges(startNode, direction) 
{
	if (RoadPathFinding.GetSlope(startNode, direction) != 2) return [];
	local tiles = [];

	for (local i = 2; i < 20; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = startNode + i * direction;
		if (RoadPathFinding.GetSlope(target, direction) == 1 && !bridge_list.IsEmpty() && AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bridge_list.Begin(), startNode, target)) {
			tiles.push(target);
			break;
		}
	}
	
	return tiles;
}
	
function Tile::GetTunnels(startNode, previousNode)
{
	local slope = AITile.GetSlope(startNode);
	if (slope == AITile.SLOPE_FLAT) return [];
	local tiles = [];
	
	/** Try to build a tunnel */
	//if (slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SE && slope != AITile.SLOPE_NE) return tiles;
	local other_tunnel_end = AITunnel.GetOtherTunnelEnd(startNode);
	if (!AIMap.IsValidTile(other_tunnel_end)) return tiles;

	local tunnel_length = AIMap.DistanceManhattan(startNode, other_tunnel_end);
	local direction = (other_tunnel_end - startNode) / tunnel_length;
	
	local prev_tile = startNode - direction;
	if (tunnel_length >= 2 && tunnel_length < 20 && prev_tile == previousNode && AIRoad.BuildRoad(other_tunnel_end, other_tunnel_end + direction) &&  (AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, startNode))) {
		tiles.push(other_tunnel_end);
	}
	return tiles;
}

function Tile::IsSlopedRoad(start, middle, end)
{
	local NW = 0; //Set to true if we want to build a road to / from the north-west
	local NE = 0; //Set to true if we want to build a road to / from the north-east
	local SW = 0; //Set to true if we want to build a road to / from the south-west
	local SE = 0; //Set to true if we want to build a road to / from the south-east

	if (middle - AIMap.GetMapSizeX() == start || middle - AIMap.GetMapSizeX() == end) NW = 1;
	if (middle - 1 == start || middle - 1 == end) NE = 1;
	if (middle + AIMap.GetMapSizeX() == start || middle + AIMap.GetMapSizeX() == end) SE = 1;
	if (middle + 1 == start || middle + 1 == end) SW = 1;

	/* If there is a turn in the current tile, it can't be sloped. */
	if ((NW || SE) && (NE || SW)) return false;

	local slope = AITile.GetSlope(middle);
	/* A road on a steep slope is always sloped. */
	if (AITile.IsSteepSlope(slope)) return true;

	/* If only one corner is raised, the road is sloped. */
	if (slope == AITile.SLOPE_N || slope == AITile.SLOPE_W) return true;
	if (slope == AITile.SLOPE_S || slope == AITile.SLOPE_E) return true;

	if (NW && (slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SE)) return true;
	if (NE && (slope == AITile.SLOPE_NE || slope == AITile.SLOPE_SW)) return true;

	return false;
}

function Tile::IsBuildable(tile) {


	// Check if we can actually build here!
	local test = AITestMode();

	// Check if we can build a road station on this tile (then we know for sure it's
	// save to build here :)
	foreach(directionTile in Tile.GetTilesAround(tile)) {
		if(AIRoad.BuildRoadStation(tile, directionTile, true, false, true) || AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) {
			return true;
		}
	}
	return false;
}
