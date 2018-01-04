class RailPathFinderHelper extends PathFinderHelper {

	static NEAR_STATION_DISTANCE = 15;
	static MAX_BRIDGE_LENGTH = 15;
	static MAX_TUNNEL_LENGTH = 15;
	
	static PATH_TYPE_PRE    = 0;
	static PATH_TYPE_FIRST  = 1;
	static PATH_TYPE_SECOND = 2;


	/// Warning: BuildRailAction::ConnectRailToStation uses adapted costs for tracks to connect station platforms!
	costForRail 	= 100;      // Cost for utilizing an existing road, bridge, or tunnel.
	costForNewRail	= 1000;     // Cost for building a new road.

	// Wormnest: Cost for bridges and tunnels seem way too low. Changed from 1000 to 2000/1500.
	// @todo Possibly even better for bridges would be to determine a value based on the costs of bridges
	// since NewGRF's can sometimes make them extra expensive.
	
	/// @todo Maybe lower costs tunnel/bridge when we have a lot of money (as long as they are not longer than 5)
	costForBridge 	= 2000;  	// Cost for building a bridge.
	costForTunnel 	= 1000;  	// Cost for building a tunnel.

	/// @todo Do we need an additional value and additional checks for when 90 degree turns are forbidden?

	// Costs for Turn and Slope depend on game settings and because of that are not set here but in constructor!
	costForTurn 	= null;      // Additional cost if the road makes a turn. Original value: 300.
	costForSlope 	= null;      // Additional cost if the road heads up a slope. Going down a slope should always be ok. Original value: 300.
	costForSlopeNear = null;	 // Additional cost if another up slope is close by.
	maxSlopes = 2;				 // Maximum number of consecutive slopes.

	costTillEnd     = 1200;     // The cost for each tile till the end.

	standardOffsets = null;
	dummyAnnotatedTile = null;
	
	vehicleType = AIVehicle.VT_RAIL;
	closed_list = null;
	been_near_end = false;
	
	PathType = 0;				// Type of path that we are finding: pre path, first path, or second path
	
	reverseSearch = null;       // Are we pathfinding from the end point to the begin point?
	startAndEndDoubleStraight = false; // Should the rail to the start and end be two straight rails?
	SLOPE_UP = null;            // The value of an upwards slope. Depends on reverseSearch.
	SLOPE_DOWN = null;		    // The value of a downwards slope. Depends on reverseSearch.
	
	AllowNonSharedRailTracking = true;		// Should be turned off for connecting short pieces of rail like secondary tracks near a station

	updateClosedList = false;
	
	goalAndDirectionTable = null;

	expectedEnd = null;

	currentRailType = null;       // The rail track to use.
	
	constructor(currentRailType_) {
		currentRailType = currentRailType_;
		standardOffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1), AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];

		// Use a temporary dummy tile for heuristics.
		dummyAnnotatedTile = AnnotatedTile();
		dummyAnnotatedTile.type = Tile.ROAD;
		dummyAnnotatedTile.parentTile = dummyAnnotatedTile;
		reverseSearch = false;
		
		closed_list = {};
		goalAndDirectionTable = {};
		updateClosedList = true;
		startAndEndDoubleStraight = false;
		expectedEnd = -1;

		// Multiplier for freight trains: possible values: 1-255.
		local freight_multiplier = (AIGameSettings.GetValue("freight_trains") / 5).tointeger();
		if (freight_multiplier > 0)
			maxSlopes = 1;
		// Adapted from WormAI railbuilder costs.
		if (AIGameSettings.GetValue("train_acceleration_model ") == 0) {
			// Original
			costForSlope = 1000 + freight_multiplier * 100;
			costForSlopeNear = costForSlope;
			costForTurn = 50;
		}
		else {
			// Realistic
			// Slope steepness percentage: values 0-10 allowed.
			costForSlope = 250 + AIGameSettings.GetValue("train_slope_steepness") * 100 + freight_multiplier * 100;
			costForSlopeNear = costForSlope / 2;
			costForTurn = 300;
		}
		PathType = PATH_TYPE_FIRST;
	}
	
	function Reset() { 
		SLOPE_UP = null;
		SLOPE_DOWN = null;
		closed_list = {};
		emptyList = AIList();
		been_near_end = false;
		goalAndDirectionTable = {};
		AIRail.SetCurrentRailType(currentRailType);
	}
	
	function GetTimeLimit() {
		if (PathType == PATH_TYPE_SECOND)
			return 150;	// Since we already built stations and first path we need to try harder (longer)
						// to find a path since demolishing will cost us money.
		else if (PathType == PATH_TYPE_FIRST)
			return 100;	// The maximum time in days we should try to find a path (for rail we use 100 days since rail routes can be long).
		else // assuming PRE PATH
			return 75;
	}
	function UpdateClosedList() { return updateClosedList; }

	/**
	 * Search for all tiles which are reachable from the given tile, either by rail or
	 * by building bridges and tunnels or exploiting existing onces.
	 * @param currentAnnotatedTile An instance of AnnotatedTile from where to search from.
	 * @param onlyRails Take only rails into acccount?
	 * @param closedList All tiles which should not be considered.
	 * @return An array of annotated tiles.
	 */
	function GetNeighbours(currentAnnotatedTile, onlyRails, closedList);

	/**
	 * Get the time it takes a vehicle to travel the given rail track.
	 * @param roadList Array of annotated tiles describing the path of the rail track.
	 * @param engineID The ID of the engine used.
	 * @param cargoEngineID The ID of the wagon engine.
	 * @param forward Traverse the roadList in the given order if true, otherwise 
	 * traverse it from back to the beginning.
	 * @return The number of days it takes a vehicle to traverse the given rail track.
	 */
	function GetTime(roadList, engineID, cargoEngineID, forward);
	
	/**
	 * Check if all the signals in this direction are pointing in the right direction.
	 */
	function CheckSignals(tile, railTrack, direction);

	/**
	 * Process all possible start locations and add all start locations to the given heap.
	 */
	function ProcessStartPositions(heap, startList, checkStartPositions, expectedEnd);

	/**
	 * Process all end positions and update the endList which will be the ultimate list.
	 */
	function ProcessEndPositions(endList, checkEndPositions);

	/**
	 * Check if the given end tile is a valid end tile.
	 */
	function CheckGoalState(at, end, checkEndPosition, closedList);
	
	/**
	 * Try to find a bridge that can be built from startTile in the given direction.
	 * @param startTile The start location for the bridge.
	 * @param direction The direction the bridge must head.
	 * @return An array of tile IDs of all possible end points.
	 */
	function GetBridge(startTile, direction);
	
	/**
	 * Try to find a tunnel that can be built from startTile in the given direction.
	 * @param startTile The start location for the tunnel.
	 * @param direction The direction the tunnel must head.
	 * @return An array of tile IDs of all possible end points.
	 */
	function GetTunnel(startTile, direction);

}

/**
 * For now, we simply select the first possible place where we can build a station. We explore
 * other options later.
 */
