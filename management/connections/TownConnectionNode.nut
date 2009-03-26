/**
 * Industry node which contains all information about an industry and its connections
 * to other industries.
 */
class TownConnectionNode extends ConnectionNode
{

	excludeList = null;			// List of all nodes where no station may be build!

	constructor(id) {
		ConnectionNode.constructor(TOWN_NODE, id);
		excludeList = {};
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
		if (productionLastMonth == 0)
			return AITown.GetMaxProduction(id, cargoID) / 2;
		return productionLastMonth;
	}
}
/**
 * Scans tiles who are within town influence.
 */
function TownConnectionNode::GetTownTiles(isAcceptingCargo, cargoID, keepBestOnly, stationRadius, stationSizeX, stationSizeY) {

	local tile = GetLocation();

	// Check how large the town is.
	local maxXSpread = 0;
	while (AITile.IsWithinTownInfluence(tile + maxXSpread, id) || AITile.IsWithinTownInfluence(tile - maxXSpread, id))
		maxXSpread += 10;

	local maxYSpread = 0;
	while (AITile.IsWithinTownInfluence(tile + maxYSpread * AIMap.GetMapSizeX(), id) || AITile.IsWithinTownInfluence(tile - maxYSpread * AIMap.GetMapSizeX(), id))
		maxYSpread += 10;

	local list = Tile.GetRectangle(tile, maxXSpread, maxYSpread);
	
	// Purge all unnecessary entries from the list.
	list.Valuate(AITile.IsWithinTownInfluence, id);
	list.KeepAboveValue(0);
	list.Valuate(AITile.IsBuildable);
	list.KeepAboveValue(0);

	local isTownToTown = AITown.GetMaxProduction(id, cargoID) > 0;
	if (isTownToTown)
		isAcceptingCargo = true;

	local minimalAcceptance = (isTownToTown ? 15 : 7);
	local minimalProduction = (isTownToTown ? 15 : 0);

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
			list.Sort(AIAbstractList.SORT_BY_VALUE, false);
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
