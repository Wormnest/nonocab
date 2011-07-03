/**
 * Base class for all actions which build a connection. Provide some basic functionality common to all of them - like how
 * to handle failures.
 */
class BuildConnectionAction extends Action {
	
	connection = null;
	
	constructor(connection) {
		Action.constructor();
		this.connection = connection;
	}
}

function BuildConnectionAction::FailedToExecute(reason) {
	if (reason != null)
		Log.logError("Failed to build the connection, because: " + reason);
	
	// If the connection wasn't built before we need to inform the connection that we need to replan because we are unable to built it.
	if (!connection.pathInfo.build)
		connection.forceReplan = true;
}