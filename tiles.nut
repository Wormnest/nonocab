
class Tile {

	static NORTH = 0;
	static EAST  = 1;
	static SOUTH = 2;
	static WEST  = 3;
	static NORTH_EAST = 4;
	static SOUTH_EAST = 5;
	static NORTH_WEST = 6;
	static SOUTH_WEST = 7;
	

	constructor() {

	}

	static function GetTilesAround(tile, getDiagonal, testFunction);
	static function IsBuildable(tile);
}
/**
 * Get all tiles around a given tile (we don't check boundaries),
 * we get the Northern, Western, Southern, and Eastern tiles. If
 * getDiagonal is true, we also get those. 
 *
 * TODO: A test function can
 * be provided to test if a certain tile should be included in
 * the set.
 */
function Tile::GetTilesAround(tile, getDiagonal, testFunction) {

	local tileArray = array( (getDiagonal ? 8 : 4));

	tileArray[Tile.NORTH] = tile + AIMap.GetMapSizeX(); 	// North
	tileArray[Tile.EAST] = tile + 1;			// East
	tileArray[Tile.SOUTH] = tile - AIMap.GetMapSizeX();	// South
	tileArray[Tile.WEST] = tile - 1;			// West

	// Check diagonals
	if(getDiagonal) {
		tileArray[Tile.NORTH_EAST] = tile + AIMap.GetMapSizeX() + 1;	 // North-East
		tileArray[Tile.SOUTH_EAST] = tile - AIMap.GetMapSizeX() + 1;  // South-East
		tileArray[Tile.NORTH_WEST] = tile + AIMap.GetMapSizeX() - 1;  // North-West
		tileArray[Tile.SOUTH_WEST] = tile - AIMap.GetMapSizeX() - 1;  // South-West
	}

	return tileArray;
}

/**
 * Check if we can actually build something on this tile :).
 */
function Tile::IsBuildable(tile) {


	// Check if we can actually build here!
	if(AITile.IsBuildable(tile)) {
		local test = AITestMode();
		local isBuildable = false;

		// Check if we can build a road station on this tile (then we know for sure it's
		// save to build here :)
		foreach(directionTile in Tile.GetTilesAround(tile, false, null)) {
			if(AIRoad.BuildRoadStation(tile, directionTile, true, false)) {
				return true;
			}
		}
	}

	return false;
}
