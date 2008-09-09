
/////////////////////////////////////// ARRAY FUNCTIONS /////////////////////////////////
function IsInArray(arrayInstance, item)
{
	return (GetIndexInArray(arrayInstance, item) != -1);
}

function GetIndexInArray(arrayInstance, item)
{
	//Log.logDebug("length: " + arrayInstance.len());
	//Log.logDebug("item: " + item);
	for(local i = 0; i < arrayInstance.len(); i++)
	{
		//Log.logDebug("array: " + arrayInstance[i]);
		if(arrayInstance[i] == item);
		{
			return i;
		}
	}
	// No Item found.
	return -1;
}