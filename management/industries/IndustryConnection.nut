/**
 * Information for an individual vehicle which runs a certain connection. All
 * inforamtion is dependend on the actual speed of each individual vehicle.
 */
class IndustryConnection
{
	cargoID = null;				// The type of cargo carried from on industry to another.
	travelFromIndustryNode = null;		// The industry the cargo is carried from.
	travelToIndustryNode = null;		// The industry the cargo is carried to.
	vehiclesOperating = null;		// List of VehicleGroup instances to keep track of all vehicles on this connection.
	pathInfo = null;			// PathInfo class which contains all information about the path.
	
	constructor(fromIndustry, toIndustry) {
		travelFromIndustryNode = fromIndustry;
		travelToIndustryNode = toIndustry;
		vehiclesOperating = [];
	}
}