/**
 * In order to build and maintain connections between industries we keep track
 * of all vehicles on those connections and their status.
 */
class VehicleGroup
{
	timeToTravelTo = null;			// Time in days it takes all vehicles in this group to 
						// travel from the accepting industry to the producing
						// industry.
	timeToTravelFrom = null;		// Time in days it takes all vehicles in this group to 
						// travel from the producing industry to the accepting
						// industry.
	incomePerRun = null;			// The average income per vehicle per run.
	engineID = null;			// The engine ID of all vehicles in this group.
	industryConnection = null;		// The industry connection all vehicles in this group
						// are operating on.
	vehicleIDs = null;			// All vehicles IDs of this group.
	
	constructor() {
		vehicleIDs = [];
	}
}