function RailPathFinderHelper::ProcessStartPositions(heap, startList, checkStartPositions, expectedEnd) {
	this.expectedEnd = expectedEnd;

	local mapSizeX = AIMap.GetMapSizeX();
	if (!checkStartPositions) {

		local offsets = [1, -1, mapSizeX, -mapSizeX];
		local rail_track_directions = [AIRail.RAILTRACK_NE_SW, AIRail.RAILTRACK_NE_SW, AIRail.RAILTRACK_NW_SE, AIRail.RAILTRACK_NW_SE];
		
		foreach (i, value in startList) {
			
			local preferedDirection = 0;
			if (AIRail.IsRailStationTile(i)) {
				preferedDirection = AIRail.GetRailStationDirection(i);
			} else if (AIRail.GetRailTracks(i) != AIRail.RAILTRACK_INVALID) {
				local railTracks = AIRail.GetRailTracks(i);
				 if ((railTracks & AIRail.RAILTRACK_NE_SW) == AIRail.RAILTRACK_NE_SW)
				 	preferedDirection = AIRail.RAILTRACK_NE_SW;
				 if ((railTracks & AIRail.RAILTRACK_NE_SW) == AIRail.RAILTRACK_NW_SE) {
				 	// If a rail type goes in both directions, let it rest because we don't know
				 	// which option to choose.
				 	if (preferedDirection != null)
				 		preferedDirection = null;
				 	else
				 		preferedDirection = AIRail.RAILTRACK_NW_SE;
				 }
			}

			for (local j = 0; j < 4; j++) {
				
				if (preferedDirection != 0 && preferedDirection != rail_track_directions[j] || !BuildRailTrack(i + offsets[j], rail_track_directions[j]))
					continue;

				// Go in all possible directions.
				// The tile at the beginning of the station.
				local stationBegin = AnnotatedTile();
				stationBegin.tile = i;
				stationBegin.type = Tile.ROAD;
				stationBegin.parentTile = stationBegin;               // Small hack ;)
				stationBegin.forceForward = true;
				stationBegin.direction = offsets[j];
				stationBegin.forceForward = startAndEndDoubleStraight;
			
				// If we can, we store the tile in front of the station.
				local stationBeginFront = AnnotatedTile();
				stationBeginFront.type = Tile.ROAD;
				stationBeginFront.direction = offsets[j];
				stationBeginFront.tile = i + offsets[j];
				stationBeginFront.alreadyBuild = false;
				stationBeginFront.distanceFromStart = costForRail;
				stationBeginFront.parentTile = stationBegin;
				stationBeginFront.length = 1;
				stationBeginFront.lastBuildRailTrack = rail_track_directions[j];
				stationBeginFront.forceForward = startAndEndDoubleStraight;

				heap.Insert(stationBeginFront, AIMap.DistanceManhattan(stationBeginFront.tile, expectedEnd) * costTillEnd);
			}
		}
		
		return;
	}
	
	// TODO: Make this a global value...
	local stationLength = 3;
	
	// Determine middle point.
	local x = 0;
	local y = 0;
	foreach (i, value in startList) {
		x += AIMap.GetTileX(i);
		y += AIMap.GetTileY(i);
	}
	if (x == 0 || y == 0)
		return;
	x = x / startList.Count();
	y = y / startList.Count();
	local middleTile = x + AIMap.GetMapSizeX() * y;
	
	
	foreach (i, value in startList) {
		if (!Tile.IsBuildable(i, false) || 
			AITown.GetRating(AITile.GetClosestTown(i), AICompany.COMPANY_SELF) <= -200)
			continue;

		local offsets = [1, mapSizeX];
		local rail_track_directions = [AIRail.RAILTRACK_NE_SW, AIRail.RAILTRACK_NW_SE];
			
		for (local j = 0; j < 2; j++) {
			
			// Check if we can actually build a train station here (big enough for exit & entry rail.
			if (AIRail.IsRailStationTile(i) ||
				!AIRail.BuildRailStation(i, rail_track_directions[j], 2, stationLength, AIStation.STATION_NEW))
				continue;
			
			if (offsets[j] == 1 &&
				!AITile.IsBuildableRectangle(i - offsets[j] * 3, stationLength + 7, 2))
				continue;
			else if (offsets[j] == mapSizeX &&
				!AITile.IsBuildableRectangle(i - offsets[j] * 3, 2, stationLength + 7))
				continue;

			// Only add the tile furthest away from the industry to the open list.
			if (checkStartPositions && AIMap.DistanceManhattan(i + stationLength * offsets[j], middleTile) > AIMap.DistanceManhattan(i - offsets[j], middleTile) ||
				!checkStartPositions && AITile.IsBuildable(i + offsets[j])) {
	
				// The tile at the beginning of the station.
				local stationBegin = AnnotatedTile();
				stationBegin.tile = i + (stationLength - 1) * offsets[j];
				stationBegin.type = Tile.ROAD;
				stationBegin.parentTile = stationBegin;               // Small hack ;)
				stationBegin.forceForward = true;
				stationBegin.direction = offsets[j];
	
				// If we can, we store the tile in front of the station.
				local stationBeginFront = AnnotatedTile();
				stationBeginFront.type = Tile.ROAD;
				stationBeginFront.direction = offsets[j];
				stationBeginFront.tile = i + stationLength * offsets[j];
				stationBeginFront.alreadyBuild = false;
				stationBeginFront.distanceFromStart = costForRail;
				stationBeginFront.parentTile = stationBegin;
				stationBeginFront.length = 1;
				stationBeginFront.lastBuildRailTrack = rail_track_directions[j];
				stationBeginFront.forceForward = startAndEndDoubleStraight;
				
				heap.Insert(stationBeginFront, AIMap.DistanceManhattan(stationBeginFront.tile, expectedEnd) * costTillEnd);
			} else {
				// The tile at the end of the station.
				local stationEnd = AnnotatedTile();
				stationEnd.tile = i;// + stationLength * offsets[j];
				stationEnd.type = Tile.ROAD;
				stationEnd.parentTile = stationEnd;               // Small hack ;)
				stationEnd.forceForward = true;
				stationEnd.direction = -offsets[j];
	
				// If we can, we store the tile in front of the end of the station.
				local stationEndFront = AnnotatedTile();
				stationEndFront.type = Tile.ROAD;
				stationEndFront.direction = -offsets[j];
				stationEndFront.tile = i - offsets[j];
				stationEndFront.alreadyBuild = false;
				stationEndFront.distanceFromStart = costForRail;
				stationEndFront.parentTile = stationEnd;
				stationEndFront.length = 1;
				stationEndFront.lastBuildRailTrack = rail_track_directions[j];
				stationEndFront.forceForward = startAndEndDoubleStraight;
				
				heap.Insert(stationEndFront, AIMap.DistanceManhattan(stationEndFront.tile, expectedEnd) * costTillEnd);
			}
		}
	}
}

