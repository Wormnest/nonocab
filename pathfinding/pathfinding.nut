
////////////////////////// PATHFINDING ///////////////////////////////////////////////////
/**
 * This class will take care of all pathfinding features.
 */
class RoadPathFinding {

	// The length of various road pieces
	static straightRoadLength 	= 28.5;					// Road length / 24 (easier to calculate km/h)
	static diagonalRoadLength	= 40.3;
	static bendedRoadLength 	= 20;
	static upDownHillRoadLength = 28.5;

	costForRoad 	= 20;		// Cost for utilizing an existing road, bridge, or tunnel.
	costForNewRoad	= 50;		// Cost for building a new road.
	costForTurn 	= 60;		// Additional cost if the road makes a turn.
	costForBridge 	= 65;		// Cost for building a bridge.
	costForTunnel 	= 65;		// Cost for building a tunnel.
	costForSlope 	= 85;		// Additional cost if the road heads up or down a slope.
	costTillEnd     = 20;           // The cost for each tile till the end.
	
	static toBuildLater = [];		// List of build actions which couldn't be completed the moment
						// they were issued due to temporal problems, but should be able
						// to complete in the (near) future.
									
	// Utility class which helps the pathfinder to reach its goal.
	pathFinderHelper = null;
								
	/**
	 * Create a pathfinder by inserting a couple of utility functions which
	 * will help the A-star algorithm:
	 * @param expandFunction The function which is used to expand the search tree
	 * the parameter provided will be an annotated tile and the algorithm expects
	 * an array of annotated tiles which will be used in the search algorithm.
	 */
	constructor(pathFinderHelper) {
		this.pathFinderHelper = pathFinderHelper;
		costTillEnd = costForRoad;
	}
								
	/**
	 * We need functions to calibrate penalties and stuff. We want functions
	 * to build the *fastest*, *cheapest*, *optimal throughput*, etc. We aren't
	 * allowed to write C++ so we need to script this information :).
	 */
	//function FallBackCreateRoad(buildResult);
	//function CreateRoad(connection);			// Create the best road from start to end
	//function BuildRoad(roadList);
	//function GetSlope(tile, currentDirection);
	//function GetTime(roadList, maxSpeed, forward);
	//function FindFastestRoad(start, end, checkStartPositions, checkEndPositions);
}

/**
 * Get the time it takes a vehicle to travel among the given road.
 * @param roadList Array of annotated tiles which compounds the road.
 * @param maxSpeed The maximum speed of the vehicle.
 * @param forward Traverse the roadList in the given order if true, otherwise 
 * traverse it from back to the begin.
 * @return The number of days it takes a vehicle to traverse the given road
 * with the given maximum speed.
 */
function RoadPathFinding::GetTime(roadList, maxSpeed, forward)
{
	local lastDirection = roadList[0];
	local currentSpeed = 0;
	local carry = 0;
	local days = 0;
	local lastDirection = 0;

	for (local i = 0; i < roadList.len(); i++) {
		local tile = roadList[i].tile;
		local currentDirection = roadList[i].direction;
		local slope = Tile.GetSlope(tile, currentDirection);

		local tileLength = 0;

		switch (roadList[i].type) {
			case Tile.ROAD:
				if(lastDirection != currentDirection) {		// Bend
					tileLength = bendedRoadLength - carry;
					currentSpeed = maxSpeed / 2;
				} else if (slope == 1 && forward || slope == 2 && !forward) {			// Uphill
					tileLength = upDownHillRoadLength - carry;
					
					local slowDowns = 0;
		
					local quarterTileLength = tileLength / 4;
					local qtl_carry = 0;
					
					// Speed decreases 10% 4 times per tile
					for (local j = 0; j < 4; j++) {
						local qtl = quarterTileLength - qtl_carry;
						while (qtl > 0) {
							qtl -= currentSpeed;
							days++;
						}
						
						currentSpeed *= 0.9;
						qtl_carry = -qtl;
						if (currentSpeed < 34) {
							currentSpeed = 34;
							break;
						}
					}
					
				} else if (slope == 2 && forward || slope == 1 && !forward) {			// Downhill
					tileLength = upDownHillRoadLength - carry;
		
					while (tileLength > 0) {
						tileLength -= currentSpeed;
						days++;
						
						currentSpeed += 74;
						if (currentSpeed >= maxSpeed) {
							currentSpeed = maxSpeed;
							break;
						}
					}
				} else {					// Straight
					tileLength = straightRoadLength - carry;
					
					// Calculate the number of days needed to traverse the tile
					while (tileLength > 0) {
						tileLength -= currentSpeed;
						days++;
		
						currentSpeed += 34;
						if (currentSpeed > maxSpeed) {
							currentSpeed = maxSpeed;
							break;
						}
					}
				}
				break;
				
			case Tile.BRIDGE:
			case Tile.TUNNEL:
				local length = (tile - roadList[i + 1].tile) / currentDirection;
				if (length < 0) length = -length;
				tileLength = straightRoadLength * length - carry;
				while (tileLength > 0) {
					tileLength -= currentSpeed;
					days++;
					
					currentSpeed += 34;
					if (currentSpeed > maxSpeed) {
						currentSpeed = maxSpeed;
						break;
					}
				}
				break;
		}
			
		if (tileLength > 0) {
			local div = (tileLength / currentSpeed).tointeger();

			carry = tileLength - (currentSpeed * div);
			days += div;
		} else {
			carry = -tileLength;
		}

		assert (carry >= 0);

		lastDirection = currentDirection;

	}
	return days.tointeger();
}

