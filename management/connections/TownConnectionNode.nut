/**
 * Industry node which contains all information about an industry and its connections
 * to other industries.
 */
class TownConnectionNode extends ConnectionNode
{

	constructor(id) {
		ConnectionNode.constructor(TOWN_NODE, id);
	}
	
	/**
	 * Get the location of this node.
	 * @return The tile location of this node.
	 */
	function GetLocation() {
		return AITown.GetLocation(id);
	}
	
	function GetProducingTiles() {
		local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		Log.logWarning("TownConnectionNode.GetProducingTiles not implemented yet.");
		return AIList();
	}
	
	function GetAcceptingTiles() {
		local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		Log.logWarning("TownConnectionNode.GetAcceptingTiles not implemented yet.");
		return AIList();
	}
	
	function GetName() {
		return AITown.GetName(id);
	}
}
