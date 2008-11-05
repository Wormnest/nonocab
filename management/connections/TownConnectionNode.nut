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
	
	function GetProducingTiles(cargoID) {
		return GetTownTiles(false, cargoID);
	}
	
	function GetAcceptingTiles(cargoID) {
		return GetTownTiles(true, cargoID);
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

	function IsAccepted(cargoID) {
		local stationRadius = (!AICargo.HasCargoClass(cargoID, AICargo.CC_PASSENGERS) ? AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP) : AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP)); 
		return AITile.GetCargoAcceptance(AITown.GetLocation(id), cargoID, 1, 1, stationRadius) > 7;
	}
}
/**
 * Scans tiles who are within town influence.
 */
function TownConnectionNode::GetTownTiles(isAcceptingCargo, cargoID) {
	local list = AITileList();
	local tile = GetLocation();

	local x = AIMap.GetTileX(tile);
	local y = AIMap.GetTileY(tile);
	local min_x = x - 20;
	local min_y = y - 20;
	local max_x = x + 20;
	local max_y = y + 20;
	if (min_x < 0) min_x = 1; else if (max_x >= AIMap.GetMapSizeX()) max_x = AIMap.GetMapSizeX() - 2;
	if (min_y < 0) min_y = 1; else if (max_y >= AIMap.GetMapSizeY()) max_y = AIMap.GetMapSizeY() - 2;
	list.AddRectangle(AIMap.GetTileIndex(min_x, min_y), AIMap.GetTileIndex(max_x, max_y));

	// Purge all unnecessary entries from the list.
	list.Valuate(AITile.IsWithinTownInfluence, id);
	list.KeepAboveValue(0);
	list.Valuate(AITile.IsBuildable);
	list.KeepAboveValue(0);

	local isTownToTown = AITown.GetMaxProduction(id, cargoID) > 0;
	if (isTownToTown)
		isAcceptingCargo = true;

	local stationRadius = (!AICargo.HasCargoClass(cargoID, AICargo.CC_PASSENGERS) ? AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP) : AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP)); 
	local minimalAcceptance = (isTownToTown ? 15 : 7);
	local minimalProduction = (isTownToTown ? 15 : 0);

	// Make sure the tiles we want to build are producing or accepting our cargo in enough
	// quantity.
	if (isAcceptingCargo) {
		list.Valuate(AITile.GetCargoAcceptance, cargoID, 1, 1, stationRadius);
		list.KeepAboveValue(minimalAcceptance);
	} else {
		list.Valuate(AITile.GetCargoProduction, cargoID, 1, 1, stationRadius);
		list.KeepAboveValue(minimalProduction);
	}

	// If we're building town to town we want the best tile in that town available
	// but also make sure we don't build to close to other road stations.
	if (isTownToTown) {
		if (excludeList.rawin("" + cargoID))
			list.RemoveList(excludeList["" + cargoID]);
		list.Valuate(AITile.GetCargoAcceptance, cargoID, 1, 1, stationRadius);
		list.Sort(AIAbstractList.SORT_BY_VALUE, false);
		list.KeepTop(1);
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
