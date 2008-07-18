import("queue.binary_heap", "BinaryHeap", 1);

////////////////////////// PATHFINDING ///////////////////////////////////////////////////
/**
 * This class will take care of all pathfinding features.
 */
class RoadPathFinding 
{
	/**
	 * We need functions to calibrate penalties and stuff. We want functions
	 * to build the *fastest*, *cheapest*, *optimal throughput*, etc. We aren't
	 * allowed to write C++ so we need to script this information :).
	 */
	function CreateRoad(roadList);		// Create the best road from start to end
	function GetCostForRoad(roadList);	// Give the cost for the best road from start to end
	function FindFastestRoad(start, end);
}

/**
 * Store important info about a path we found! :)
 */
class PathInfo
{
	roadList = null;		// List of all road tiles the road needs to follow
	travelDistance = null;		// The total number of squares of road (multipy by 429 to get km)
	speedModifier = null;		// The 'cost' of the road (taking into account all the slopes, etc) 
					// <-- The average velocity can be calculated by multiplying this value with 
					// the speed of the vehicle...
	roadCost = null;		// The cost to create this road

	constructor(roadList, travelDistance, speedModifier, roadCost) {
		this.roadList = roadList;
		this.travelDistance = travelDistance;
		this.speedModifier = speedModifier;
		this.roadCost = roadCost;
	}
}

/**
 * Create the fastest road from start to end, without altering
 * the landscape. We use the A* pathfinding algorithm.
 */
function RoadPathFinding::CreateRoad(roadList)
{
	local b = AIExecMode();
	if(roadList == null || roadList.len() < 2)
		return false;
		
	local buildFrom = roadList[roadList.len() - 1].tile;
	local currentDirection = roadList[roadList.len() - 1].direction;
	
	for(local a = roadList.len() - 2; -1 < a; a--)		
	{
		//AISign.BuildSign(roadList[a].tile, "B");
		local buildTo = roadList[a].tile;
		local direction = roadList[a].direction;
		
		switch (roadList[a].type) {
			case Tile.ROAD:
				if (direction != currentDirection) {
		
					// Check if we need to do some terraforming
					// Not needed ATM, as we make sure we only consider roads which
					// don't require terraforming
					// Terraform(buildFrom, currentDirection);
					
					if (!AIRoad.BuildRoad(buildFrom, roadList[a + 1].tile)) {
						local s = "Failed to build a road from " + AIMap.GetTileX(buildFrom) + ", " + AIMap.GetTileY(buildFrom) + " to " + AIMap.GetTileX(roadList[a + 1].tile) + ", " + AIMap.GetTileY(roadList[a + 1].tile);
						print(s);
						print(AIError.GetLastErrorString());
					}
					currentDirection = direction;
					buildFrom = roadList[a + 1].tile;
				}
				break;
			case Tile.TUNNEL:
				AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, roadList[a + 1].tile + roadList[a].direction);

				// Build road before the tunnel
				AIRoad.BuildRoad(buildFrom, roadList[a + 1].tile);

				if (a > 0)
					buildFrom = roadList[a - 1].tile;
				else
					buildFrom = roadList[0].tile;
				break;
			case Tile.BRIDGE:
				local length = roadList[a].tile - roadList[a + 1].tile / roadList[a].direction;
				if (length < 0)
					length = -length;
				
				AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, AIBridgeList_Length(length).Begin(), roadList[a + 1].tile + roadList[a].direction, roadList[a].tile);
								
				// Build road before the tunnel
				AIRoad.BuildRoad(buildFrom, roadList[a + 1].tile);

				if (a > 0)
					buildFrom = roadList[a - 1].tile;
				else
					buildFrom = roadList[0].tile;
				break;
		}
	}
	
	// Build the last part
	AIRoad.BuildRoad(roadList[0].tile, buildFrom);
	return true;		
}

/**
 * Plan and check how much it cost to create the fastest route
 * from start to end.
 */
function RoadPathFinding::GetCostForRoad(roadList)
{
	local test = AITestMode();		// Switch to test mode...

	local accounting = AIAccounting();	// Start counting costs

	this.CreateRoad(roadList);		// Fake the construction

	return accounting.GetCosts();		// Automatic memory management will kill accounting and testmode! :)
}

/**
 * A* pathfinder to find the fastest path from start to end.
 * @param start An AIAbstractList which contains all the nodes the path can start from.
 * @param end An AIAbstractList which contains all the nodes the path can stop at. The
 * middle point of these values will be used to guide the pathfinder to its goal.
 * @return A PathInfo instance which contains the found path (if any).
 */
