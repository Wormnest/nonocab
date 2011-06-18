class WaterPathFinderHelper extends PathFinderHelper {

	standardOffsets = null;
	straightOffsets = null;
	costTillEnd     = Tile.diagonalRoadLength;           // The cost for each tile till the end.
	startLocationIsBuildOnWater = false;
	endLocationIsBuildOnWater = false;
	
	vehicleType = AIVehicle.VT_WATER;
	
	constructor() {
		standardOffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0),
				   AIMap.GetTileIndex(1, 1), AIMap.GetTileIndex(1, -1), AIMap.GetTileIndex(-1, -1), AIMap.GetTileIndex(-1, 1)];
		straightOffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
		emptyList = AIList();
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
		if (!AITile.IsWaterTile(nextTile))
			continue;

		local annotatedTile = AnnotatedTile();
		annotatedTile.direction = offset;
		annotatedTile.tile = nextTile;
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
	tileList.Valuate(AITile.IsCoastTile);
	tileList.KeepValue(1);

	local newList = AITileList();

	foreach (i, value in tileList) {
	
		local slope = AITile.GetSlope(i);
		if (slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NE && slope != AITile.SLOPE_SE || !AIMarine.BuildDock(i, AIStation.STATION_NEW) || AIMarine.IsDockTile(i))
			continue;

		local annotatedTile = AnnotatedTile();
		annotatedTile.tile = i;
		annotatedTile.parentTile = annotatedTile;               // Small hack ;)
		
		// We preprocess all start nodes to see if a road station can be build on them.
		local neighbours = GetNeighbours(annotatedTile, true, emptyList);

		foreach (neighbour in neighbours) {
			if (callbackFunction(annotatedTile, neighbour, heap, expectedEnd))
				newList.AddTile(neighbour.tile);
		}
	}
	return newList;
}

function WaterPathFinderHelper::ProcessStartPositions(heap, startList, checkStartPositions, expectedEnd) {

	if (startLocationIsBuildOnWater) {

		foreach (i, value in startList) {
			local annotatedTile = AnnotatedTile();
			annotatedTile.tile = i;
			annotatedTile.parentTile = annotatedTile;               // Small hack ;)
			
			// We preprocess all start nodes to see if a road station can be build on them.
			local neighbours = GetNeighbours(annotatedTile, true, emptyList);
				
			foreach (neighbour in neighbours) {
				local offset = annotatedTile.tile - neighbour.tile;
	
				if (!AIMap.GetTileX(offset) || !AIMap.GetTileY(offset))
					neighbour.distanceFromStart = Tile.diagonalRoadLength;
				else
					neighbour.distanceFromStart = Tile.straightRoadLength;
	
				neighbour.parentTile = annotatedTile;
				neighbour.length = 1;
					
				heap.Insert(neighbour, AIMap.DistanceManhattan(neighbour.tile, expectedEnd) * costTillEnd);
			}
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

	if (!endLocationIsBuildOnWater) {
		local newEndList = ProcessNeighbours(endList, function(annotatedTile, neighbour, heap, expectedEnd) {
			return true;
		}, null, null);

		endList.Clear();
		endList.AddList(newEndList);
	}
}


function WaterPathFinderHelper::CheckGoalState(at, end, checkEndPositions, closedList) {
	at.tile = at.tile + at.direction;
	// If we need to check the end positions then we either have to be able to build a road station
	// Either the slope is flat or it is downhill, othersie we can't build a depot here
	// Don't allow a tunnel to be near the planned end points because it can do terraforming, there by ruining the prospected location.
	if (checkEndPositions && (endLocationIsBuildOnWater || !AIMarine.BuildDock(at.tile, AIStation.STATION_NEW))) {

		at.tile = at.tile - at.direction;
		// Something went wrong, the original end point isn't valid anymore! We do a quick check and remove any 
		// endpoints that aren't valid anymore.
		end.RemoveTile(at.tile);

		if (end.IsEmpty()) {
			Log.logDebug("End list is empty, original goal isn't satisviable anymore.");
			return null;
		}
		return false;
	}
	return true;
}
