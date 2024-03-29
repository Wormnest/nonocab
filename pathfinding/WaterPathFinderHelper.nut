class WaterPathFinderHelper extends PathFinderHelper {

	standardOffsets = null;
	straightOffsets = null;
	costTillEnd     = Tile.diagonalRoadLength;           // The cost for each tile till the end.
	startLocationIsBuildOnWater = false;
	endLocationIsBuildOnWater = false;
	
	endDirections = null;								///< AIList tile, direction for endpoints because we need the correct approach direction
	
	vehicleType = AIVehicle.VT_WATER;
	
	constructor() {
		standardOffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0),
				   AIMap.GetTileIndex(1, 1), AIMap.GetTileIndex(1, -1), AIMap.GetTileIndex(-1, -1), AIMap.GetTileIndex(-1, 1)];
		straightOffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
		emptyList = AIList();
		endDirections = AIList();
	}

	/**
	 * Search for all tiles which are reachable from the given tile, either by road or
	 * by building bridges and tunnels or exploiting existing onces.
	 * @param currentAnnotatedTile An instance of AnnotatedTile from where to search from.
	 * @param onlyRoads Take only roads into acccount?
	 * @param closedList All tiles which should not be considered.
	 * @return An array of annotated tiles.
	 */
	function GetNeighbours(currentAnnotatedTile, onlyRoads, closedList);
}

function WaterPathFinderHelper::GetNeighbours(currentAnnotatedTile, onlyStraight, closedList) {

	local tileArray = [];
	local offsets = (onlyStraight ? straightOffsets : standardOffsets);

	foreach (offset in offsets) {
		
		local nextTile = currentAnnotatedTile.tile + offset;

		// Skip if this node is already processed and if this node is on water.
		if (!AITile.IsWaterTile(nextTile) || AIMarine.IsWaterDepotTile(nextTile))
			continue;

		local annotatedTile = AnnotatedTile();
		annotatedTile.direction = offset;
		annotatedTile.tile = nextTile;
		/// @todo This should probably also depend on being diagonal or not (+1 or +0.5). But see line 89.
		annotatedTile.length = currentAnnotatedTile.length + 1;

		// Check if the path is diagonal of not.
		if (!AIMap.GetTileX(offset) || !AIMap.GetTileY(offset))
			annotatedTile.distanceFromStart = Tile.straightRoadLength;
		else
			annotatedTile.distanceFromStart = Tile.diagonalRoadLength;
		tileArray.push(annotatedTile);
	}

	return tileArray;
}

function WaterPathFinderHelper::GetTime(roadList, engineID, forward) {

	local maxSpeed = AIEngine.GetMaxSpeed(engineID);
	local lastTile = roadList[0].tile;
	local distance = 0;

	foreach (at in roadList) {

		local offset = lastTile - at.tile;
		local lastTileX = AIMap.GetTileX(lastTile);
		local lastTileY = AIMap.GetTileY(lastTile);
		local currentX = AIMap.GetTileX(at.tile);
		local currentY = AIMap.GetTileY(at.tile);
		local distanceX = currentX - lastTileX;
		local distanceY = currentY - lastTileY;
		
		if (distanceX < 0) distanceX = -distanceX;
		if (distanceY < 0) distanceY = -distanceY;
		
		local diagonalTiles = 0;
		local straightTiles = 0;
		
		if (distanceX < distanceY) {
			diagonalTiles = distanceX;
			straightTiles = distanceY - diagonalTiles;
		} else {
			diagonalTiles = distanceY;
			straightTiles = distanceX - diagonalTiles;
		}
		
		distance += diagonalTiles * Tile.diagonalRoadLength + straightTiles * Tile.straightRoadLength;
		lastTile = at.tile;
	}
	return (distance / maxSpeed).tointeger();
}

