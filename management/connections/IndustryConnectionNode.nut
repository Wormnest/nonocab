/**
 * Industry node which contains all information about an industry and its connections
 * to other industries.
 */
class IndustryConnectionNode extends ConnectionNode
{

	constructor(id) {
		ConnectionNode.constructor(INDUSTRY_NODE, id);
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
		return AITileList_IndustryAccepting(id, stationRadius);
	}
	
	function GetName() {
		return AIIndustry.GetName(id);
	}
	
	function GetProduction(cargoID) {
		return AIIndustry.GetLastMonthProduction(id, cargoID);
	}
}
