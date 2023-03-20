/**
 * Industry node which contains all information about an industry and its connections
 * to other industries.
 */
class TownConnectionNode extends ConnectionNode
{

	excludeList = null;			// List of all nodes where no station may be build!
	cacheDate     = 0;			// Date the cache was set
	cachedXSpread = 0;			// XSpread cached value
	cachedYSpread = 0;			// YSpread cached value

	constructor(id) {
		ConnectionNode.constructor(TOWN_NODE, id);
		excludeList = {};
		cacheDate     = 0;
		cachedXSpread = 0;
		cachedYSpread = 0;
		}

	/**
	 * Get the location of this node.
	 * @return The tile location of this node.
	 */
	function GetLocation() {
		return AITown.GetLocation(id);
	}
	
	function GetProducingTiles(cargoID, stationRadius, stationSizeX, stationSizeY) {
		return GetTownTiles(false, cargoID, true, stationRadius, stationSizeX, stationSizeY);
	}
	
	function GetAcceptingTiles(cargoID, stationRadius, stationSizeX, stationSizeY) {
		return GetTownTiles(true, cargoID, true, stationRadius, stationSizeX, stationSizeY);
	}

	function GetAllProducingTiles(cargoID, stationRadius, stationSizeX, stationSizeY) {
		return GetTownTiles(false, cargoID, false, stationRadius, stationSizeX, stationSizeY);
	}
	
	function GetAllAcceptingTiles(cargoID, stationRadius, stationSizeX, stationSizeY) {
		return GetTownTiles(true, cargoID, false, stationRadius, stationSizeX, stationSizeY);
	}
	
	function GetName() {
		return AITown.GetName(id);
	}
	
	function GetProduction(cargoID) {
		local productionLastMonth = AITown.GetLastMonthProduction(id, cargoID);
		return productionLastMonth;
	}
}
/**
 * Scans tiles who are within town influence.
 */