function RailPathFinderHelper::ProcessEndPositions(endList, checkEndPositions) {

	if (!checkEndPositions)
		return;

	local newEndLocations = AITileList();
	local mapSizeX = AIMap.GetMapSizeX();
	local stationLength = 3;

	foreach (i, value in endList) {
		
		// Check if we can actually start here!
		if (!Tile.IsBuildable(i, false) || 
			AITown.GetRating(AITile.GetClosestTown(i), AICompany.COMPANY_SELF) <= -200)
			continue;

		local offsets = [1, mapSizeX];
		local rail_track_directions = [AIRail.RAILTRACK_NE_SW, AIRail.RAILTRACK_NW_SE];
		
		for (local j = 0; j < 2; j++) {
			local stationSizeX, stationSizeY;


			if (offsets[j] == 1) {
				stationSizeX = stationLength + 6;
				stationSizeY = 2;
			} else if (offsets[j] == mapSizeX) {
				stationSizeX = 2;
				stationSizeY = stationLength + 6;
			}

			if (AITile.IsBuildableRectangle(i - offsets[j] * stationLength, stationSizeX, stationSizeY)) 
			{
				goalAndDirectionTable[i + "-" + offsets[j]] <- true;
				goalAndDirectionTable[(i + offsets[j] * (stationLength - 1)) + "-" + (-offsets[j])] <- true;
				newEndLocations.AddTile(i);
			}
			
			if (AITile.IsBuildableRectangle(i - offsets[j] * stationLength * 2, stationSizeX, stationSizeY)) 
			{
				goalAndDirectionTable[i - offsets[j] * (stationLength - 1) + "-" + offsets[j]] <- true;
				goalAndDirectionTable[i + "-" + (-offsets[j])] <- true;
				newEndLocations.AddTile(i);
			}
		}
	}

	endList.Clear();
	endList.AddList(newEndLocations);
}


function RailPathFinderHelper::CheckGoalState(at, end, checkEndPositions, closedList) {


	if (at.type != Tile.ROAD)
		return false;

	// Check if the 'go straight' precondition has been satisfied.
	if (startAndEndDoubleStraight && (at.parentTile.lastBuildRailTrack != at.lastBuildRailTrack || at.parentTile.parentTile.lastBuildRailTrack != at.lastBuildRailTrack))
		return false;
	
	// If this tile has a rail station, check if there is something on it.
	if (AICompany.IsMine(AITile.GetOwner(at.tile))) {
		// If it is a rail station, make sure the rail tile goes in the same direction.
		if (AIRail.IsRailStationTile(at.tile)) {
			if (at.lastBuildRailTrack != AIRail.GetRailStationDirection(at.tile) || at.parentTile.lastBuildRailTrack != at.lastBuildRailTrack ||
			   (startAndEndDoubleStraight && at.parentTile.parentTile.lastBuildRailTrack != at.lastBuildRailTrack))
				return false;
			return true;
		}
		else if (AIRail.GetRailTracks(at.tile) != AIRail.RAILTRACK_INVALID) {
			if ((AIRail.GetRailTracks(at.tile) & at.lastBuildRailTrack) != at.lastBuildRailTrack)
				return false;
			return true;
		}
	}

	local direction;
	if (at.direction == -1 || at.direction == 1)
		direction = AIRail.RAILTRACK_NE_SW;
	else if (at.direction == AIMap.GetMapSizeX() || at.direction == -AIMap.GetMapSizeX())
		direction = AIRail.RAILTRACK_NW_SE;
	else
		return false;
		
	if (at.parentTile.direction != at.direction)
		return false;

	// If we need to check the end positions then we have to be able to build a rail station
	// Either the slope is flat or it is downhill, otherwise we can't build a depot here
	// Don't allow a tunnel to be near the planned end points because it can do terraforming, thereby ruining the prospected location.
	if (checkEndPositions) {

		if (!goalAndDirectionTable.rawin(at.tile + "-" + at.direction))
			return false;

		local mapSizeX = AIMap.GetMapSizeX();
		local aroundStationTile = at.tile + (at.direction == -1 || at.direction == -AIMap.GetMapSizeX() ? 5 * at.direction : -3 * at.direction); 
		local stationTile = at.tile + (at.direction == -1 || at.direction == -mapSizeX ? 2 * at.direction : 0); 

		if (!AIRail.BuildRailStation(stationTile, direction, 2, 3, AIStation.STATION_NEW) ||
			direction == AIRail.RAILTRACK_NE_SW && !AITile.IsBuildableRectangle(aroundStationTile, 9, 2) ||
			direction == AIRail.RAILTRACK_NW_SE && !AITile.IsBuildableRectangle(aroundStationTile, 2, 9) ||
			at.parentTile.type != Tile.ROAD)
			return false;
	}

	return true;
}

/**
 * Get all the offsets from the current tile going in the given direction. CurrentRailTrack
 * is the rail track of the current tile.
 */
function RailPathFinderHelper::GetOffsets(direction, currentRailTrack) {
	local mapSizeX = AIMap.GetMapSizeX();
	local offsets = null;
	if (direction == 1)
		offsets = [1, 1 + mapSizeX, 1 - mapSizeX];
	else if (direction == -1)
		offsets = [-1, -1 + mapSizeX, -1 - mapSizeX];
	else if (direction == mapSizeX)
		offsets = [mapSizeX, mapSizeX - 1, mapSizeX + 1];
	else if (direction == -mapSizeX)
		offsets = [-mapSizeX, -mapSizeX - 1, -mapSizeX + 1];
	
	// South
	else if (direction == 1 + mapSizeX) {
		if (currentRailTrack == AIRail.RAILTRACK_NW_SW)
			offsets = [1, 1 + mapSizeX];
		else
			offsets = [mapSizeX, 1 + mapSizeX];
	}
	// West
	else if (direction == 1 - mapSizeX) {
		if (currentRailTrack == AIRail.RAILTRACK_NW_NE)
			offsets = [-mapSizeX, 1 - mapSizeX];
		else
			offsets = [1, 1 - mapSizeX];
	}
	// East
	else if (direction ==  -1 + mapSizeX) {
		if (currentRailTrack == AIRail.RAILTRACK_NW_NE)
			offsets = [-1, -1 + mapSizeX];
		else
			offsets = [mapSizeX, -1 + mapSizeX];
	}
	// North
	else if (direction ==  -1 - mapSizeX) {
		if (currentRailTrack == AIRail.RAILTRACK_NW_SW)
			offsets = [-mapSizeX, -1 - mapSizeX];
		else
			offsets = [-1, -1 - mapSizeX];
	}
	else
		assert(false);
	
	return offsets;	
}

