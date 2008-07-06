
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
