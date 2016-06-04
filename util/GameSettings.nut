class GameSettings {

	static maxVehiclesLimit = array(4); 		// List with the maximum vehicles allowed in game (actual setting).
	static maxVehiclesBuildLimit = array(4); 	// List with the maximum vehicles still buildable per vehicle type.
	static vehicleTypes = array(4);
	static vehicleGameSettingNames = ["vehicle.max_trains", "vehicle.max_roadveh", "vehicle.max_ships", "vehicle.max_aircraft"];	// List with the corresponding setting names.
	static subsidy = array(1);
	static subsidy_multipliers = [1.5, 2, 3, 4];
	static plane_speed_modifier = array(1);
	static plane_speed_modifiers = [1, 0.5, 0.33, 0.25];

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

function GameSettings::UpdateMaxVehicles(vehicleType)
{
	local gameSettingName = GameSettings.vehicleGameSettingNames[vehicleType];
	if (AIGameSettings.IsValid(gameSettingName)) {
		local maxVehicles = AIGameSettings.GetValue(gameSettingName);
		local allVehicles = AIVehicleList();
		allVehicles.Valuate(AIVehicle.GetVehicleType);
		allVehicles.KeepValue(GameSettings.vehicleTypes[vehicleType]);

		GameSettings.maxVehiclesLimit[vehicleType] = maxVehicles;
		local max = maxVehicles - allVehicles.Count();
		if (max < 0)
			GameSettings.maxVehiclesBuildLimit[vehicleType] = 0;
		else
			GameSettings.maxVehiclesBuildLimit[vehicleType] = maxVehicles - allVehicles.Count();
	}
}

function GameSettings::UpdateGameSettings() {

	if (AIGameSettings.IsValid("difficulty.subsidy_multiplier"))
	{
		GameSettings.subsidy[0] = AIGameSettings.GetValue("difficulty.subsidy_multiplier");
	}

	for (local i = 0; i < GameSettings.maxVehiclesLimit.len(); i++) {

		GameSettings.UpdateMaxVehicles(i);
		local max = GameSettings.maxVehiclesLimit[i];
		Log.logDebug("VEHICLES (type=" + i + ") max: " + max +
			", current: " + (max-GameSettings.maxVehiclesBuildLimit[i]));
	}

	if (AIGameSettings.IsValid("vehicle.plane_speed")) {
		GameSettings.plane_speed_modifier[0] = AIGameSettings.GetValue("vehicle.plane_speed") - 1;
	}
}

function GameSettings::GetSubsidyMultiplier() {
	return GameSettings.subsidy_multipliers[GameSettings.subsidy[0]];
}

function GameSettings::GetMaxBuildableVehicles(vehicleType) {
	if (vehicleType >= GameSettings.maxVehiclesBuildLimit.len() || AIGameSettings.IsDisabledVehicleType(vehicleType))
		return 0;
	// Actual numbers of vehicles continually change so we need to update actual number.
	// Once every main loop is not enough.
	GameSettings.UpdateMaxVehicles(vehicleType);

	return GameSettings.maxVehiclesBuildLimit[vehicleType];
}

function GameSettings::IsBuildable(vehicleType) {
	if (vehicleType >= GameSettings.maxVehiclesBuildLimit.len() || AIGameSettings.IsDisabledVehicleType(vehicleType))
		return false;
	return GameSettings.maxVehiclesLimit[vehicleType] > 0;
}

function GameSettings::GetPlaneSpeedModifier() {
	return GameSettings.plane_speed_modifiers[GameSettings.plane_speed_modifier[0]];
}