function RailPathFinderHelper::GetNextAnnotatedTile(offset, nextTile, currentBuildRailTrack) {
	local annotatedTile = AnnotatedTile();
	annotatedTile.type = Tile.ROAD;
	annotatedTile.direction = offset;
	annotatedTile.lastBuildRailTrack = -1;
	annotatedTile.alreadyBuild = false;
	annotatedTile.distanceFromStart = 0;
	annotatedTile.forceForward = false;
	
	local mapSizeX = AIMap.GetMapSizeX();

	/**
	 * Check if we can build a rail track in the direction of offset.
	 * For the first 2 cases (NE, NW, SE, SW) this is quite straightforeward. However,
	 * for the diagonal offsets (N, S, E, W) we need to do some extra work. It is important
	 * to remember that we only check every other tile (as we go diagonal we cut through 2
	 * tiles, but we only really check the first).
	 */
	if (offset == 1 || offset == -1) {
		if (!BuildRailTrack(nextTile, AIRail.RAILTRACK_NE_SW))
			return null;
		annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NE_SW;
	} else if (offset == mapSizeX || offset == -mapSizeX) {
		if (!BuildRailTrack(nextTile, AIRail.RAILTRACK_NW_SE))
			return null;
		annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_SE;
	} else {
		// Whether we can build here depends on the previous rail piece and direction.
		if (offset == mapSizeX - 1) {
		
		// Going East.

			// If the previous rail track is going SE, build in the upper corner.
			if(currentBuildRailTrack == AIRail.RAILTRACK_NW_SE) {
				if (!BuildRailTrack(nextTile + 1, AIRail.RAILTRACK_NW_NE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_NE;
				nextTile += 1;
			}

			// If the previous rail track is going NE, build in the lower corner.
			else if (currentBuildRailTrack == AIRail.RAILTRACK_NE_SW) {
				if (!BuildRailTrack(nextTile - mapSizeX, AIRail.RAILTRACK_SW_SE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_SW_SE;
				nextTile -= mapSizeX;
			}
			
			// If the previous rail track is going E, build according to the previous railtrack.
			else if (currentBuildRailTrack == AIRail.RAILTRACK_SW_SE) {
				if (!BuildRailTrack(nextTile + 1, AIRail.RAILTRACK_NW_NE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_NE;
				nextTile += 1;
			} else if (currentBuildRailTrack == AIRail.RAILTRACK_NW_NE) {
				if (!BuildRailTrack(nextTile - mapSizeX, AIRail.RAILTRACK_SW_SE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_SW_SE;
				nextTile -= mapSizeX;

			} else {
				Log.logWarning("Last build rail track: " + currentBuildRailTrack);
				assert(false);
			}
		} else if (offset == -mapSizeX + 1) {
			
			// Going West.
			
			// If the previous rail track is going SW, build in the upper corner.
			if(currentBuildRailTrack == AIRail.RAILTRACK_NE_SW) {
				if (!BuildRailTrack(nextTile + mapSizeX, AIRail.RAILTRACK_NW_NE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_NE;
				nextTile += mapSizeX;
			}
			
			// If the previous rail track is going NW, build in the lower corner.
			else if (currentBuildRailTrack == AIRail.RAILTRACK_NW_SE) {
				if (!BuildRailTrack(nextTile - 1, AIRail.RAILTRACK_SW_SE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_SW_SE;
				nextTile -= 1;
			}
			
			// If the previous rail track is going W, build according to the previous railtrack.
			else if (currentBuildRailTrack == AIRail.RAILTRACK_SW_SE) {
				if (!BuildRailTrack(nextTile + mapSizeX, AIRail.RAILTRACK_NW_NE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_NE;
				nextTile += mapSizeX;

			} else if (currentBuildRailTrack == AIRail.RAILTRACK_NW_NE) {
				if (!BuildRailTrack(nextTile - 1, AIRail.RAILTRACK_SW_SE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_SW_SE;
				nextTile -= 1;

				} else {
					Log.logWarning("Last build rail track: " + currentBuildRailTrack);
					assert(false);
				}
			} else if (offset == -mapSizeX - 1) {
			
			// Going North.
			
			// If the previous rail track is going NE, build in the left corner.
			if (currentBuildRailTrack == AIRail.RAILTRACK_NE_SW) {
				if (!BuildRailTrack(nextTile + mapSizeX, AIRail.RAILTRACK_NW_SW))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_SW;
				nextTile += mapSizeX;
			}

			// If the previous rail track is going NW, build in the right corner.
			else if (currentBuildRailTrack == AIRail.RAILTRACK_NW_SE) {
				if (!BuildRailTrack(nextTile + 1, AIRail.RAILTRACK_NE_SE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NE_SE;
				nextTile += 1;
			}
			
			// If the previous rail track is going N, build according to the previous railtrack.
			else if (currentBuildRailTrack == AIRail.RAILTRACK_NE_SE) {
				if (!BuildRailTrack(nextTile + mapSizeX, AIRail.RAILTRACK_NW_SW))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_SW;
				nextTile += mapSizeX;

			} else if (currentBuildRailTrack == AIRail.RAILTRACK_NW_SW) {
				if (!BuildRailTrack(nextTile + 1, AIRail.RAILTRACK_NE_SE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NE_SE;
				nextTile += 1;

			} else {
				Log.logWarning("Last build rail track: " + currentBuildRailTrack);
				assert(false);
			}
		} else if (offset == mapSizeX + 1) {
		
		// Going South.

			// If the previous rail track is going SW, build in the right corner.
			if(currentBuildRailTrack == AIRail.RAILTRACK_NE_SW) {
				if (!BuildRailTrack(nextTile - mapSizeX, AIRail.RAILTRACK_NE_SE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NE_SE;
				nextTile -= mapSizeX;
			}
			
			// If the previous rail track is going SE, build in the left corner.
			else if (currentBuildRailTrack == AIRail.RAILTRACK_NW_SE) {
				if (!BuildRailTrack(nextTile - 1, AIRail.RAILTRACK_NW_SW))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_SW;
				nextTile -= 1;
			}
			
			// If the previous rail track is going S, build according to the previous railtrack.
			else if (currentBuildRailTrack == AIRail.RAILTRACK_NE_SE) {
				if (!BuildRailTrack(nextTile - 1, AIRail.RAILTRACK_NW_SW))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_SW;
				nextTile -= 1;
			} else if (currentBuildRailTrack == AIRail.RAILTRACK_NW_SW) {
				if (!BuildRailTrack(nextTile - mapSizeX, AIRail.RAILTRACK_NE_SE))
					return null;
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NE_SE;
				nextTile -= mapSizeX;
			} else {
				Log.logWarning("Last build rail track: " + currentBuildRailTrack);
				assert(false);
			}
		} else {
			assert(false);
		}
	}

	assert (annotatedTile.lastBuildRailTrack != -1);
	annotatedTile.tile = nextTile;
	return annotatedTile;
}

function RailPathFinderHelper::DoRailsCross(railTrack1, railTracks2) {

	// If either of these is not a rail track than it's pretty obvious :).
	if (railTrack1 == AIRail.RAILTRACK_INVALID || railTrack1 == 0 ||
  		railTracks2 == AIRail.RAILTRACK_INVALID || railTracks2 == 0)
  		return false;
	
	// If the rail tracks go in the same direction, they don't cross.
	else if ((railTracks2 & railTrack1) == railTrack1)
		return false;

	// If one of them goes 'straight' it will always cross.
	else if (railTrack1 == AIRail.RAILTRACK_NE_SW ||
		railTrack1 == AIRail.RAILTRACK_NW_SE ||
		(railTracks2 & AIRail.RAILTRACK_NE_SW) == AIRail.RAILTRACK_NE_SW ||
		(railTracks2 & AIRail.RAILTRACK_NW_SE) == AIRail.RAILTRACK_NW_SE)
		return true;

	// All the options left cross if the other rail track is not on the
	// complete opposite side.
	else if (railTrack1 == AIRail.RAILTRACK_NW_NE)
		return (railTracks2 & ~AIRail.RAILTRACK_SW_SE) != 0;
	else if (railTrack1 == AIRail.RAILTRACK_SW_SE)
		return (railTracks2 & ~AIRail.RAILTRACK_NW_NE) != 0;
	else if (railTrack1 == AIRail.RAILTRACK_NW_SW)
		return (railTracks2 & ~AIRail.RAILTRACK_NE_SE) != 0;
	else if (railTrack1 == AIRail.RAILTRACK_NE_SE)
		return (railTracks2 & ~AIRail.RAILTRACK_NW_SW) != 0;
		
	// All options should be exhausted.
	assert (false);
}

function RailPathFinderHelper::GetNeighbours(currentAnnotatedTile, onlyRails, closedList) {

	assert(currentAnnotatedTile.lastBuildRailTrack != -1);
	//{
	//	local abc = AIExecMode();
	//	AISign.BuildSign(currentAnnotatedTile.tile, "X");
	//}
	closed_list[currentAnnotatedTile.tile + "-" + currentAnnotatedTile.direction] <- true;


//	if (currentAnnotatedTile.length >= NEAR_STATION_DISTANCE && AIMap.DistanceManhattan(currentAnnotatedTile.tile, expectedEnd) >= NEAR_STATION_DISTANCE)
//		closedList[currentAnnotatedTile.tile] <- true;


	if (SLOPE_UP == null) {
		if (reverseSearch) {
			SLOPE_UP = 1;
			SLOPE_DOWN = 2;
		}
		else {
			SLOPE_UP = 2;
			SLOPE_DOWN = 1;
		}
	}

	local tileArray = [];
	local offsets;

	local currentTile = currentAnnotatedTile.tile;
	
	/**
	 * If the tile we want to build from is a bridge or tunnel, the only acceptable way 
	 * to go is forward. If we fail to do so the pathfinder will try to build invalid
	 * roadpieces by building over the endpoints of bridges and tunnels.
	 */
	local mapSizeX = AIMap.GetMapSizeX();
	if (currentAnnotatedTile.type == Tile.ROAD && currentAnnotatedTile.parentTile.type == Tile.ROAD && !currentAnnotatedTile.forceForward)
		offsets = GetOffsets(currentAnnotatedTile.direction, currentAnnotatedTile.lastBuildRailTrack);
	else
		offsets = [currentAnnotatedTile.direction];

	foreach (offset in offsets) {
		
		// Don't build in the wrong direction.
		if (offset == -currentAnnotatedTile.direction)
			continue;
		
		local nextTile = currentTile + offset;

		local distanceToEnd = AIMap.DistanceManhattan(nextTile, expectedEnd);
		if (distanceToEnd < NEAR_STATION_DISTANCE / 2)
			been_near_end = true;
		else if (been_near_end && distanceToEnd > NEAR_STATION_DISTANCE)
			continue;
		

		// Check if we're going 'straight'.
		local goingStraight = (offset == 1 || offset == -1 || offset == mapSizeX || offset == -mapSizeX ? true : false);
		local isBridgeOrTunnelEntrance = false;

		// Check if we can exploit existing bridges and tunnels.
		if (!onlyRails && AITile.HasTransportType(nextTile, AITile.TRANSPORT_RAIL) && goingStraight) {
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

				local length = otherEnd - nextTile;
				
				// Make sure we're heading in the same direction as the bridge or tunnel we try
				// to connect to, else we end up with false road pieces which try to connect to the
				// side of a bridge.
				if (-length >= mapSizeX && offset == -mapSizeX ||		// North
				     length <  mapSizeX && length > 0 && offset ==  1 ||	// West
				     length >= mapSizeX && offset ==  mapSizeX ||		// South
				    -length <  mapSizeX && length < 0 && offset == -1) {	// East

					if (length > mapSizeX || length < -mapSizeX)
						length /= mapSizeX; 
				    
				    if (length < 0)
				    	length = -length;
					
					// Don't reuse bridges/tunnels longer than 5 for multiple routes. It might cause slowdowns.
					if (length > 5)
						continue;
				    
					local annotatedTile = AnnotatedTile();
					annotatedTile.type = type;
					annotatedTile.direction = offset;
					annotatedTile.tile = otherEnd;
					annotatedTile.alreadyBuild = true;
					annotatedTile.forceForward = true;
					annotatedTile.length = currentAnnotatedTile.length + length;
					annotatedTile.distanceFromStart = costForRail * (length < 0 ? -length : length);
					if (offset == 1 || offset == -1)
						annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NE_SW;
					else if (offset == AIMap.GetMapSizeX() || offset == -AIMap.GetMapSizeX())
						annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_SE;
					else
						assert(false);
					annotatedTile.tilesInSameDirection = currentAnnotatedTile.tilesInSameDirection + length;
					tileArray.push(annotatedTile);
					isBridgeOrTunnelEntrance = true;
				}
			}
		}

		//onlyRails = false;
		/** 
		 * If neither a bridge or tunnel has been found to exploit, we try to:
		 * 1) Build a bridge or tunnel ourselves.
		 * 2) Build a piece of rail.
		 */
		if (!isBridgeOrTunnelEntrance) {

			// Commenting out currentAnnotatedTile.parentTile.direction == offset makes it easier to build tunnels and bridges.
			// However it leads in certain cases to tracks between depot and station that make it impossible to reach the station.
			/// @todo Figure out how to fix the second problem without having to use the first comparison.
			if (!onlyRails && currentAnnotatedTile.parentTile.direction == offset && currentAnnotatedTile.direction == offset && goingStraight) {
				local tmp;
				if ((tmp = GetBridge(nextTile, offset)) != null || (tmp = GetTunnel(nextTile, currentTile)) != null) {
					tmp.tilesInSameDirection = currentAnnotatedTile.tilesInSameDirection + tmp.length;
					tmp.length += currentAnnotatedTile.length;
					tileArray.push(tmp);
				}
			}

			if (AIRail.IsRailStationTile(currentTile) && AIRail.IsRailStationTile(nextTile))
				continue;
			local previousTile = currentAnnotatedTile.parentTile != currentAnnotatedTile ? currentAnnotatedTile.parentTile.tile : currentAnnotatedTile.tile - offset;
			local railTrackDirection = -1;
			
			local annotatedTile = GetNextAnnotatedTile(offset, nextTile, currentAnnotatedTile.lastBuildRailTrack);
			if (annotatedTile == null)
				continue;
			nextTile = annotatedTile.tile;
			railTrackDirection = annotatedTile.lastBuildRailTrack;
			
			// If the next tile is a rail tile, make sure we do not cross it orthogonally.
			local roadTrack = AIRail.GetRailTracks(nextTile);
			if (roadTrack != AIRail.RAILTRACK_INVALID) {
				if ((roadTrack & AIRail.RAILTRACK_NE_SW) == AIRail.RAILTRACK_NE_SW && 
					railTrackDirection == AIRail.RAILTRACK_NW_SE)
					continue;
				else if ((roadTrack & AIRail.RAILTRACK_NW_SE) == AIRail.RAILTRACK_NW_SE && 
					railTrackDirection == AIRail.RAILTRACK_NE_SW)
					continue;
				else if (((roadTrack & AIRail.RAILTRACK_NW_NE) == AIRail.RAILTRACK_NW_NE ||
					(roadTrack & AIRail.RAILTRACK_SW_SE) == AIRail.RAILTRACK_SW_SE) &&
					(railTrackDirection == AIRail.RAILTRACK_NW_SW || railTrackDirection == AIRail.RAILTRACK_NE_SE))
					continue;
				else if (((roadTrack & AIRail.RAILTRACK_NW_SW) == AIRail.RAILTRACK_NW_SW ||
					(roadTrack & AIRail.RAILTRACK_NE_SE) == AIRail.RAILTRACK_NE_SE) &&
					(railTrackDirection == AIRail.RAILTRACK_NW_NE || railTrackDirection == AIRail.RAILTRACK_SW_SE))
					continue;
			}

			// If the next tile is a road tile, only allow bridges over or bridges beneath it!
			if (AIRoad.IsRoadTile(nextTile))
				continue;

			// Check if the road is sloped.
			//if (Tile.IsSlopedRoad(currentAnnotatedTile.parentTile.tile, currentTile, nextTile))
			/// @todo Should we base on currentTile or nextTile?
			// 1 is slope down. However we search in reverse direction from how we will be travelling so use 2
			
			local slope = Tile.GetSlope(currentTile, offset)
			if (slope == SLOPE_UP) {
				annotatedTile.distanceFromStart = costForSlope;
				local tileParent = currentAnnotatedTile.parentTile;
				local slopeCount = 1;
				local consecutiveSlopes = 1;
				local noSlope = 0;
				// We set a maximum of 3 slopes right after each other!
				for (local i=0; i < 6; i++) {
					if (tileParent == null)
						break;
					local slope = Tile.GetSlope(tileParent.tile, tileParent.direction);
					if (slope == SLOPE_UP) {
						annotatedTile.distanceFromStart += (8-i) * costForSlopeNear;
						if (noSlope == 0 && consecutiveSlopes = maxSlopes)
							annotatedTile.distanceFromStart += costForSlopeNear;
						slopeCount++;
						consecutiveSlopes++;
						noSlope = 0;
					}
					else {
						noSlope++;
						consecutiveSlopes = 0;
						if (noSlope == 2) {
							slopeCount--
							noSlope = 0;
						}
					}
					tileParent = tileParent.parentTile;
					if (slopeCount > 3)
						continue;
				}
			}
			else if (slope == SLOPE_DOWN) {
				// Even though going down in itself isn't bad too many downslopes probably means at some time we will have to go up again.
				// Thus we also use a smaller penalty for going down.
				annotatedTile.distanceFromStart = costForSlope / 10;
			}

			if (currentAnnotatedTile.direction != offset) {
				annotatedTile.distanceFromStart += costForTurn;
				
				/// @todo Multiple turns can be bad as long as the second turn is not in the same direction as before the first turn
				if (currentAnnotatedTile.tilesInSameDirection < 5)
					annotatedTile.distanceFromStart += (8-currentAnnotatedTile.tilesInSameDirection) * costForTurn;
				annotatedTile.tilesInSameDirection = 0;
			} else if (goingStraight) {
				annotatedTile.tilesInSameDirection = currentAnnotatedTile.tilesInSameDirection + 1;
			} else {
				annotatedTile.tilesInSameDirection = currentAnnotatedTile.tilesInSameDirection + 0.5;
			}

			local existingRailTracks = AIRail.GetRailTracks(nextTile);
			local reuseRailTrack = false;
			//local reuseRailTrack = existingRailTracks != AIRail.RAILTRACK_INVALID && (AIRail.GetRailTracks(nextTile) & railTrackDirection) == railTrackDirection;
			if (existingRailTracks != AIRail.RAILTRACK_INVALID) {
				local doRailCross = DoRailsCross(railTrackDirection, existingRailTracks);

				// If this rail tile crosses, the previous cannot cross. I.e. we MUST make use of 
				// a piece of rail if we decide to cross.
				if (doRailCross && 
				    DoRailsCross(currentAnnotatedTile.lastBuildRailTrack, AIRail.GetRailTracks(currentTile)))
					continue;

				reuseRailTrack = (AIRail.GetRailTracks(nextTile) & railTrackDirection) == railTrackDirection;
				
				// If we do not cross nor reuse a rail we cannot allow this rail to be built. Because when
				// we upgrade the rails we upgrade per tile and we cannot have 2 non crossing rails on the
				// same tile as we do not have the means to detect this. Failing to do this will result in
				// trains being stuck after upgrading to an incompetable rail type.
				if (!reuseRailTrack && !doRailCross)
					continue;

				// If we do reuse increment the counter.
				if (reuseRailTrack)
					if (currentAnnotatedTile.reusedPieces < 0)
						annotatedTile.reusedPieces = 1;
					else
						annotatedTile.reusedPieces = currentAnnotatedTile.reusedPieces + 1;

				// If we cross, make sure we have reused at least 6 rail tracks so we can assure
				// we don't get any trouble with the crossings.
				/// @todo Instead of a fixed number (6) we should compute it based on train/station length!
				if (doRailCross && currentAnnotatedTile.reusedPieces < 6 && currentAnnotatedTile.reusedPieces > 0) {
					//Log.logInfo("Reused pieces of track: " + currentAnnotatedTile.reusedPieces);
					continue;
				}
			}

			// If we're reusing a rail track, make sure we don't head in the wrong direction!!!
			if (reuseRailTrack) {
				
				// Make sure the train can ride on this!
				//local currentRailType = AIRail.GetCurrentRailType();
				local tileRailType = AIRail.GetRailType(nextTile);
				if (!AIRail.TrainCanRunOnRail(currentRailType, tileRailType) ||
				    !AIRail.TrainHasPowerOnRail(currentRailType, tileRailType))
					continue;
				
				if (!CheckSignals(annotatedTile.tile, annotatedTile.lastBuildRailTrack, annotatedTile.direction)) {
					//Log.logInfo("Can't reuse track: wrong direction ");
					continue;
				}
				
				// We should have at least 10 rail pieces since start or since the last time we used shared rails before thinking of using shared rails (again).
				/// @todo Instead of a fixed number (10) we should compute it based on train/station length!
				if (currentAnnotatedTile.reusedPieces < 0 && currentAnnotatedTile.reusedPieces > -10) {
					//Log.logInfo("Can't reuse track since reused pieces is: " + currentAnnotatedTile.reusedPieces);
					continue;
				}
				
				annotatedTile.alreadyBuild = true;

				if (!goingStraight)
					annotatedTile.distanceFromStart += costForRail / 2;
				else
					annotatedTile.distanceFromStart += costForRail;
			} else if (!goingStraight)
				annotatedTile.distanceFromStart += costForNewRail / 2;
			else
				annotatedTile.distanceFromStart += costForNewRail;
			
			if (goingStraight)
				annotatedTile.length = currentAnnotatedTile.length + 1;
			else
				annotatedTile.length = currentAnnotatedTile.length + 0.5;
				
			if (!reuseRailTrack)
				if (currentAnnotatedTile.reusedPieces > 0)
					annotatedTile.reusedPieces = 0;
				else if (AllowNonSharedRailTracking) {
					// Zero or negative values to track the number of non shared rail track pieces
					// Note: this should be disabled when building/connecting secondary rail tracks
					// to the first track near a station otherwise you get very long connecting pieces.
					annotatedTile.reusedPieces = currentAnnotatedTile.reusedPieces - 1;
					//Log.logInfo("Reused pieces of track: " + currentAnnotatedTile.reusedPieces);
				}

			tileArray.push(annotatedTile);
		}
	}
	return tileArray;
}

function RailPathFinderHelper::CheckStation(curTile, curRailTrack, curDirection, stationsToIgnore) {

	// Work with an open / closed list. We're doing a breadth first search.
	local openList = [];
	local closedList = {};
	local mapSizeX = AIMap.GetMapSizeX();
	
	openList.push([curTile, curRailTrack, curDirection]);
	
	while (openList.len() > 0) {
		
		local entry = openList[0];
		openList.remove(0);
		
		local tile = entry[0];
		local railTrack = entry[1];
		local direction = entry[2];

		if (closedList.rawin(tile + "-" + direction))
			continue;
		closedList[tile + "-" + direction] <- true;

		if (AIRail.IsRailStationTile(tile)) {

			local stationID = AIStation.GetStationID(tile);
			for (local i = 0; i < stationsToIgnore.len(); i++) {
				if (stationID == stationsToIgnore[i]) {
					stationID = -1;
					break;
				}
			}
			
			if (stationID == -1)
				continue;
			assert(AIStation.IsValidStation(stationID));
			//return AIStation.GetStationID(tile);
			return tile;
		}

		// If non of these are true, search for the next rail!
		//local nextTile = tile + direction;
		local nextOffsets = RailPathFinderHelper.GetOffsets(direction, railTrack);
		
		// Check for all possible rails which can be linked to from here.
		// We do a depth first search to find the connecting station.
		foreach (offset in nextOffsets) {
			local annotatedTile = null;
			
			// Skip over bridges and tunnels.
			if (offset == 1 || offset == -1 || offset == mapSizeX || offset == -mapSizeX) {
				while (AIBridge.IsBridgeTile(tile + offset) || AITunnel.IsTunnelTile(tile + offset)) {
					if (AIBridge.IsBridgeTile(tile + offset)) {
						tile = AIBridge.GetOtherBridgeEnd(tile + offset);
					} else if (AITunnel.IsTunnelTile(tile + offset)){
						tile = AITunnel.GetOtherTunnelEnd(tile + offset);
					}
				}
			}
			annotatedTile = GetNextAnnotatedTile(offset, tile + offset, railTrack);
			
			if (annotatedTile == null)
				continue;

			// Check if this rail exists.
			if (AIRail.GetRailTracks(annotatedTile.tile) != AIRail.RAILTRACK_INVALID && (AIRail.GetRailTracks(annotatedTile.tile) & annotatedTile.lastBuildRailTrack) == annotatedTile.lastBuildRailTrack)
				openList.push([annotatedTile.tile, annotatedTile.lastBuildRailTrack, offset]);
		}
	}
	return -1;
}

function RailPathFinderHelper::CheckSignals(tile, railTrack, direction) {

	//{
	//	local abc = AIExecMode();
	//	AISign.BuildSign(tile, "CS " + direction);
	//}

	if (AIRail.IsRailStationTile(tile)) {
	//	{
	//		local abc = AIExecMode();
	//		AISign.BuildSign(tile, "OK!");
	//	}
		return true;
	}

	// Check if there is a signal on this piece of tile.
	local frontSignalTile = BuildRailAction.GetSignalFrontTile(tile, railTrack, direction);
	local mapSizeX = AIMap.GetMapSizeX();
	local otherDirection = -direction;
	if (direction == 1 + mapSizeX)
		otherDirection = -1 - mapSizeX;
	else if (direction == 1 - mapSizeX)
		otherDirection = -1 + mapSizeX;
	else if (direction == -1 + mapSizeX)
		otherDirection = 1 - mapSizeX;
	else if (direction == -1 - mapSizeX)
		otherDirection = 1 + mapSizeX;
	local backSignalTile = BuildRailAction.GetSignalFrontTile(tile, railTrack, otherDirection);
	
	if (reverseSearch) {
		local tmp = frontSignalTile;
		frontSignalTile = backSignalTile;
		backSignalTile = tmp;
	}
	
	if (AIRail.GetSignalType(tile, backSignalTile) != AIRail.SIGNALTYPE_NONE)
		return false;

	// If this is something else than the 'normal' type we won't allow it!
	local signalRightDirection = AIRail.GetSignalType(tile, frontSignalTile);
	if (signalRightDirection != AIRail.SIGNALTYPE_NONE) {
		if (signalRightDirection != AIRail.SIGNALTYPE_NORMAL)
			return false;
		return true;
	}

	// If non of these are true, search for the next rail!
	//local nextTile = tile + direction;
	local nextOffsets = RailPathFinderHelper.GetOffsets(direction, railTrack);
	
	// Check for all possible rails which can be linked to from here.
	// We do a depth first search to find the connecting station.
	foreach (offset in nextOffsets) {
		local annotatedTile = null;
		
		// Skip over bridges and tunnels.
		if (offset == 1 || offset == -1 || offset == mapSizeX || offset == -mapSizeX) {
			while (AIBridge.IsBridgeTile(tile + offset) || AITunnel.IsTunnelTile(tile + offset)) {
				if (AIBridge.IsBridgeTile(tile + offset))
					tile = AIBridge.GetOtherBridgeEnd(tile + offset);
				else if (AITunnel.IsTunnelTile(tile + offset))
					tile = AITunnel.GetOtherTunnelEnd(tile + offset);
			}
		}
		annotatedTile = GetNextAnnotatedTile(offset, tile + offset, railTrack);
		
		if (annotatedTile == null)
			continue;

		// Check if this rail exists.
		if (AIRail.GetRailTracks(annotatedTile.tile) != AIRail.RAILTRACK_INVALID && (AIRail.GetRailTracks(annotatedTile.tile) & annotatedTile.lastBuildRailTrack) == annotatedTile.lastBuildRailTrack)
			return CheckSignals(annotatedTile.tile, annotatedTile.lastBuildRailTrack, offset);
	}
	return false;
}

function RailPathFinderHelper::BuildRailTrack(tile, railTrack) {
	//local existingTrack = AIRail.GetRailTracks(tile);
	if (AIRail.BuildRailTrack(tile, railTrack) || (AICompany.IsMine(AITile.GetOwner(tile)) && AIRail.GetRailTracks(tile) != AIRail.RAILTRACK_INVALID && (AIRail.GetRailTracks(tile) & railTrack) == railTrack))
		return true;
	return false;
}

function RailPathFinderHelper::ProcessTile(inClosedList, tile, direction) {
	if (inClosedList)
		return false;

	if (closed_list.rawin(tile + "-" + direction))
		return false;
	return true;
}

function RailPathFinderHelper::GetBridge(startNode, direction) {

	//Log.logWarning("Check for bridge!");
	local bridgeRailOrRoad = AIRail.IsRailTile(startNode + direction) || AIRoad.IsRoadTile(startNode + direction);
	if (!bridgeRailOrRoad && Tile.GetSlope(startNode, direction) != SLOPE_DOWN)
		return null;

	/// @todo Check if we already want to build a bridge just before this one. In that case they should be combined into one bridge!
	for (local i = 1; i < MAX_BRIDGE_LENGTH; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = startNode + i * direction;
		if (!AIMap.DistanceFromEdge(target))
			return null;

		if ((Tile.GetSlope(target, direction) == SLOPE_UP || bridgeRailOrRoad) && !bridge_list.IsEmpty() && AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridge_list.Begin(), startNode, target)) {

			// Only allow to build the bridge if the next tile is free as the first tile most go straight.
			if (!AITile.IsBuildable(target + direction))
				continue;

			local annotatedTile = AnnotatedTile();
			annotatedTile.type = Tile.BRIDGE;
			annotatedTile.direction = direction;
			annotatedTile.tile = target;
			annotatedTile.alreadyBuild = false;
			local bridgeLen = i+1;
			local bridgeTileCosts = costForBridge * ((5*bridgeLen+100)/100);  // Increase costs with 5% for each tile extra.
			local bridgeCosts = bridgeTileCosts * bridgeLen;
			if (bridgeLen > 5)
				bridgeCosts += (bridgeLen-5) * bridgeTileCosts;
			annotatedTile.distanceFromStart = bridgeCosts;
			annotatedTile.length = i + 1;
			
			if (direction == 1 || direction == -1)
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NE_SW;
			else if (direction == AIMap.GetMapSizeX() || direction == -AIMap.GetMapSizeX())
				annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_SE;
			else
				assert(false);
			annotatedTile.forceForward = true;
			//Log.logWarning("	Bridge added!");
			return annotatedTile;
		}
	}
	//Log.logWarning("	No bridge found...");
	return null;
}
	
function RailPathFinderHelper::GetTunnel(startNode, previousNode) {

	local slope = AITile.GetSlope(startNode);
	if (slope == AITile.SLOPE_FLAT) return null;
	
	/** Try to build a tunnel */
	local other_tunnel_end = AITunnel.GetOtherTunnelEnd(startNode);
	if (!AIMap.IsValidTile(other_tunnel_end)) return null;

	// Since other end of the tunnel is part of the tunnel we need to add one to distance manhattan.
	local tunnel_length = AIMap.DistanceManhattan(startNode, other_tunnel_end) + 1;
	// Stop immediately if tunnel length is too long or invalid.
	if (tunnel_length < 2 || tunnel_length > MAX_TUNNEL_LENGTH) {
		return null;
	}
	
	local direction = (other_tunnel_end - startNode) / (tunnel_length-1);
	local prev_tile = startNode - direction;
	if (prev_tile == previousNode && AITunnel.BuildTunnel(AIVehicle.VT_RAIL, startNode)) {
		local annotatedTile = AnnotatedTile();
		annotatedTile.type = Tile.TUNNEL;
		annotatedTile.direction = direction;
		annotatedTile.tile = other_tunnel_end;
		annotatedTile.alreadyBuild = false;
		local tunnel_tile_cost = costForTunnel * ((5*tunnel_length+100)/100);  // Increase costs with 5% for each tile extra.
		local tcost =  tunnel_tile_cost * tunnel_length;
		// Up to a length 5 We don't expect slowdowns because we will have a normal signal distance. After that we might expect slowdowns so increase costs for longer lengths.
		if (tunnel_length > 5)
			tcost += (tunnel_length-5) * tunnel_tile_cost;
		annotatedTile.distanceFromStart = tcost;
		annotatedTile.forceForward = true;
		annotatedTile.length = tunnel_length;
		
		if (direction == 1 || direction == -1)
			annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NE_SW;
		else if (direction == AIMap.GetMapSizeX() || direction == -AIMap.GetMapSizeX())
			annotatedTile.lastBuildRailTrack = AIRail.RAILTRACK_NW_SE;
		else
			assert(false);
		return annotatedTile;
	}
	return null;
}

function RailPathFinderHelper::GetTime(roadList, engineID, cargoEngineID, forward) {

	local acceleration = AIEngine.GetPower(engineID) / (4 * AIEngine.GetWeight(engineID));
	local maxSpeed = AIEngine.GetMaxSpeed(engineID);
	/// @todo Take tractive effort into account on slopes and also the hill steepness percentage

	// We need to check if wagon speeds matter and if so lower maxSpeed if wagon speed is lower than engine speed.
	local WagonSpeedMatters = AIController.GetSetting("wagon_speed_limits");
	if (WagonSpeedMatters) {
		local wagonSpeed = AIEngine.GetMaxSpeed(cargoEngineID);
		if (wagonSpeed > 0 && wagonSpeed < maxSpeed) {
			//Log.logDebug("Wagon speed lower than train engine speed: " + wagonSpeed + " instead of " + maxSpeed);
			maxSpeed = wagonSpeed;
		}
	}

	local lastDirection = roadList[0];
	local currentSpeed = 0;
	local carry = 0;
	local hours = 0;
	local lastDirection = 0;

	for (local i = 0; i < roadList.len(); i++) {
		local tile = roadList[i].tile;
		local currentDirection = roadList[i].direction;
		local slope = Tile.GetSlope(tile, currentDirection);

		local tileLength = 0;

		switch (roadList[i].type) {
			case Tile.ROAD:
				if(lastDirection != currentDirection) {		// Bend
					tileLength = Tile.diagonalRoadLength * 24 - carry;
					currentSpeed = maxSpeed / 4;
				} else if (slope == 1 && forward || slope == 2 && !forward) {			// Uphill
					tileLength = Tile.upDownHillRoadLength * 24 - carry;
					
					local slowDowns = 0;
		
					local quarterTileLength = tileLength / 4;
					local qtl_carry = 0;
					
					// Speed decreases 10% 4 times per tile
					for (local j = 0; j < 4; j++) {
						local qtl = quarterTileLength - qtl_carry;
						while (qtl > 0) {
							qtl -= currentSpeed;
							hours++;
						}
						
						currentSpeed *= 0.9;
						qtl_carry = -qtl;
						if (currentSpeed < 34) {
							currentSpeed = 34;
							break;
						}
					}
					
				} else if (slope == 2 && forward || slope == 1 && !forward) {			// Downhill
					tileLength = Tile.upDownHillRoadLength * 24 - carry;
		
					while (tileLength > 0) {
						tileLength -= currentSpeed;
						hours++;
						
						currentSpeed += 74;
						if (currentSpeed >= maxSpeed) {
							currentSpeed = maxSpeed;
							break;
						}
					}
				} else {					// Straight
				///
					tileLength = Tile.straightRoadLength * 24 - carry;
///					
					// Calculate the number of days needed to traverse the tile
					while (tileLength > 0) {
						tileLength -= currentSpeed;
						hours++;

						currentSpeed += acceleration;
						if (currentSpeed > maxSpeed) {
							currentSpeed = maxSpeed;
							break;
						}

					}
///
				}
				break;
				
			case Tile.BRIDGE:
			case Tile.TUNNEL:
				local length = (tile - roadList[i + 1].tile) / currentDirection;
				if (length < 0) length = -length;
				tileLength = Tile.straightRoadLength * length * 24 - carry;
///	
				while (tileLength > 0) {
					tileLength -= currentSpeed;
					hours++;
					
					currentSpeed += acceleration;
					if (currentSpeed > maxSpeed) {
						currentSpeed = maxSpeed;
						break;
					}
				}
				break;
///
		}
			
		if (tileLength > 0) {
			local div = (tileLength / currentSpeed).tointeger();

			carry = tileLength - (currentSpeed * div);
			hours += div;
		} else {
			carry = -tileLength;
		}
		lastDirection = currentDirection;

	}
	//return days.tointeger();
	return (hours / 24).tointeger();
}

