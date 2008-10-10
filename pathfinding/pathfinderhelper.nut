class PathFinderHelper {

	/**
	 * Search for all tiles which are reachable from the given tile, either by road or
	 * by building bridges and tunnels or exploiting existing onces.
	 * @param currentAnnotatedTile An instance of AnnotatedTile from where to search from.
	 * @return An array of annotated tiles.
	 */
	function GetNeighbours(currentAnnotatedTile);
	
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
}

function PathFinderHelper::GetNeighbours(currentAnnotatedTile) {

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
				    
				    local annotatedTile = AnnotatedTile();
					annotatedTile.type = type;
					annotatedTile.direction = offset;
					annotatedTile.tile = otherEnd;
					annotatedTile.bridgeOrTunnelAlreadyBuild = true;
					tileArray.push(annotatedTile);
				    isBridgeOrTunnelEntrance = true;
				}
			}
		}


		/** 
		 * If it is neither a tunnel or a bridge, we try to build one
		 * our selves.
		 */
		if (!isBridgeOrTunnelEntrance) {

			foreach (bridge in GetBridges(nextTile, offset)) {
			    local annotatedTile = AnnotatedTile();
				annotatedTile.type = Tile.BRIDGE;
				annotatedTile.direction = offset;
				annotatedTile.tile = bridge;
				annotatedTile.bridgeOrTunnelAlreadyBuild = false;
				tileArray.push(annotatedTile);
			}
			
			foreach (tunnel in GetTunnels(nextTile, currentAnnotatedTile.tile)) {
			    local annotatedTile = AnnotatedTile();
				annotatedTile.type = Tile.TUNNEL;
				annotatedTile.direction = offset;
				annotatedTile.tile = tunnel;
				annotatedTile.bridgeOrTunnelAlreadyBuild = false;
				tileArray.push(annotatedTile);
			}

			
			// Besides the tunnels and bridges, we also add the tiles
			// adjacent to the currentTile.
		    local annotatedTile = AnnotatedTile();
			annotatedTile.type = Tile.ROAD;
			annotatedTile.direction = offset;
			annotatedTile.tile = nextTile;
			annotatedTile.bridgeOrTunnelAlreadyBuild = false;
			tileArray.push(annotatedTile);
		}
	}

	return tileArray;
}



function PathFinderHelper::GetBridges(startNode, direction) {

	if (Tile.GetSlope(startNode, direction) != 2) return [];
	local tiles = [];

	for (local i = 2; i < 20; i++) {
		local bridge_list = AIBridgeList_Length(i);
		local target = startNode + i * direction;
		if (Tile.GetSlope(target, direction) == 1 && !bridge_list.IsEmpty() && AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bridge_list.Begin(), startNode, target)) {
			tiles.push(target);
			break;
		}
	}
	
	return tiles;
}
	
function PathFinderHelper::GetTunnels(startNode, previousNode) {

	local slope = AITile.GetSlope(startNode);
	if (slope == AITile.SLOPE_FLAT) return [];
	local tiles = [];
	
	/** Try to build a tunnel */
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
