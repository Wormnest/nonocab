/**
 * For the connections advisor we need an handler for the ManageVehiclesAction
 * because we need to add the vehicles to the IndustryConnectionNode after they
 * have been build.
 */
class ConnectionManageVehiclesActionHandler {
	
	industryConnectionNode = null;				// The industry connection node the vehicles will operate on.

	/**
	 * @param industryConnectionNode The industry connection node where the build 
	 * vehicles will operate on.
	 */
	constructor(industryConnectionNode) {
		this.industryConnectionNode = industryConnectionNode;
	}
	
	/**
	 * Call back handler; We iterate over all build vehicles and group them in
	 * in VehicleGroup objects.
	 */
	function HandleAction(manageVehiclesAction) {
		foreach (vehicleNumber in manageVehiclesAction.buildVehicles) {
			
			local vehicleGroup = null;
			
			// Search if there are already have a vehicle group with this engine ID.
			foreach (vGroup in industryConnectionNode.vehiclesOperating) {
				if (vGroup.engineID == AIVehicle.GetEngineType(vehicleNumber)) {
					vehicleGroup = vGroup;
					break;
				}
			}
			
			// If there isn't a vehicles group we create one.
			if (vehicleGroup == null) {
				vehicleGroup = VehicleGroup();
				vehicleGroup.industryConnection = industryConnectionNode;
			}
			
			vehicleGroup.vehicleIDs.push(vehicleNumber);
			industryConnectionNode.vehiclesOperating.push(vehicleGroup);
		}		
	}
}