function TownConnectionNode::GetTownTiles(isAcceptingCargo, cargoID, keepBestOnly, stationRadius, stationSizeX, stationSizeY) {

	local tile = GetLocation();

	// Check how large the town is.
	local maxXSpread = 1;
	local maxYSpread = 1;
	local xBuildable = false;
	local yBuildable = false;

	if (AIDate.GetCurrentDate() - cacheDate > 365) {
		// We had a crash due to excessive CPU usage below in list.Valuate(AITile.IsBuildable);
		// maxYSpread was 175, and maxXSpread 286.
		// We were not checking if a tile still belonged to the town causing us to
		// go way beyond where our town was. So, we now add a check to make sure
		// we stay close to the town, and as extra security set a limit on the spread.
		local spreadLimit = 150;

		while ((!xBuildable || !yBuildable) && maxXSpread < spreadLimit) {

			// We need to check that tile stays within the borders of the map thus check if
			// tile is valid before checking IsBuildableRectangle
			if ((!Tile.IsValidTileMaxXOffset(tile, maxXSpread)) || AITile.IsWaterTile(tile + maxXSpread) ||
				(!AITown.IsWithinTownInfluence(id, tile + maxXSpread)) ||
				AITile.IsBuildableRectangle(tile + maxXSpread, stationSizeX, stationSizeY))
				xBuildable = true;

			if ((!Tile.IsValidTileMinXOffset(tile, maxXSpread - stationSizeX)) || AITile.IsWaterTile(tile - maxXSpread) ||
				(!AITown.IsWithinTownInfluence(id, tile - maxXSpread)) ||
				AITile.IsBuildableRectangle(tile - maxXSpread - stationSizeX, stationSizeX, stationSizeY)) {
				yBuildable = true;
			}

			maxXSpread++;
		}
		maxXSpread += stationSizeX * 2;

		// Do the same for the y value.
		xBuildable = false;
		yBuildable = false;

		while ((!xBuildable || !yBuildable) && maxYSpread < spreadLimit) {

			// We need to check that tile stays within the borders of the map thus check if
			// tile is valid before checking IsBuildableRectangle
			local isValidMaxY = Tile.IsValidTileMaxYOffset(tile, maxYSpread);
			local targetTile = tile + maxYSpread * AIMap.GetMapSizeX();
			if ((!isValidMaxY) || AITile.IsWaterTile(targetTile) ||
				(!AITown.IsWithinTownInfluence(id, targetTile)) ||
				AITile.IsBuildableRectangle(targetTile, stationSizeX, stationSizeY))
				xBuildable = true;

			local isValidMinY = Tile.IsValidTileMinYOffset(tile, maxYSpread+stationSizeY);
			targetTile = tile - maxYSpread * AIMap.GetMapSizeX() - stationSizeY * AIMap.GetMapSizeX();
			if ((!isValidMinY) || AITile.IsWaterTile(targetTile) ||
				(!AITown.IsWithinTownInfluence(id, targetTile)) ||
				AITile.IsBuildableRectangle(targetTile, stationSizeX, stationSizeY))
				yBuildable = true;

			maxYSpread++;
		}

		maxYSpread += stationSizeY;
		Log.logDebug("GetTownTiles: Max spread X: " + maxXSpread + ", Y: " + maxYSpread);
		cachedXSpread = maxXSpread;
		cachedYSpread = maxYSpread;
		cacheDate     = AIDate.GetCurrentDate();
	}
	else {
		maxXSpread = cachedXSpread;
		maxYSpread = cachedYSpread;
		Log.logDebug("GetTownTiles: using cached spread X: " + maxXSpread + ", Y: " + maxYSpread);
	}

	local list = Tile.GetRectangle(tile, maxXSpread, maxYSpread);

	// Purge all unnecessary entries from the list.
	list.Valuate(AITile.IsBuildable);
	list.KeepAboveValue(0);

	local isTownToTown = AITown.GetLastMonthProduction(id, cargoID) > 0;
	if (isTownToTown)
		isAcceptingCargo = true;

	local minimalAcceptance = (isTownToTown ? (stationRadius * stationRadius / 2) * 6 : 12);
	local minimalProduction = (isTownToTown ? stationRadius * stationRadius / 1 : 8);

	if (minimalAcceptance < 8)
		minimalAcceptance = 8;
	else if (minimalAcceptance > 64)
		minimalAcceptance = 64;

	if (isTownToTown && minimalAcceptance < 32)
		minimalAcceptance = 32;
	

	// Make sure the tiles we want to build are producing or accepting our cargo in enough
	// quantity.
	if (isAcceptingCargo) {
		list.Valuate(AITile.GetCargoAcceptance, cargoID, stationSizeX, stationSizeY, stationRadius);
		list.KeepAboveValue(minimalAcceptance);
	} else {
		list.Valuate(AITile.GetCargoProduction, cargoID, stationSizeX, stationSizeY, stationRadius);
		list.KeepAboveValue(minimalProduction);
	}
	// If we're building town to town we want the best tile in that town available
	// but also make sure we don't build to close to other road stations.
	if (isTownToTown) {
		if (excludeList.rawin("" + cargoID))
			list.RemoveList(excludeList.rawget("" + cargoID));

		if (keepBestOnly) {
			list.Valuate(AITile.GetCargoAcceptance, cargoID, stationSizeX, stationSizeY, stationRadius);
			list.Sort(AIList.SORT_BY_VALUE, false);
			list.KeepTop(1);
		}
	}

	return list;
}

function TownConnectionNode::GetPopulation()
{
	return AITown.GetPopulation(id);
}

function TownConnectionNode::ToString()
{
	return GetName() + " (" + GetPopulation() + ")";
}

/**
 * We want to make sure that connections in the same town aren't placed to close
 * together. That's why tiles in a town are marked as taken by this algorithm. Any
 * connection must build their stations outside these tiles.
 * This algorithm calculates and marks these tiles in this town.
 * @param cargoID The cargo transported.
 * @param centreTile The centre of the new station.
 * @radius The radius of influence.
 */
function TownConnectionNode::AddExcludeTiles(cargoID, centreTile, radius) {

	local list;
	radius = radius * 2;
	if (!excludeList.rawin("" + cargoID)) {
		list = AITileList();
		excludeList["" + cargoID] <- list;
	} else
		list = excludeList.rawget("" + cargoID);

	local mapSizeX = AIMap.GetMapSizeX();
	list.AddRectangle(centreTile - radius - radius * mapSizeX, centreTile + radius + radius * mapSizeX);
}
