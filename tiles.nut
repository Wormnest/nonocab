
class Tile {


	static BRIDGE = 0;
	static TUNNEL = 1;
	static ROAD   = 2;

	constructor() {

	}

	static function GetTilesAround(currentAnnotatedTile);
	static function GetTilesAround2(currentTile);
	static function GetBridges(startTile, direction);
	static function GetTunnels(startTile, direction);
	static function IsSlopedRoad(startNode, direction);
	static function IsBuildable(node);
	static function ValidateTurn(startTile, dir);
}

function Tile::GetTilesAround2(currentTile) {
	return [currentTile -1, currentTile +1, currentTile - AIMap.GetMapSizeX(), currentTile + AIMap.GetMapSizeX()];
}

/**
 * Get all the tiles around currentTile, if these tiles happen to be a 
 * starting point of a tunnel or bridge we return the end points of these
 * structures. Also, we explore the possibility to build bridges and
 * tunnels and return those end points as well.
 */
function Tile::GetTilesAround(currentAnnotatedTile) {

	local tileArray = [];

	local offsets;
	
	if (currentAnnotatedTile.type == Tile.ROAD)
		offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
	else {
		offsets = [currentAnnotatedTile.direction];
		if (currentAnnotatedTile.direction != 1 && currentAnnotatedTile.direction != -1 &&  
			currentAnnotatedTile.direction != AIMap.GetMapSizeX() && currentAnnotatedTile.direction != -AIMap.GetMapSizeX())
			Quit();
	}
	

	foreach (offset in offsets) {
		
		// Don't build in the wrong direction
		if (offset == -currentAnnotatedTile.direction)
			continue;
			
		// Check if we can actually build in the orthogonal directions, this is impossible if
		// currentTile is a slope which faces currentDirection.
		if (offset != currentAnnotatedTile.direction && !Tile.ValidateTurn(currentAnnotatedTile.tile, offset))
			continue;
		
		// Check for each tile if it already has a bridge / tunnel
		// or if we could build one.
		local nextTile = currentAnnotatedTile.tile + offset;

		if (AIBridge.IsBridgeTile(nextTile) && AITile.HasTransportType(nextTile, AITile.TRANSPORT_ROAD)) {
			tileArray.push([AIBridge.GetOtherBridgeEnd(nextTile), offset, Tile.BRIDGE, 0]);
		} else if (AITunnel.IsTunnelTile(nextTile) && AITile.HasTransportType(nextTile, AITile.TRANSPORT_ROAD)) {
			tileArray.push([AITunnel.GetOtherTunnelEnd(nextTile), offset, Tile.TUNNEL, 0]);
		}
		
		/** 
		 * If it is neither a tunnel or a bridge, we try to build one
		 * our selves.
		 */
		else {
			//foreach (bridge in Tile.GetBridges(nextTile, offset)) {
			//	tileArray.push([bridge, offset, Tile.BRIDGE, 0]);
			//}
			
			foreach (tunnel in Tile.GetTunnels(nextTile, currentAnnotatedTile.tile)) {
				tileArray.push([tunnel, offset, Tile.TUNNEL, 0]);
			}
			
			// Besides the tunnels and bridges, we also add the tiles
			// adjacent to the currentTile.
			tileArray.push([nextTile, offset, Tile.ROAD, 0]);
		}
	}

	return tileArray;
}

/**
 * Validate whether a turn can be made from the startTile to the
 * given direction.
 */
