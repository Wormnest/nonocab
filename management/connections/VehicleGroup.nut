/**
 * In order to build and maintain connections between nodes we keep track
 * of all vehicles on those connections and their status.
 */
class VehicleGroup
{
	timeToTravelTo = null;			// Time in days it takes all vehicles in this group to 
									// travel from the accepting node to the producing
									// node.
	timeToTravelFrom = null;		// Time in days it takes all vehicles in this group to 
									// travel from the producing node to the accepting
									// node.
	incomePerRun = null;			// The average income per vehicle per run per vehicle.
	engineID = null;				// The engine ID of all vehicles in this group.
	connection = null;				// The connection all vehicles in this group
									// operate on.
	vehicleIDs = null;				// All vehicles IDs of this group.
	
	constructor() {
		vehicleIDs = [];
	}
	
	function LoadData(data) {
		timeToTravelTo = data["timeToTravelTo"];
		timeToTravelFrom = data["timeToTravelFrom"];
		incomePerRun = data["incomePerRun"];
		engineID = data["engineID"];
		vehicleIDs = data["vehicleIDs"];		
	}
	
	function SaveData() {
		local saveData = {};
		saveData["timeToTravelTo"] <- timeToTravelTo;
		saveData["timeToTravelFrom"] <- timeToTravelFrom;
		saveData["incomePerRun"] <- incomePerRun;
		saveData["engineID"] <- engineID;
		saveData["vehicleIDs"] <- vehicleIDs;
		return saveData;
	}
}