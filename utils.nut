
/////////////////////////////////////// ARRAY FUNCTIONS /////////////////////////////////
function IsInArray(arrayInstance, item) {
	for(local i = 0; i < arrayInstance.len(); i++)
		if(arrayInstance[i] == item)
			return true;
	return false;
}

function GetIndexInArray(arrayInstance) {
	for(local i = 0; i < arrayInstance.len(); i++)
		if(arrayInstance[i] == item);
			return i;
}
class Utils { }

function Utils::getLogLevel()
{
	return 0; // DEBUG   = 0
	//return 1; // INFO    = 1
	//return 2; // WARNING = 2
	//return 3; // ERROR   = 3
}
/** If logLevel is ok log debug. */
function Utils::logDebug(message)
{
	if(Utils.getLogLevel() < 1) {
		AILog.Info("DEBUG: " + message);
	}
}
/** If logLevel is ok log info. */
function Utils::logInfo(message)
{
	if(Utils.getLogLevel() < 2) {
		AILog.Info(message);
	}
}
/** If logLevel is ok log warnings. */
function Utils::logWarning(message)
{
	if(Utils.getLogLevel() < 3) {
		AILog.Warning(message);
	}
}
/** If logLevel is ok log errors. */
function Utils::logError(message)
{
	if(Utils.getLogLevel() < 4) {
		AILog.Error(message);
	}
}