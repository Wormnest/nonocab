class GameSettings {

	static maxVehiclesLimit = array(4); 		// List with the maximum vehicles allowed in game (actual setting).
	static maxVehiclesBuildLimit = array(4); 	// List with the maximum vehicles still buildable per vehicle type.
	static vehicleTypes = array(4);
	static vehicleGameSettingNames = ["vehicle.max_trains", "vehicle.max_roadveh", "vehicle.max_ships", "vehicle.max_aircraft"];	// List with the corresponding setting names.

	function InitGameSettings();

	/**
	 * Update the game settings by reading the latest value from the
	 * game.
	 */
	function UpdateGameSettings();

	/**
	 * Utility function which determines if more vehicles of a certain
	 * type can be build. It checkes the game settings and the amount
	 * of vehicles of that type already build.
	 * @param vehicleType The type of vehicle.
	 * @return The amount of vehicles of the given type that can still
	 * be build.
	 */
	function GetMaxBuildableVehicles(vehicleType);

	/**
	 * Determine if a particular vehicle type is buildable at all.
	 * @param vehicleType The type of vehicle.
	 * @return If the vehicle type is constructable (i.e. the setting is
	 * higher then 0!
	 */
	function IsBuildable(vehicleType);
}

function GameSettings::InitGameSettings() {
	GameSettings.vehicleTypes[0] = AIVehicle.VT_RAIL;
	GameSettings.vehicleTypes[1] = AIVehicle.VT_ROAD;
	GameSettings.vehicleTypes[2] = AIVehicle.VT_WATER;
	GameSettings.vehicleTypes[3] = AIVehicle.VT_AIR;
}

function GameSettings::UpdateGameSettings() {

	for (local i = 0; i < GameSettings.maxVehiclesLimit.len(); i++) {

		local gameSettingName = GameSettings.vehicleGameSettingNames[i];
		if (AIGameSettings.IsValid(gameSettingName)) {
			local maxVehicles = AIGameSettings.GetValue(gameSettingName);
			local allVehicles = AIVehicleList();
			allVehicles.Valuate(AIVehicle.GetVehicleType);
			allVehicles.KeepValue(GameSettings.vehicleTypes[i]);

			GameSettings.maxVehiclesLimit[i] = maxVehicles;
			local max = maxVehicles - allVehicles.Count();
			if (max < 0)
				GameSettings.maxVehiclesBuildLimit[i] = 0;
			else
				GameSettings.maxVehiclesBuildLimit[i] = maxVehicles - allVehicles.Count();
		} else {
			Log.logWarning("Setting " + gameSettingName + " couldn't be found, not sure if we can actually build this type of vehicles!");
		}
	}
}

function GameSettings::GetMaxBuildableVehicles(vehicleType) {
	if (vehicleType >= GameSettings.maxVehiclesBuildLimit.len() || AIGameSettings.IsDisabledVehicleType(vehicleType))
		return 0;
	return GameSettings.maxVehiclesBuildLimit[vehicleType];
}

function GameSettings::IsBuildable(vehicleType) {
	if (vehicleType >= GameSettings.maxVehiclesBuildLimit.len() || AIGameSettings.IsDisabledVehicleType(vehicleType))
		return false;
	return GameSettings.maxVehiclesLimit[vehicleType] > 0;
}
