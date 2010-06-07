class PathFinderHelper {

	emptyList = null;

	/**
	 * Reset all variables before doing pathfinding.
	 */
	function Reset() {
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
	
	/**
	 * Get the time it takes a vehicle to travel among the given road.
	 * @param roadList Array of annotated tiles which compounds the road.
	 * @param maxSpeed The maximum speed of the vehicle.
	 * @param forward Traverse the roadList in the given order if true, otherwise 
	 * traverse it from back to the begin.
	 * @return The number of days it takes a vehicle to traverse the given road
	 * with the given maximum speed.
	 */
	function GetTime(roadList, maxSpeed, forward);	

	/**
	 * Sometimes we want to process tiles which are already in the closed
	 * list. For example, bridges and tunnels can only be build if the road
	 * which leads towards the entrence of these structures follows the same
	 * direction. During the A* algorithm a tile can already be processed and
	 * stored in the closed list, but if we approach the same tile from an
	 * other direction it may be possible that a tunnel or bridge can be
	 * build! There for this test is conducted to check if a tile in the
	 * closed list should be processed.
	 * @param tile The tile under inspection.
	 * @param direction The direction the tile is going.
	 * @return True if the tile should be processed, false otherwise.
	 */
	function ProcessTile(inClosedList, tile, direction) { return inClosedList; }
	
	/**
	 * Some helpers might want to keep track of their own closed list instead of
	 * relying on the default pathfinder. This is for example necessary if you
	 * want to allow the pathfinder to visit tiles multiple times but from
	 * different angles.
	 */
	function UpdateClosedList() { return true; }
}
