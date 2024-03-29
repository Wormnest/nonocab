
////////////////////////// PATHFINDING ///////////////////////////////////////////////////
/**
 * This class will take care of all pathfinding features.
 */
class RoadPathFinding {


	static toBuildLater = [];		// List of build actions which couldn't be completed the moment
						// they were issued due to temporal problems, but should be able
						// to complete in the (near) future.
									
	// Utility class which helps the pathfinder to reach its goal.
	pathFinderHelper = null;

	emptyList = null;
								
	/**
	 * Create a pathfinder by inserting a couple of utility functions which
	 * will help the A-star algorithm:
	 * @param expandFunction The function which is used to expand the search tree
	 * the parameter provided will be an annotated tile and the algorithm expects
	 * an array of annotated tiles which will be used in the search algorithm.
	 */
	constructor(pathFinderHelper) {
		this.pathFinderHelper = pathFinderHelper;
		emptyList = AIList();
	}

	/**
	 * A* pathfinder to find the fastest path from start to end.
	 * @param start An AIList which contains all the nodes the path can start from.
	 * @param end An AIList which contains all the nodes the path can stop at. The
	 * middle point of these values will be used to guide the pathfinder to its goal.
	 * @param checkStartPoints Check the start points before finding a road.
	 * @param checkEndPoints Check the end points before finding a road.
	 * @param stationType The station type to build.
	 * @param maxPathLength The maximum length of the path (stop afterwards!).
	 * @param tilesToIgnore The set of tiles which the pathfinder should ignore.
	 * @return A PathInfo instance which contains the found path (if any).
	 */
	function FindFastestRoad(start, end, checkStartPositions, checkEndPositions, stationType, maxPathLength, tilesToIgnore);
}

