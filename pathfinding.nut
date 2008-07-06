
////////////////////////// PATHFINDING ///////////////////////////////////////////////////
/**
 * This class will take care of all pathfinding features.
 */
class RoadPathFinding 
{
	road = null;	// We'll use AIRoad to manage building / managing roads
	map = null;	// The map we're currently playing
	
	constructor(map, road) {
		this.map = map;
		this.road = road;
	}

	/**
	 * We need functions to calibrate penalties and stuff. We want functions
	 * to build the *fastest*, *cheapest*, *optimal throughput*, etc. We aren't
	 * allowed to write C++ so we need to script this information :).
	 */
	function CreateRoad(roadList);		// Create the best road from start to end
	function GetCostForRoad(roadList);	// Give the cost for the best road from start to end
	function FindFastestRoad(start, end, allowenceSavings, excludeList, ai);
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
 *
 * The allowenceSavings is used to specify how much longer a road 
 * may be if it saves on the costs of building roads. The value 
 * must be between [0..1], 0 meaning NO detour may be made to 
 * lower the costs, 1 means that any means must be exploited to 
 * lower the cost as much as possible (existing roads are 
 * considered to be free).
 */
function RoadPathFinding::CreateRoad(roadList, ai)
{
	if(roadList == null || roadList.len() < 2)
		return false;

	// Build the entire tile list! :)
	local i = roadList[0];
	local j = roadList[1];

	// Check the initial direction
	local currentDirection = j - i;

	// We want to build entire segments at once. So if our road goes North
	// 5 times we want to build it with one command, instead of calling
	// BuildRoad 5 times (saves time! :)). So we keep track of the direction.
	local direction = null;
	local lastChecked = null;

	/**
	 * We use an iterating process. We monitor if each sequential tile
	 * heads in the same direction as the previous tile, if not we 
	 * construct the road found so far and continue the process in 
	 * the new direction.
	 */

	// Skip list till we find a tile with an other direction
	for(local a = 2; a < roadList.len(); a++)		
	{
		lastChecked = j;
		j = roadList[a];

		// If the road changes direction, create that part of the road
		// and change the direction we're heading
		if(j != lastChecked + currentDirection)
		{
			local result = road.BuildRoad(i, lastChecked);


			// You may want to do some fixing if the road couldn't be build.

			// Update new direction information for the next
			// iteration
			currentDirection = j - lastChecked;
			i = lastChecked;
		}
	}

	
	// Build the last part (if any)!
	if(i && j)
		road.BuildRoad(i, j);
	
	return true;			
}

/**
 * Plan and check how much it cost to create the fastest route
 * from start to end.
 */
function RoadPathFinding::GetCostForRoad(roadList, ai)
{
	local test = AITestMode();		// Switch to test mode...

	local accounting = AIAccounting();	// Start counting costs

	this.CreateRoad(roadList, ai);		// Fake the construction

	return accounting.GetCosts();		// Automatic memory management will kill accounting and testmode! :)
}

/**
 * A* pathfinder to find the fastest path from start to end. The allowenceSavings
 * is used to specify how much longer a road may be if it saves on the costs of
 * building roads. The value must be between [0..1], 1 meaning NO detour may be
 * made to lower the costs, 0 mean that any means must be exploited to lower the
 * cost as much as possible (existing roads are considered to be free).
 * Update X and Y values! :)
 * start and end are always an AIAbstractList.
 * The excludeList contain tiles that mustn't be evaluated during pathfinding.
 */
function RoadPathFinding::FindFastestRoad(start, end, allowenceSavings, excludeList, ai)
{
	// Now, for the interresting part... :)
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
	print("Found: " + expectedEnd);
	
	// We must also keep track of all tiles we've already processed, we use
	// a table for that purpose.
	local closedList = {};

	// We keep a seperate list for start tiles
	local startList = {};

	if(excludeList) 
		foreach(val in excludeList)
			closedList[val] <- val;
	
	// Start by constructing a priority queue and by adding all start
	// nodes to it.
	pq = PriorityQueue(start.Count() * 2);
	for(local i = start.Begin(); start.HasNext(); i = start.Next()) {

		// Check if we can actually start here!
		if(!Tile.IsBuildable(i))
			continue;
 
		AISign.BuildSign(i, "START");
		local annotatedTile = AnnotatedTile(i, null, 0, AIMap.DistanceManhattan(i, expectedEnd), null);
		pq.insert(annotatedTile);
		closedList[i] <- i;
		startList[i] <- i;
		AISign.BuildSign(i, "Start");
	}


	// Now with the open and closed list we're ready to do some grinding!!!
	while(pq.nrElements != 0) 
	{
		local at = pq.remove();

		// Why is this needed!? Don't know but for some reason tiles are put in the priority queue without
		// me wanting it. May want to refactor this code....
		if(closedList.rawin(at.tile) && !startList.rawin(at.tile))
			continue;

		// Check if this is the end already!!
		if(end.HasItem(at.tile)) {

			// Check we can actually end here...
			if(!Tile.IsBuildable(at.tile))
				continue;

			// determine size...
			local tmp = at;
			local tmp_size = 1;
			while(tmp.parentTile != null) {
				tmp = tmp.parentTile;
				tmp_size++;
			}

			// Create the result list
			local resultList = array(tmp_size);
			resultList[0] = at.tile;

			// We want to return a PathInfo object, we need it for later
			// assesments! :)
			local avg_speed = 0;
			local lastDirection = at.direction;

			tmp_size = 1;
			// Construct result list! :)
			while(at.parentTile != null) {
				at = at.parentTile;
				resultList[tmp_size] = at.tile;
				tmp_size++;

				// Check speed,
				// TODO: FIX SLOPES!
				if(lastDirection == at.direction)
					avg_speed += 1;
				else
					avg_speed += 0.5;
			}

			return PathInfo(resultList, tmp_size, avg_speed / tmp_size, null);
		}
		
		// Get all possible tiles from this annotated tile (North, South, West,
		// East) and check if we're already at the end or if new roads are possible
		// from those tiles.
		local directions = Tile.GetTilesAround(at.tile, false, null);

		// Squirrel doesn't support inline functions? :(
		// Check if we can access those directions and add them to the list! :)
		for(local i = 0; i < directions.len(); i++) {

			// Check if we can actually build here and if we haven't checked this
			// tile already. If we've already checked it, we know there is a already
			// faster route to this tile (else it wouldn't have come first).
			if(closedList.rawin(directions[i])) {

				// Don't include tiles we can't build on anyways.
				if(!AITile.IsBuildable(directions[i])) {
					closedList[directions[i]] <- directions[i];
				}
				continue;
			}

			// Try to build it, slopes or other obstacles may prevent this...
			// TODO: Need NoAI extention to catch WHY a road couldn't be
			// build. (ie. because of vehicles, wrong slopes?)
			if(!AIRoad.AreRoadTilesConnected(at.tile, directions[i]))
			{
				local testAI = AITestMode();
				if(!AIRoad.BuildRoadFull(at.tile, directions[i]) ||
					!AIRoad.BuildRoadFull(directions[i], at.tile))
					continue;
			}

			// Calculate the cost for building this road
			/**
			 * We want to build roads as straight as possible, because bends slow
			 * verhicles down 50%. So they are 2 times as 'expensive' for the
			 * heuristic function.
			 * TODO: Take slopes into account
			 */
			local roadCostFromStart = 0;

			// No direction choosen or we're traveling in the same direction
			if(at.direction == i || at.direction == null)
				roadCostFromStart = 1;
			// We're heading in an other direction so make the cost twice as expensive
			else
				roadCostFromStart = 2;
			
			// If it's a road, we might add a discount! :)
			if(!road.IsRoadTile(directions[i]))
				roadCostFromStart *= 1 + (1 - allowenceSavings);
			roadCostFromStart += at.distanceFromStart;

			// Add the tile to the queue! (remove the * 2 later when we've completed regions! :)
			pq.insert(AnnotatedTile(directions[i], at, roadCostFromStart, AIMap.DistanceManhattan(directions[i], expectedEnd), i));
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
	distanceToEnd = null;		// Distance from this tile to the end tile
	distanceFromStart = null;	// Distance already travelled from start tile
	direction = null;		// Which way is this road going to?

	// A Tile is 429km on a side :)

	constructor(tile, parentTile, distanceFromStart, distanceToEnd, direction)
	{
		this.tile = tile;
		this.parentTile = parentTile;
		this.distanceFromStart = distanceFromStart;
		this.distanceToEnd = distanceToEnd;
		this.direction = direction;
	}

	function getHeuristic() {
		return distanceToEnd + distanceFromStart;
	}
}
