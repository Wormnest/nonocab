/**
 * For the connections advisor we need an handler for the ManageVehiclesAction
 * because we need to add the vehicles to the ConnectionNode after they
 * have been build.
 */
class ConnectionManageVehiclesActionHandler {
	
	connectionNode = null;				// The industry connection node the vehicles will operate on.

	/**
	 * @param connectionNode The industry connection node where the build 
	 * vehicles will operate on.
	 */
	constructor(connectionNode) {
		this.connectionNode = connectionNode;
	}
	
	/**
	 * Call back handler; We iterate over all build vehicles and group them in
	 * in VehicleGroup objects.
	 */
	function HandleAction(manageVehiclesAction) {
		foreach (vehicleNumber in manageVehiclesAction.buildVehicles) {
			
			local vehicleGroup = null;
			
			// Search if there are already have a vehicle group with this engine ID.
			foreach (vGroup in connectionNode.vehiclesOperating) {
				if (vGroup.engineID == AIVehicle.GetEngineType(vehicleNumber)) {
					vehicleGroup = vGroup;
					break;
				}
			}
			
			// If there isn't a vehicles group we create one.
			if (vehicleGroup == null) {
				vehicleGroup = VehicleGroup();
				vehicleGroup.connection = connectionNode;
			}
			
			vehicleGroup.vehicleIDs.push(vehicleNumber);
			connectionNode.vehiclesOperating.push(vehicleGroup);
		}		
	}
}