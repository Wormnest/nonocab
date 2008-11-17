class WaterPathFinderHelper extends PathFinderHelper {

	standardOffsets = null;
	costTillEnd     = Tile.diagonalRoadLength;           // The cost for each tile till the end.
	
	constructor() {
		standardOffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0),
				   AIMap.GetTileIndex(1, 1), AIMap.GetTileIndex(1, -1), AIMap.GetTileIndex(-1, -1), AIMap.GetTileIndex(-1, 1)];
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

function WaterPathFinderHelper::GetNeighbours(currentAnnotatedTile, onlyRoads, closedList) {

	local tileArray = [];
	local offsets = standardOffsets;

	foreach (offset in offsets) {
		
		local nextTile = currentAnnotatedTile.tile + offset;

		// Skip if this node is already processed.
		if (closedList.rawin(nextTile))
			continue;

		// Check if this is water or not.
		if (!AITile.IsWaterTile(nextTile))
			continue;

		local annotatedTile = AnnotatedTile();
		annotatedTile.direction = offset;
		annotatedTile.tile = nextTile;

		// Check if the path is diagonal of not.
		if (!AIMap.GetTileX(offset) || !AIMap.GetTileY(offset))
			annotatedTile.distanceFromStart = Tile.diagonalRoadLength;
		else
			annotatedTile.distanceFromStart = Tile.straightRoadLength;

		// At a little insentive to follow straight lines, otherwise there
		// will be way to many bouys!
		if (annotatedTile.direction != currentAnnotatedTile.direction)
			annotatedTile.distanceFromStart += 10;

		tileArray.push(annotatedTile);
	}

	return tileArray;
}

function WaterPathFinderHelper::GetTime(roadList, maxSpeed, forward) {

	local lastTile = roadList[0].tile;
	local distance = 0;

	foreach (at in roadList) {

		local offset = lastTile - at.tile;

		if (!AIMap.GetTileX(offset) || !AIMap.GetTileY(offset))
			distance += Tile.diagonalRoadLength;
		else
			distance += Tile.straightRoadLength;
		lastTile = at.tile;
	}
	return (distance / maxSpeed).tointeger();
}

function WaterPathFinderHelper::ProcessNeighbours(tileList, callbackFunction, heap, expectedEnd) {
	tileList.Valuate(AITile.IsCoastTile);
	tileList.KeepValue(1);

	local newList = AIList();

	foreach (i, value in tileList) {
	
		local slope = AITile.GetSlope(i);
		if (slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NE && slope != AITile.SLOPE_SE || !AIMarine.BuildDock(i, true) && !AIMarine.BuildDock(i, false) || AIMarine.IsDockTile(i))
			continue;

		local annotatedTile = AnnotatedTile();
		annotatedTile.tile = i;
		annotatedTile.parentTile = annotatedTile;               // Small hack ;)
		
		// We preprocess all start nodes to see if a road station can be build on them.
		local neighbours = GetNeighbours(annotatedTile, true, emptyList);

		// Check if the start location has at least 3 neighbours, so we know
		// there is enough water around it for ships to navigate.
		if (neighbours.len() < 3)
			continue;
			
		foreach (neighbour in neighbours) {
			if (callbackFunction(annotatedTile, neighbour, heap, expectedEnd))
				newList.AddItem(neighbour.tile, neighbour.tile);
		}
	}
	return newList;
}

function WaterPathFinderHelper::ProcessStartPositions(heap, startList, checkStartPositions, expectedEnd) {

	ProcessNeighbours(startList, function(annotatedTile, neighbour, heap, expectedEnd) {
			local offset = annotatedTile.tile - neighbour.tile;

			if (!AIMap.GetTileX(offset) || !AIMap.GetTileY(offset))
				neighbour.distanceFromStart = Tile.diagonalRoadLength;
			else
				neighbour.distanceFromStart = Tile.straightRoadLength;

			neighbour.parentTile = annotatedTile;
			neighbour.length = 1;
				
			heap.Insert(neighbour, AIMap.DistanceManhattan(neighbour.tile, expectedEnd) * costTillEnd);
			return false;
		}, heap, expectedEnd);
}

function WaterPathFinderHelper::ProcessEndPositions(endList, checkEndPositions) {

	local newEndList = ProcessNeighbours(endList, function(annotatedTile, neighbour, heap, expectedEnd) {
			return true;
		}, null, null);	

	endList.Clear();
	endList.AddList(newEndList);
}


function WaterPathFinderHelper::CheckGoalState(at, end, checkEndPositions, closedList) {
	at.tile = at.tile + at.direction;
	// If we need to check the end positions then we either have to be able to build a road station
	// Either the slope is flat or it is downhill, othersie we can't build a depot here
	// Don't allow a tunnel to be near the planned end points because it can do terraforming, there by ruining the prospected location.
	if (checkEndPositions && (!AIMarine.BuildDock(at.tile, true) && !AIMarine.BuildDock(at.tile, false))) {

		at.tile = at.tile - at.direction;
		// Something went wrong, the original end point isn't valid anymore! We do a quick check and remove any 
		// endpoints that aren't valid anymore.
		end.RemoveValue(at.tile);

		if (end.IsEmpty()) {
			Log.logDebug("End list is empty, original goal isn't satisviable anymore.");
			return null;
		}
		return false;
	}
	return true;
}
