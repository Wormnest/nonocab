class Log { }

function Log::getLogLevel()
{
	return 0; // DEBUG   = 0
	//return 1; // INFO    = 1
	//return 2; // WARNING = 2
	//return 3; // ERROR   = 3
}

/** If logLevel is ok log debug. */
function Log::logDebug(message)
{
	if(Log.getLogLevel() < 1) {
		AILog.Info("DEBUG: " + message);
	}
}

/** If logLevel is ok log info. */
function Log::logInfo(message)
{
	if(Log.getLogLevel() < 2) {
		AILog.Info("INFO: " + message);
	}
}

/** If logLevel is ok log warnings. */
function Log::logWarning(message)
{
	if(Log.getLogLevel() < 3) {
		AILog.Warning("WARNING: " + message);
	}
}

/** If logLevel is ok log errors. */
function Log::logError(message)
{
	if(Log.getLogLevel() < 4) {
		AILog.Error("ERROR: " + message);
	}
}