function WaterPathFinderHelper::ProcessNeighbours(tileList, callbackFunction, heap, expectedEnd) {

	/// @todo Check: This seems unnecessary as this valuate is also done in BuildShipYardAction.
	tileList.Valuate(AITile.IsCoastTile);
	tileList.KeepValue(1);

	local newList = AITileList();

	foreach (i, value in tileList) {
	
		local slope = AITile.GetSlope(i);
		if (slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NE && slope != AITile.SLOPE_SE ||
			!AIMarine.BuildDock(i, AIStation.STATION_NEW) || AIMarine.IsDockTile(i))
			continue;

		local annotatedTile = AnnotatedTile();
		annotatedTile.tile = i;
		annotatedTile.parentTile = annotatedTile;               // Small hack ;)
		
		// We preprocess all start nodes to see if it is a valid water tile as required by the second tile of a dock.
		local neighbours = GetNeighbours(annotatedTile, true, emptyList);

		// The way docks are supposed to be built probably even makes it unnecessary to use a foreach since there should be only one neighbour in this case.
		foreach (neighbour in neighbours) {
			// First check to make sure there are no obstacles in front of our proposed dock.
			if (!CheckForWaterObstacles(neighbour))
				continue;
			if (callbackFunction(annotatedTile, neighbour, heap, expectedEnd)) {
				newList.AddTile(neighbour.tile);
				// We need to be able to find the correct approach direction for end points.
				endDirections.AddItem(neighbour.tile, neighbour.direction);
			}
		}
	}
	return newList;
}

/**
 * Check if there are any obstacles on the water on the 2 tiles straight in front of our dock candidate position.
 * @todo Also check the tiles left and right of the dock part that is in the water. I've seen a new built dock blocking another dock this way. Screenshot July 11 1962.
 * However if that other dock is pointing in the same direction it is ok (next to each other). Just not if it's pointing in a different direction.
 * @param at The tile data of the proposed dock part that is in the water.
 * @return Boolean true or false Whether we can safely build a dock here or not.
 */