/**
 * A* pathfinder to find the fastest path from start to end.
 * @param start An AIAbstractList which contains all the nodes the path can start from.
 * @param end An AIAbstractList which contains all the nodes the path can stop at. The
 * middle point of these values will be used to guide the pathfinder to its goal.
 * @param checkStartPoints Check the start points before finding a road.
 * @param checkEndPoints Check the end points before finding a road.
 * @param stationType The station type to build.
 * @param maxPathLength The maximum length of the path (stop afterwards!).
 * @return A PathInfo instance which contains the found path (if any).
 */
function RoadPathFinding::FindFastestRoad(start, end, checkStartPositions, checkEndPositions, stationType, maxPathLength) {

	local test = AITestMode();

	local pq = null;
	local expectedEnd = null;

	// Calculate the central point of the end array
	local x = 0;
	local y = 0;

	local newEndLocations = AIList();

	// Optimalization, use a prefat annotated tile for heuristics.
	local dummyAnnotatedTile = AnnotatedTile();
	dummyAnnotatedTile.type = Tile.ROAD;
	dummyAnnotatedTile.parentTile = dummyAnnotatedTile;

	while (AICompany.GetBankBalance(AICompany.MY_COMPANY) < 1000)
		AIController.Sleep(1);

	if (checkEndPositions) {
		end.Valuate(Tile.IsBuildable);
		end.KeepValue(1);
	}
	
	foreach (i, value in end) {
		if (checkEndPositions) {
			dummyAnnotatedTile.tile = i;

			// We preprocess all end nodes to see if a road station can be build on them.
			local neighbours = pathFinderHelper.GetNeighbours(dummyAnnotatedTile, true);
			
			// We only consider roads which don't go down hill because we can't build road stations
			// on them!
			foreach (neighbour in neighbours) {
				if (Tile.GetSlope(i, neighbour.direction) == 2)
					continue;
					
				newEndLocations.AddItem(i, i);
			}
		}
		x += AIMap.GetTileX(i);
		y += AIMap.GetTileY(i);
	}

	if (checkEndPositions)
		end = newEndLocations;

	if(end.IsEmpty()) {
		Log.logDebug("Could not find a fasted road for an empty endlist.");
		return null;
	}

	expectedEnd = AIMap.GetTileIndex(x / end.Count(), y / end.Count());
	
	// We must also keep track of all tiles we've already processed, we use
	// a table for that purpose.
	local closedList = {};

	// Start by constructing a fibonacci heap and by adding all start nodes to it.
	pq = FibonacciHeap();
	foreach (i, value in start) {
	
		local annotatedTile = AnnotatedTile();
		annotatedTile.tile = i;
		annotatedTile.type = Tile.ROAD;
		annotatedTile.parentTile = annotatedTile;               // Small hack ;)
		
		
		// Check if we can actually start here!
		if(checkStartPositions) {
		
			if (!Tile.IsBuildable(i))
				continue;
			
			// We preprocess all start nodes to see if a road station can be build on them.
			local neighbours = pathFinderHelper.GetNeighbours(annotatedTile, true);
			
			// We only consider roads which don't go down hill because we can't build road stations
			// on them!
			foreach (neighbour in neighbours) {
				local slope = Tile.GetSlope(i, neighbour.direction);
				if (neighbour.type != Tile.ROAD || slope == 2)
					continue;
					
				neighbour.distanceFromStart += (slope == 0 ? costForRoad : costForSlope);
				neighbour.parentTile = annotatedTile;
				neighbour.length = 1;
				
				pq.Insert(neighbour, AIMap.DistanceManhattan(neighbour.tile, expectedEnd) * costTillEnd);
			}
		} else {
			pq.Insert(annotatedTile, AIMap.DistanceManhattan(i, expectedEnd) * costTillEnd);
		}
	}
	
	// Check if we have a node from which to build.
	if (!pq.Count) {
		Log.logDebug("Pathfinder: No start points for this road; Abort: original #start points: " + start.Count());
		return null;
	}

	// Now with the open and closed list we're ready to do some grinding!!!
	local at;
	while ((at = pq.Pop())) {
		if (at.length > maxPathLength) {
			Log.logDebug("Max length hit, aborting!");
			return null;
		}
			
		// Get the node with the best utility value
		if(closedList.rawin(at.tile))
			continue;

		// Check if this is the end already, if so we've found the shortest route.
		if(end.HasItem(at.tile) && at.type == Tile.ROAD) { 

			// If we need to check the end positions then we either have to be able to build a road station
			// Either the slope is flat or it is downhill, othersie we can't build a depot here
			// Don't allow a tunnel to be near the planned end points because it can do terraforming, there by ruining the prospected location.
			if (checkEndPositions && (!AIRoad.BuildRoadStation(at.tile, at.parentTile.tile, true, false, true) || Tile.GetSlope(at.tile, at.direction) == 1 || at.parentTile.type == Tile.TUNNEL)) {

				// Something went wrong, the original end point isn't valid anymore! We do a quick check and remove any 
				// endpoints that aren't valid anymore.
				end.RemoveItem(at.tile);

				// Check the remaining nodes too!
				end.Valuate(Tile.IsBuildable);
				end.KeepValue(1);
				local listToRemove = AITileList();

				foreach (i, value in end) {

					dummyAnnotatedTile.tile = i;
	
					// We preprocess all end nodes to see if a road station can be build on them.
					local neighbours = pathFinderHelper.GetNeighbours(dummyAnnotatedTile, true);
			
					// We only consider roads which don't go down hill because we can't build road stations
					// on them!
					local foundSuitableNeighbour = false;
					foreach (neighbour in neighbours) {
						if (Tile.GetSlope(i, neighbour.direction) != 2) {
							foundSuitableNeighbour = true;
							break;
						}
					}

					if (!foundSuitableNeighbour)
						listToRemove.AddItem(i, i);
				}

				end.RemoveList(listToRemove);

				if (end.IsEmpty()) {
					Log.logDebug("End list is empty, original goal isn't satisviable anymore.");
					return null;
				}
			} else {
				
				local resultList = [];
				local resultTile = at;
			
				while (resultTile.parentTile != resultTile) {
					resultList.push(resultTile);
					resultTile = resultTile.parentTile;
				}
		
				resultList.push(resultTile);
				return PathInfo(resultList, null);
			}
		}
		

		
		// Get all possible tiles from this annotated tile (North, South, West,
		// East) and check if we're already at the end or if new roads are possible
		// from those tiles.
		local neighbour = null;
		foreach (neighbour in pathFinderHelper.GetNeighbours(at, false)) {
		
			// Skip if this node is already processed.
			if (closedList.rawin(neighbour.tile))
				continue;
				
			if (neighbour.type != Tile.ROAD) {
				
				local length = (neighbour.tile - at.tile) / neighbour.direction;
				if (length < 0) length = -length;
				
				// Treat already build bridges and tunnels the same as already build roads.
				if (neighbour.bridgeOrTunnelAlreadyBuild)
					neighbour.distanceFromStart = costForRoad * length;
				else if (neighbour.type == Tile.TUNNEL)
					neighbour.distanceFromStart = costForTunnel * length;
				else
					neighbour.distanceFromStart = costForBridge * length;
			}			
			
			// This is a normal road
			else {
				
				// Check if the road is sloped.
				if (Tile.IsSlopedRoad(at.parentTile, at.tile, neighbour.tile))
					neighbour.distanceFromStart = costForSlope;
				
				// Check if the road makes a turn.
				if (at.direction != neighbour.direction)
					neighbour.distanceFromStart += costForTurn;
				
				// Check if there is already a road here.
				if (AIRoad.IsRoadTile(neighbour.tile))
					neighbour.distanceFromStart += costForRoad;
				else
					neighbour.distanceFromStart += costForNewRoad;
			}
			
			neighbour.distanceFromStart += at.distanceFromStart;
			neighbour.parentTile = at;
			neighbour.length = at.length + 1;
			
			// Add this neighbour node to the queue.
			pq.Insert(neighbour, neighbour.distanceFromStart + AIMap.DistanceManhattan(neighbour.tile, expectedEnd) * costTillEnd);
		}
		
		// Done! Don't forget to put at into the closed list
		closedList[at.tile] <- at.tile;
	}

	// Oh oh... No result found :(
	Log.logWarning("No path found!");
	return null;
}

/**
 * Util class to hold a tile and the heuristic value for
 * pathfinding.
 */
class AnnotatedTile 
{
	tile = 0;				// Instance of AITile
	parentTile = null;		// Needed for backtracking!
	distanceFromStart = 0;	// 'Distance' already travelled from start tile
	direction = 0;			// The direction the road travels to this point.
	type = null;			// What type of infrastructure is this?
	length = 0;				// The length of the path.
	bridgeOrTunnelAlreadyBuild = false;	// Is the bridge or tunnel already build?
}
