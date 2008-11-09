class AircraftAdvisor extends Advisor {

	reportTable = null;
	world = null;
	
	constructor (world) {
		this.world = world;
		reportTable = {};
		local currentDate = AIDate.GetCurrentDate();
	}
	
	function GetReports();
	function Update(loopCounter);
}

function AircraftAdvisor::Update(loopCounter) {
		
	if (loopCounter == 0) {
		// Check if some connections in the reportTable have been build, if so remove them!
		local reportsToBeRemoved = [];
		foreach (report in reportTable)
			if (report.connection.pathInfo.forceReplan || report.connection.pathInfo.build)
				reportsToBeRemoved.push(report);
		
		foreach (report in reportsToBeRemoved)
			reportTable.rawdelete(report.connection.GetUID());
	}

	local maxSize = 3 * (1 + loopCounter);
	
	// First get a list of all good towns.
	foreach (from in world.townConnectionNodes) {
		foreach (to in from.connectionNodeList) {

			if (AITown.GetPopulation(from.id) < 500 ||
			AITown.GetPopulation(to.id) < 500)
				continue;

			foreach (cargo in AICargoList()) {

				if (to.GetProduction(cargo) == 0 || from.GetProduction(cargo) == 0)
					continue;
					
				local connection = from.GetConnection(to, cargo);
				if (connection == null) {
					connection = Connection(cargo, from, to, PathInfo(null, 0));
					from.AddConnection(to, connection);
				} else if (connection.pathInfo.build || reportTable.rawin(connection.GetUID()))
					continue;

				local engine = world.cargoTransportEngineIds[AIVehicle.VEHICLE_AIR][cargo];
				local report = connection.CompileReport(world, engine);
						
				if (report.isInvalid || report.nrVehicles < 1)
					continue;
						
				// Generate a report.
				if (reportTable.rawin(connection.GetUID())) {
					local otherReport = reportTable.rawget(connection.GetUID());
					if (otherReport.Utility() >= report.Utility())
						continue;
				}
						
				reportTable[connection.GetUID()] <- report;
				Log.logInfo("[" + reportTable.len() + "/" + maxSize + "] " + report.ToString());

				if (reportTable.len() > maxSize)
					return;
			}
		}
	}
}

function AircraftAdvisor::GetReports() {
	// We have a list with possible connections we can afford, we now apply
	// a subsum algorithm to get the best profit possible with the given money.
	local reports = [];
	local processedProcessingIndustries = {};
	
	foreach (report in reportTable) {
	
		// The industryConnectionNode gives us the actual connection.
		local connection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
	
		// Check if this industry has already been processed, if this is the
		// case, we won't add it to the reports because we want to prevent
		// an industry from being exploited by different connections which
		// interfere with eachother. i.e. 1 connection should suffise to bring
		// all cargo from 1 producing industry to 1 accepting industry.
		if (processedProcessingIndustries.rawin(connection.GetUID()))
			continue;
			
		// Update report.
		report = connection.CompileReport(world, report.engineID);
			
		Log.logInfo("Report an air connection from: " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " with " + report.nrVehicles + " vehicles! Utility: " + report.Utility());
		local actionList = [];
			
		// Give the action to build the airfield.
		actionList.push(BuildAirfieldAction(connection, world));
			
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();

		// Buy only half of the vehicles needed, build the rest gradualy.
		report.nrVehicles = report.nrVehicles / 2;
		if (report.nrVehicles < 1)
			continue;
		vehicleAction.BuyVehicles(report.engineID, report.nrVehicles, connection);
		
		actionList.push(vehicleAction);
		report.actions = actionList;

		// Create a report and store it!
		reports.push(report);
		processedProcessingIndustries[connection.GetUID()] <- connection.GetUID();
	}
	
	return reports;
}

