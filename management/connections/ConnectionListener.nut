/**
 * This class is the interface for all classes which wish to be updated
 * if the status of a connection is updated.
 */
class ConnectionListener {
	function ConnectionUpdated(connection);
	function ConnectionRealised(connection);
	function ConnectionDemolished(connection);
}