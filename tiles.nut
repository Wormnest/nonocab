
class Tile {

	static NONE   = 0;
	static BRIDGE = 1;
	static TUNNEL = 2;
	static ROAD   = 3;

	constructor() {

	}

	static function GetNeighbours(currentAnnotatedTile);
	static function GetTilesAround(currentTile);
	static function GetBridges(startTile, direction);
	static function GetTunnels(startTile, direction);
	static function IsSlopedRoad(startNode, direction);
	static function IsBuildable(node);
	static function ValidateTurn(startTile, dir);
}

function Tile::GetTilesAround(currentTile) {
	return [currentTile -1, currentTile +1, currentTile - AIMap.GetMapSizeX(), currentTile + AIMap.GetMapSizeX()];
}

/**
 * Get all the tiles around currentTile, if these tiles happen to be a 
 * starting point of a tunnel or bridge we return the end points of these
 * structures. Also, we explore the possibility to build bridges and
 * tunnels and return those end points as well.
 */
function Tile::GetNeighbours(currentAnnotatedTile) {

	local tileArray = [];

	local offsets;
	
	if (currentAnnotatedTile.type == Tile.ROAD)
		offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
	else {
		offsets = [currentAnnotatedTile.direction];
	}
	

	foreach (offset in offsets) {
		
		// Don't build in the wrong direction
		if (offset == -currentAnnotatedTile.direction)
			continue;
		
		// Check for each tile if it already has a bridge / tunnel
		// or if we could build one.
		local nextTile = currentAnnotatedTile.tile + offset;

		// Check if we can actually build this piece of road.
		if (!AIRoad.CanBuildConnectedRoadPartsHere(currentAnnotatedTile.tile, currentAnnotatedTile.parentTile.tile, nextTile))
			continue;
		
		local isBridgeOrTunnelEntrance = false;
		
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
				    	tileArray.push([otherEnd, offset, type, 0]);
				    	isBridgeOrTunnelEntrance = true;
				}
			}
		}
		
		/** 
		 * If it is neither a tunnel or a bridge, we try to build one
		 * our selves.
		 */
		if (!isBridgeOrTunnelEntrance) {

			if (offset == currentAnnotatedTile.direction) {
				foreach (bridge in Tile.GetBridges(nextTile, offset)) {
					tileArray.push([bridge, offset, Tile.BRIDGE, 0]);
				}
			}
			
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
 * Get all bridges and tunnels which can be build on the given node
 * in the given direction.
 */
function Tile::GetBridges(startNode, direction) 
{
	local slope = AITile.GetSlope(startNode);
	if (slope == AITile.SLOPE_FLAT) return [];
	local tiles = [];

	for (local i = 2; i < 20; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = startNode + i * direction;
		if (!bridge_list.IsEmpty() && AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bridge_list.Begin(), startNode, target)) {
			tiles.push(target);
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
	if (tunnel_length >= 2 && tunnel_length < 20 && prev_tile == previousNode && AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, startNode)) {
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
		foreach(directionTile in Tile.GetTilesAround(tile)) {
			if(AIRoad.BuildRoadStation(tile, directionTile, true, false)) {
				return true;
			}
		}
	}

	return false;
}