function RoadPathFinding::FindFastestRoad(start, end, checkStartPositions, checkEndPositions, stationType, maxPathLength, tilesToIgnore) {
	Log.logDebug("PathFinding: Find fastest route.");
	// Safety trigger, if we take longer than 3 months to plan for a path, abort!
	local startingDay = AIDate.GetCurrentDate();
	local lastCheckingTime = 0;

	//if (checkStartPositions ) 
	//{
	//	local bla = AIExecMode();
	//	foreach (index, sign in AISignList())
	//		AISign.RemoveSign(index);
	//}

	local test = AITestMode();

	local pq = null;
	local expectedEnd = null;

	// Calculate the central point of the end array
	local x = 0;
	local y = 0;

	local costTillEnd = pathFinderHelper.costTillEnd;
	pathFinderHelper.Reset();

	// Wormnest: Not sure why we need money here. Aren't we only pathfinding here?
	// We will disable this for now.
	/*
	while (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < Finance.minimumBankReserve / 2) {
		Finance.GetMaxLoan();
		AIController.Sleep(1);
	}
	*/

	// There should be no tiles in start that are also defined in end.
	// I've seen this happen when trying to build a water route where the path consisted of a begin and end tile on the same position.
	// Note: This loop has to be done before ProcessEndPositions because the end tiles are changed in that function!
	foreach (tile, value in end) {
		if (start.HasItem(tile)) {
			Log.logDebug("Removing tile " + tile + " from our start list since it's already defined in our end list.");
			// We probably can just return null too since this probably means start and end are too close for a profitable route.
			start.RemoveTile(tile);
		}
	}
	
	// Use the helper to prune all end positions which can't be reached.
	pathFinderHelper.ProcessEndPositions(end, checkEndPositions);

	if(end.IsEmpty()) {
		Log.logDebug("List of usable destinations is empty.");
		return null;
	}

	// To guide the pathfinder we use the mean of all viable end positions.
	local test = 0;
	foreach (i, value in end) {
		x += AIMap.GetTileX(i);
		y += AIMap.GetTileY(i);
	}
	expectedEnd = AIMap.GetTileIndex(x / end.Count(), y / end.Count());
	
	// We must also keep track of all tiles we've already processed, we use
	// a table for that purpose.
	local closedList = {};
	if (tilesToIgnore)
		foreach (tile in tilesToIgnore)
			closedList[tile] <- tile;

	// Start by constructing a fibonacci heap and by adding all start nodes to it.
	pq = FibonacciHeap();
	pathFinderHelper.ProcessStartPositions(pq, start, checkStartPositions, expectedEnd);
	
	// Check if we have a node from which to build.
	if (!pq.Count) {
		Log.logDebug("Pathfinder: No usable start positions for this route; Abort: original #start points: " + start.Count());
		return null;
	}
	
	// Now with the open and closed list we're ready to do some grinding!!!
	local at;
	local updateClosedList = pathFinderHelper.UpdateClosedList();
	while ((at = pq.Pop())) {
		if (at.length + AIMap.DistanceManhattan(at.tile, expectedEnd) > maxPathLength) {
			Log.logDebug("Max length hit, aborting!");
			return null;
		}
			
		// If this node has already been processed, skip it!
		local inClosedList = closedList.rawin(at.tile);
		if(!pathFinderHelper.ProcessTile(inClosedList, at.tile, at.direction))
			continue;

		// Check if this is the end already, if so we've found the shortest route.
		if(end.HasItem(at.tile) && pathFinderHelper.CheckGoalState(at, end, checkEndPositions, closedList)) { 
			local resultList = [];
			local resultTile = at;
			
			// We store the route from back to front!
			while (resultTile.parentTile != resultTile) {
				resultList.push(resultTile);
				resultTile = resultTile.parentTile;
			}
		
			resultList.push(resultTile);
			Log.logDebug("Path found in " + (AIDate.GetCurrentDate() - startingDay) + " days.");
			return PathInfo(resultList, null, null, pathFinderHelper.vehicleType);
		} else if (end.IsEmpty()) {
			Log.logDebug("End list is empty, original goal isn't satisfiable anymore.");
			return null;
		}

		// Get all possible tiles from this annotated tile and add them to the open list.
		local neighbour = null;
		foreach (neighbour in pathFinderHelper.GetNeighbours(at, false, closedList)) {
			neighbour.distanceFromStart += at.distanceFromStart;
			neighbour.parentTile = at;
			
			// Add this neighbour node to the queue.
			pq.Insert(neighbour, neighbour.distanceFromStart + AIMap.DistanceManhattan(neighbour.tile, expectedEnd) * costTillEnd);
		}
		
		// Done! Don't forget to put at into the closed list
		if (updateClosedList)
			closedList[at.tile] <- at.tile;
		
		// Check every 100 iterations if we have run out of time.
		if (++lastCheckingTime == 100) {
			if (AIDate.GetCurrentDate() - startingDay > pathFinderHelper.GetTimeLimit()) {
				Log.logWarning("Time expired (" + (AIDate.GetCurrentDate() - startingDay) + " days), move on!");
				return null;
			}
			lastCheckingTime = 0;
		}
	}

	// Oh oh... No result found :(
	Log.logDebug("No path found!");
	return null;
}

/**
 * Util class to hold a tile and the heuristic value for
 * pathfinding.
 */
class AnnotatedTile {
	tile = 0;               // Instance of AITile
	parentTile = null;      // Needed for backtracking!
	distanceFromStart = 0;  // 'Distance' already travelled from start tile
	direction = 0;          // The direction the road travels to this point.
	type = null;            // What type of infrastructure is this?
	length = 0;	            // The length of the path.
	alreadyBuild = false;	// Is this piece already build?
	forceForward = false;   // Force the sucessor to go forward.
	lastBuildRailTrack = -1; // The last build rail track, needed to determine the next piece.
	reusedPieces = 0;        // The number of consecutive rail pieces which have been reused. Negative numbers give the number of consecutive non reused pieces.
	tilesInSameDirection = 0;// The number of tiles going in the same direction.
}