function RoadPathFinding::FindFastestRoad(start, end)
{
	// Now, for the interesting part... :)
	// Road can only be build from North to South and from West to East, we
	// use the Manhattan distance as heuristic (faster and as good as squared
	// distance) for our algorithm. Every tile is stored in a priority queue.

	local pq = null;
	local expectedEnd = null;

	// Calculate the central point of the end array
	local x = 0;
	local y = 0;

	for(local i = end.Begin(); end.HasNext(); i = end.Next()) {
		x += AIMap.GetTileX(i);
		y += AIMap.GetTileY(i);
	}

	expectedEnd = AIMap.GetTileIndex(x / end.Count(), y / end.Count());
	
	// We must also keep track of all tiles we've already processed, we use
	// a table for that purpose.
	local closedList = {};
	local closedListBridgesTunnels = {};

	// We keep a separate list for start tiles
	local startList = {};
	
	// Start by constructing a priority queue and by adding all start
	// nodes to it.
	pq = BinaryHeap()
	//pq = FibonacciHeap();
	for(local i = start.Begin(); start.HasNext(); i = start.Next()) {

		// Check if we can actually start here!
		if(!Tile.IsBuildable(i))
			continue;
 
		local annotatedTile = AnnotatedTile(i, null, 0, 0, Tile.ROAD);
		annotatedTile.parentTile = annotatedTile;		// Small hack ;)
		pq.Insert(annotatedTile, AIMap.DistanceManhattan(i, expectedEnd) * 30);
		startList[i] <- i;
	}


	// Now with the open and closed list we're ready to do some grinding!!!
	while (pq.Count != 0)
	{
		// Get the node with the best utility value
		local at = pq.Pop();	

		//{
		//	local a = AIExecMode();
		//	AISign.BuildSign(at.tile, "A");
		//}
		
		if(closedList.rawin(at.tile))
			continue;

		// Check if this is the end already!!
		// TODO: Rewrite!
		if(end.HasItem(at.tile) && Tile.IsBuildable(at.tile)) {

			// determine size...
			local tmp = at;
			local tmp_size = 1;
			while(tmp.parentTile != tmp) {
				tmp = tmp.parentTile;
				tmp_size++;
			}

			// Create the result list
			local resultList = array(tmp_size);
			resultList[0] = at;

			// We want to return a PathInfo object, we need it for later
			// assesments! :)
			local avg_speed = 0;
			local lastDirection = at.direction;

			tmp_size = 1;
			// Construct result list! :)
			while(at.parentTile != at) {
				at = at.parentTile;
				resultList[tmp_size] = at;
				tmp_size++;
			}
			return PathInfo(resultList, null, null, null);
		}
		
		// Get all possible tiles from this annotated tile (North, South, West,
		// East) and check if we're already at the end or if new roads are possible
		// from those tiles.
		local directions = Tile.GetNeighbours(at);
		
		/**
		 * neighbour is an array with 4 elements:
		 * [0] = TileIndex
		 * [1] = Direction from parent (TileIndex - Parent.TileIndex)
		 * [2] = Type (i.e. TUNNEL, BRIDGE, or ROAD)
		 * [3] = Utility costs
		 */
		local neighbour = 0;
		foreach (neighbour in directions) {
		
			// Skip if this node is already processed or if we can't build on it
			if (closedList.rawin(neighbour[0]) || (neighbour[2] == Tile.ROAD && !AIRoad.AreRoadTilesConnected(neighbour[0], at.tile) && !AIRoad.BuildRoadFull(neighbour[0], at.tile))) {
				continue;
			}
			
			// Are we dealing with a tunnel or bridge?
			// i.e. is the distance to the next node greater then 1 tile
			if (at.tile + neighbour[1] != neighbour[0]) {
				
				local length = (neighbour[0] - at.tile) / neighbour[1];
				if (length < 0) length = -length;
				
				if (neighbour[2] == Tile.TUNNEL) {
					neighbour[3] = 120 * length;
				} else {
					neighbour[3] = 150 * length;
				}
			}
			
			// This is a normal road
			else {
				
				// Check if the road is sloped.
				if (Tile.IsSlopedRoad(at.parentTile, at.tile, neighbour[0])) {
					neighbour[3] = 80;
				}
				
				// Check if the road makes a turn.
				if (at.direction != neighbour[1]) {
					neighbour[3] += 75;
				}
				
				// Check if there is already a road here.
				if (AIRoad.IsRoadTile(neighbour[0])) {
					neighbour[3] += 30;
				} else {
					neighbour[3] += 50;
				}
			}
			
			neighbour[3] += at.distanceFromStart;

			// Add this neighbour node to the queue.
			pq.Insert(AnnotatedTile(neighbour[0], at, neighbour[3], neighbour[1], neighbour[2]), neighbour[3] + AIMap.DistanceManhattan(neighbour[0], expectedEnd) * 30);
		}
		
		// Done! Don't forget to put at into the closed list
		closedList[at.tile] <- at.tile;
	}

	// Oh oh... No result found :(
	print("No path found!");
	return null;
}

/**
 * Util class to hold a tile and the heuristic value for
 * pathfinding.
 */
class AnnotatedTile 
{
	tile = null;			// Instance of AITile
	parentTile = null;		// Needed for backtracking!
	distanceFromStart = null;	// 'Distance' already travelled from start tile
	direction = null;		// The direction the road travels to this point.
	type = null;			// What type of infrastructure is this?

	// A Tile is about 612km on a side :)

	constructor(tile, parentTile, distanceFromStart, direction, type)
	{
		this.tile = tile;
		this.parentTile = parentTile;
		this.distanceFromStart = distanceFromStart;
		this.direction = direction;
		this.type = type;
	}
}
