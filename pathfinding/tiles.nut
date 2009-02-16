/**
 * This class provides static functions which provide information and perform
 * searches for tiles in the world map.
 */
class Tile {

	// Types of tile.
	static NONE   = 0;
	static BRIDGE = 1;
	static TUNNEL = 2;
	static ROAD   = 3;

	// The length of various road pieces
	static straightRoadLength 	= 28.5;					// Road length / 24 (easier to calculate km/h)
	static diagonalRoadLength	= 40.3;
	static bendedRoadLength 	= 20;
	static upDownHillRoadLength 	= 28.5;
	
	/**
	 * Get all the tile IDs from the tiles directly adjacent to the given tile ID.
	 * @param currentTile Tile ID.
	 * @param diagonal Return diagonal tiles as well?
	 * @return An array with the tile IDs of all tiles around it.
	 * @remark This function does not boundary checking and cannot be used safely on 
	 * border tiles.
	 */
	static function GetTilesAround(currentTile, diagonal);
	
	/**
	 * Determine whether the road will be sloped.
	 * @param startNode The node to build from.
	 * @param direction The direction to build to.
	 * @return True if the road will be sloped when building
	 * from the startNode in the given direction, false otherwise.
	 */
	static function IsSlopedRoad(startNode, direction);
	
	/**
	 * Get the slope of the tile if moving in the specified direction.
	 * @param tile The tile to determine the slope of.
	 * @direction The direction you want to 'walk' from this tile.
	 * @return Possible return values are:
	 * 0: No slope.
	 * 1: Slope upwards.
	 * 2: Slope downwards.
	 */
	static function GetSlope(tile, direction);
	
	/**
	 * Determine if the tile is buildable.
	 * @param node The tile ID to check.
	 * @return True if the tile is buildable, false otherwise.
	 */
	static function IsBuildable(tile);
	
	/**
	 * Get a list of a rectangle of tiles from the world.
	 * @param centre The centre of the rectangle.
	 * @param radiusX The size of the rectangle in the X direction.
	 * @param radiusY The size of the rectangle in the Y direction.
	 * @return An AITileList instance with the tiles which are in the
	 * rectangle.
	 */
	static function GetRectangle(centre, sizeX, sizeY);
}

function Tile::GetTilesAround(currentTile, diagonal) {
	if (diagonal)
		return [currentTile -1, currentTile +1, currentTile - AIMap.GetMapSizeX(), currentTile + AIMap.GetMapSizeX(),
			currentTile - AIMap.GetMapSizeX() + 1, currentTile - AIMap.GetMapSizeX() - 1, currentTile - AIMap.GetMapSizeY() + 1, currentTile - AIMap.GetMapSizeY() - 1];
	return [currentTile -1, currentTile +1, currentTile - AIMap.GetMapSizeX(), currentTile + AIMap.GetMapSizeX()];
}

function Tile::IsSlopedRoad(start, middle, end)
{
	local NW = 0; //Set to true if we want to build a road to / from the north-west
	local NE = 0; //Set to true if we want to build a road to / from the north-east
	local SW = 0; //Set to true if we want to build a road to / from the south-west
	local SE = 0; //Set to true if we want to build a road to / from the south-east

	if (middle - AIMap.GetMapSizeX() == start || middle - AIMap.GetMapSizeX() == end) NW = 1;
	if (middle - 1 == start || middle - 1 == end) NE = 1;
	if (middle + AIMap.GetMapSizeX() == start || middle + AIMap.GetMapSizeX() == end) SE = 1;
	if (middle + 1 == start || middle + 1 == end) SW = 1;

	/* If there is a turn in the current tile, it can't be sloped. */
	if ((NW || SE) && (NE || SW)) return false;

	local slope = AITile.GetSlope(middle);
	/* A road on a steep slope is always sloped. */
	if (AITile.IsSteepSlope(slope)) return true;

	/* If only one corner is raised, the road is sloped. */
	if (slope == AITile.SLOPE_N || slope == AITile.SLOPE_W) return true;
	if (slope == AITile.SLOPE_S || slope == AITile.SLOPE_E) return true;

	if (NW && (slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SE)) return true;
	if (NE && (slope == AITile.SLOPE_NE || slope == AITile.SLOPE_SW)) return true;

	return false;
}

function Tile::GetSlope(tile, direction)
{
	// 0: No slope.
	// 1: Slope upwards.
	// 2: Slope downwards.
	
	local slope = AITile.GetSlope(tile);

	if (direction == 1) { 		// West
		if ((slope & AITile.SLOPE_NE) == 0 && (slope & AITile.SLOPE_SW) != 0) // Eastern slope must be flat and one point of the western slope must be high
			return 1;
		else if ((slope & AITile.SLOPE_SW) == 0 && (slope & AITile.SLOPE_NE) != 0) // Western slope must be flat and one point of the eastern slope must be high
			return 2;
	} else if (direction == -1) {	// East
		if ((slope & AITile.SLOPE_SW) == 0 && (slope & AITile.SLOPE_NE) != 0) // Western slope must be flat and one point of the eastern slope must be high
			return 1;
		else if ((slope & AITile.SLOPE_NE) == 0 && (slope & AITile.SLOPE_SW) != 0) // Eastern slope must be flat and one point of the western slope must be high
			return 2;
	} else if (direction == -AIMap.GetMapSizeX()) {	// North
		if ((slope & AITile.SLOPE_SE) == 0 && (slope & AITile.SLOPE_NW) != 0) // Southern slope must be flat and one point of the northern slope must be high
			return 1;
		else if ((slope & AITile.SLOPE_NW) == 0 && (slope & AITile.SLOPE_SE) != 0) // Northern slope must be flat and one point of the southern slope must be high
			return 2;
	} else if (direction == AIMap.GetMapSizeX()) {	// South
		if ((slope & AITile.SLOPE_NW) == 0 && (slope & AITile.SLOPE_SE) != 0) // Northern slope must be flat and one point of the southern slope must be high
			return 1;
		else if ((slope & AITile.SLOPE_SE) == 0 && (slope & AITile.SLOPE_NW) != 0) // Southern slope must be flat and one point of the northern slope must be high
			return 2;
	}

	return 0;
}

function Tile::IsBuildable(tile) {

	// Check if we can actually build here!
	local test = AITestMode();

	// Check if we can build a road station on this tile (then we know for sure it's
	// save to build here :)
	foreach(directionTile in Tile.GetTilesAround(tile, false)) {
		if(AIRoad.BuildRoadStation(tile, directionTile, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_JOIN_ADJACENT)) {
			return true;
		}
	}
	return false;
}

function Tile::GetRectangle(centre, sizeX, sizeY) {
		local list = AITileList();
		local x = AIMap.GetTileX(centre);
		local y = AIMap.GetTileY(centre);
		local min_x = x - sizeX;
		local min_y = y - sizeY;
		local max_x = x + sizeX;
		local max_y = y + sizeY;
		if (min_x < 0) min_x = 1; else if (max_x >= AIMap.GetMapSizeX()) max_x = AIMap.GetMapSizeX() - 2;
		if (min_y < 0) min_y = 1; else if (max_y >= AIMap.GetMapSizeY()) max_y = AIMap.GetMapSizeY() - 2;
		list.AddRectangle(AIMap.GetTileIndex(min_x, min_y), AIMap.GetTileIndex(max_x, max_y));
		return list;
}