function WaterPathFinderHelper::CheckForWaterObstacles(at) {
	local tile = at.tile + at.direction;
	if (!AITile.IsWaterTile(tile) || AIMarine.IsWaterDepotTile(tile))
		return false;
	tile = tile + at.direction;
	if (!AITile.IsWaterTile(tile) || AIMarine.IsWaterDepotTile(tile))
		return false;
	
	// Check the tiles beside our dock candidate to see if there is already a dock there with its head turned towards us.
	local tilesToCheck = null;
	if (at.direction == 1 || at.direction == -1) {
		tilesToCheck = [AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
	}
	else {
		tilesToCheck = [1, -1];
	}
	tile = at.tile + tilesToCheck[0];
	if (AIMap.IsValidTile(tile) && AIMarine.IsDockTile(tile)) {
		local stid = AIStation.GetStationID(tile);
		tile = tile + tilesToCheck[0];
		if (AIMap.IsValidTile(tile) && AIMarine.IsDockTile(tile) && stid == AIStation.GetStationID(tile)) {
			// Looks like there is another dock turned towards us. We can't use this for our dock.
			return false;
		}
	}
	tile = at.tile + tilesToCheck[1];
	if (AIMap.IsValidTile(tile) && AIMarine.IsDockTile(tile)) {
		local stid = AIStation.GetStationID(tile);
		tile = tile + tilesToCheck[1];
		if (AIMap.IsValidTile(tile) && AIMarine.IsDockTile(tile) && stid == AIStation.GetStationID(tile)) {
			// Looks like there is another dock turned towards us. We can't use this for our dock.
			return false;
		}
	}
	
	return true;
}

function WaterPathFinderHelper::ProcessStartPositions(heap, startList, checkStartPositions, expectedEnd) {

	if (startLocationIsBuildOnWater) {
		// This is for water industries that have a built in dock only!
		// Note that there are industries on water without a dock, e.g. firs port is built on water
		// but connected to the coast and does not have a dock.

		foreach (i, value in startList) {
			// There should be only 1 value: the dock location tile.
			// The position where ships stop to load is 2 tiles to the south-west of this (Y+2).
			local annotatedTile = AnnotatedTile();
			annotatedTile.tile = i;
			annotatedTile.parentTile = annotatedTile;               // Small hack ;)
			
			// For industry on water with a dock we already know the dock tile.
			// What we do have to check is the tile where the ships will stop at,
			// which always seems to be at offset [2,0] from the dock tile (see discussion on IRC 2018-01-06).
			// So  no need for anything complicated, just check that one tile if its free.
			local shiptile = AnnotatedTile();
			shiptile.tile = i+2;
			shiptile.parentTile = annotatedTile;
			shiptile.length = 1;
			/// @todo Maybe also check that at least one of the 3 neighbors of this tile is also free? (or will that be done in pathfinding? Check!)
			if (AITile.IsWaterTile(shiptile.tile) && !AIMarine.IsWaterDepotTile(shiptile.tile))
				heap.Insert(shiptile, AIMap.DistanceManhattan(shiptile.tile, expectedEnd) * costTillEnd);
		}
	} else {
	
		ProcessNeighbours(startList, function(annotatedTile, neighbour, heap, expectedEnd) {
			local offset = annotatedTile.tile - neighbour.tile;
	
			if (!AIMap.GetTileX(offset) || !AIMap.GetTileY(offset))
				neighbour.distanceFromStart = Tile.straightRoadLength;
			else
				neighbour.distanceFromStart = Tile.diagonalRoadLength;
	
			neighbour.parentTile = annotatedTile;
			neighbour.length = 1;
				
			heap.Insert(neighbour, AIMap.DistanceManhattan(neighbour.tile, expectedEnd) * costTillEnd);
			return false;
		}, heap, expectedEnd);
	}
}

function WaterPathFinderHelper::ProcessEndPositions(endList, checkEndPositions) {

	local newEndList = null;
	if (!endLocationIsBuildOnWater) {
		newEndList = ProcessNeighbours(endList, function(annotatedTile, neighbour, heap, expectedEnd) {
			return true;
		}, null, null);

	}
	else {
		// Industry on water with an inbuilt dock.
		// Since we need to make sure we can approach the docking position on the industry we have to
		// process the endList here too even though we don't need to replace it with neighbours.
		newEndList = AITileList();
		foreach (i, value in endList) {
			// There should be only 1 value in this list: the dock location on the industry.
			local annotatedTile = AnnotatedTile();
			annotatedTile.tile = i;
			annotatedTile.parentTile = annotatedTile;               // Small hack ;)
			
			// For industry on water with a dock we already know the dock tile.
			// What we do have to check is the tile where the ships will stop at,
			// which always seems to be at offset [2,0] from the dock tile (see discussion on IRC 2018-01-06).
			// So  no need for anything complicated, just check that one tile if its free.
			local shiptile = AnnotatedTile();
			shiptile.tile = i+2;
			shiptile.parentTile = annotatedTile;
			shiptile.length = 1;
			/// @todo Maybe also check that at least one of the 3 neighbors of this tile is also free? (or will that be done in pathfinding? Check!)
			if (AITile.IsWaterTile(shiptile.tile) && !AIMarine.IsWaterDepotTile(shiptile.tile)) {
				newEndList.AddTile(shiptile.tile);
				break;
			}
		}
	}
	// Replace endList with new endpoints that all end in the water on a tile in front of a coast tile where a dock can be built.
	endList.Clear();
	endList.AddList(newEndList);
}


function WaterPathFinderHelper::CheckGoalState(at, end, checkEndPositions, closedList) {
	// The direction of the end item can be different from the direction we are coming from with our path.
	// Therefore we need to use the direction of the target end point or we may build the dock in a different direction
	// than we wanted. This may cause the end point to be outside the acceptance range of an accepting industry!
	local endDirection = -endDirections.GetValue(at.tile);
	at.tile = at.tile + endDirection;

	// If we need to check the end positions end it's not built on water then we have to be able to build a dock.
	if (checkEndPositions && (endLocationIsBuildOnWater || !AIMarine.BuildDock(at.tile, AIStation.STATION_NEW))) {

		at.tile = at.tile - endDirection;
		// Something went wrong, the original end point isn't valid anymore! Remove it.
		end.RemoveTile(at.tile);

		// Are there any end points left?
		if (end.IsEmpty()) {
			Log.logDebug("End list is empty, original goal isn't satisfiable anymore.");
			return null;
		}
		return false;
	}
	return true;
}
