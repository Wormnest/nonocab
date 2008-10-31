class Log { 

	logLevel = 1;
}

/** If logLevel is ok log debug. */
function Log::logDebug(message)
{
	if(Log.logLevel < 1) {
		AILog.Info("DEBUG: " + message);
	}
}

/** If logLevel is ok log info. */
function Log::logInfo(message)
{
	if(Log.logLevel < 2) {
		AILog.Info("INFO: " + message);
	}
}

/** If logLevel is ok log warnings. */
function Log::logWarning(message)
{
	if(Log.logLevel < 3) {
		AILog.Warning("WARNING: " + message);
	}
}

/** If logLevel is ok log errors. */
function Log::logError(message)
{
	if(Log.logLevel < 4) {
		AILog.Error("ERROR: " + message);
	}
}
