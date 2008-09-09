
/////////////////////////////////////// ARRAY FUNCTIONS /////////////////////////////////
function IsInArray(arrayInstance, item)
{
	return (GetIndexInArray(arrayInstance, item) != -1);
}

function GetIndexInArray(arrayInstance, item)
{
	for(local i = 0; i < arrayInstance.len(); i++)
	{
		if(arrayInstance[i] == item);
		{
			return i;
		}
	}
	// No Item found.
	return -1;
}