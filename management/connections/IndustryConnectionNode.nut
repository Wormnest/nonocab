/**
 * Industry node which contains all information about an industry and its connections
 * to other industries.
 */
class IndustryConnectionNode extends ConnectionNode
{
	_world = null;

	constructor(id, world) {
		ConnectionNode.constructor(INDUSTRY_NODE, id);
		this._world = world;
	}
	
	/**
	 * Get the location of this node.
	 * @return The tile location of this node.
	 */
	function GetLocation() {
		return AIIndustry.GetLocation(id);
	}
	
	function GetProducingTiles(cargoID, stationRadius, stationSizeX, stationSizeY) {
		return AITileList_IndustryProducing(id, stationRadius);
	}
	
	function GetAcceptingTiles(cargoID, stationRadius, stationSizeX, stationSizeY) {
		local acceptingList =  AITileList_IndustryAccepting(id, stationRadius);
		acceptingList.Valuate(AITile.GetCargoAcceptance, cargoID, stationSizeX, stationSizeY, stationRadius);
		acceptingList.KeepAboveValue(7);
		return acceptingList;
	}
	
	function GetName() {
		return AIIndustry.GetName(id);
	}
	
	function GetProduction(cargoID) {
		if (_world.niceCABEnabled) { // Check if competitors have stations here or not
			local nrStationsAround = AIIndustry.GetAmountOfStationsAround(id);

			if (AIIndustry.GetLastMonthTransported(id, cargoID) == 0 || nrStationsAround < 0)
				return AIIndustry.GetLastMonthProduction(id, cargoID);
			else
				return AIIndustry.GetLastMonthProduction(id, cargoID) / (nrStationsAround + 1);
		}
		return AIIndustry.GetLastMonthProduction(id, cargoID);
	}
}