function Tile::ValidateTurn(startTile, direction) {

	local slope1, slope2;
	if (direction == -AIMap.GetMapSizeX() || direction == AIMap.GetMapSizeX()) {
		slope1 = AITile.SLOPE_NW;
		slope2 = AITile.SLOPE_SE;
	} else if (direction == -1 || direction == 1) {
		slope1 = AITile.SLOPE_NE;
		slope2 = AITile.SLOPE_SW;
	} else {
		print("Fix terraforming123!");
		return false;
	}

	local slope = AITile.GetSlope(startTile);
	
	// We can always turn on flat slopes
	//if (slope & AITile.SLOPE_FLAT)
	//	return true;
	
	// We can never turn on steep slopes
	if ((slope & AITile.SLOPE_STEEP))
		return false;
		
	// If the current road goes up or down a slope (i.e. 2 points are lower, and at 
	// least 1 point is raised), we can't build a turn ON the slope!
	else if (((~slope & slope1) == slope1 && (slope & slope2) != 0) || ((~slope & slope2) == slope2 && (slope & slope1) != 0))
		return false;
	
	// If the tile we're turning to is flat, it is accessible at this point
	//else if (AITile.GetSlope(startTile + direction) & AITile.SLOPE_FLAT)
	//	return true;
	
	// If the current road follows a slope, we can build a turn if the tile has the same height
	// as the slope (i.e. 2 point adjoined to the tile the road is build on is at the same height).
	//
	//                  N    n    W
	//                  ^    *    ^
	//                     -   -
	//                 e *       * w  
	//                     -   -
	//                  v    *    v
	//                  E    s    S
	//
	else {
	
		// Try to turn to the north
		// Road runs from east to west (or visa versa)
		// The lower part is on the north-eastern edge
		// Higher part is on the south-western edge
		if (direction == -AIMap.GetMapSizeX() && (~AITile.GetSlope(startTile) & AITile.SLOPE_NE) == AITile.SLOPE_NE && (AITile.GetSlope(startTile) & AITile.SLOPE_SW) != 0) {
			return false;
		}
		
		// Try to turn to the south
		// Road runs from east to west (or visa versa)
		// The lower part is on the south-western edge
		// Higher part is on the north-eastern edge
		else if (direction == AIMap.GetMapSizeX() && (~AITile.GetSlope(startTile) & AITile.SLOPE_SW) == AITile.SLOPE_SW && (AITile.GetSlope(startTile) & AITile.SLOPE_NE) != 0) {
			return false;
		}
		
		// Try to turn to the west
		// Road runs from north to south (or visa versa)
		// The lower part is on the north-western edge
		// Higher part is on the south-eastern edge
		else if (direction == -1 && (~AITile.GetSlope(startTile) & AITile.SLOPE_NW) == AITile.SLOPE_NW && (AITile.GetSlope(startTile) & AITile.SLOPE_SE) != 0) {
			return false;
		}

		// Try to turn to the east
		// Road runs from north to south (or visa versa)
		// The lower part is on the south-eastern edge
		// Higher part is on the north-western edge
		else if (direction == 1 && (~AITile.GetSlope(startTile) & AITile.SLOPE_SE) == AITile.SLOPE_SE && (AITile.GetSlope(startTile) & AITile.SLOPE_NW) != 0) {
			return false;
		}
	}
	return true;
}

/**
 * Get all bridges and tunnels which can be build on the given node
 * in the given direction.
 */
function Tile::GetBridges(startNode, direction) 
{
	local slope = AITile.GetSlope(startNode);
	if (slope == AITile.SLOPE_FLAT) return [];
	local tiles = [];

	/** Try to build a bridge 
	for (local i = 2; i < 20; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = startNode + i * direction;
		if (!bridge_list.IsEmpty() && AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bridge_list.Begin(), startNode, target)) {
			tiles.push(target);
		}
	}*/
	
	return tiles;
}
	
function Tile::GetTunnels(startNode, previousNode)
{
	local slope = AITile.GetSlope(startNode);
	if (slope == AITile.SLOPE_FLAT) return [];
	local tiles = [];
	
	/** Try to build a tunnel */
	if (slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SE && slope != AITile.SLOPE_NE) return tiles;
	local other_tunnel_end = AITunnel.GetOtherTunnelEnd(startNode);
	if (!AIMap.IsValidTile(other_tunnel_end)) return tiles;

	local tunnel_length = AIMap.DistanceManhattan(startNode, other_tunnel_end);
	local direction = (other_tunnel_end - startNode) / tunnel_length;
	
	local prev_tile = startNode - direction;
	if (tunnel_length >= 2 && tunnel_length < 20 && prev_tile == previousNode && AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, startNode)) {
		tiles.push(other_tunnel_end); //  + direction
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

/**
 * Check if we can actually build something on this tile :).
 */
function Tile::IsBuildable(tile) {


	// Check if we can actually build here!
	if(AITile.IsBuildable(tile)) {
		local test = AITestMode();
		local isBuildable = false;

		// Check if we can build a road station on this tile (then we know for sure it's
		// save to build here :)
		foreach(directionTile in Tile.GetTilesAround2(tile)) {
			if(AIRoad.BuildRoadStation(tile, directionTile, true, false)) {
				return true;
			}
		}
	}

	return false;
}
