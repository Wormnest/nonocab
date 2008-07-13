//////////////////////////// VECTOR ///////////////////////////////////////////
class Vector
{
	size = null;
	elements = null;
	nrElements = null;

	constructor(size) {
		this.size = size;
		elements = array(size);
		nrElements = 0;
	}

	function Add(item);
	function Delete(index);
	function Get(index);
	function ToArray();
	function CheckAndExpand();
}

function Vector::Add(item)
{
	CheckAndExpand();

	elements[nrElements++] = item;
}

function Vector::Delete(index)
{
	if(!(index > -1) || !(index < nrElements)) 
		return null;

	local ret = elements[index];

	nrElements--;
	// Shift the rest of the elements after removing the item at index
	for(local i = index; i < nrElements; i++)
		elements[i] = elements[i + 1];

	return ret;
}

function Vector::Get(index)
{
	if(!(index > -1) || !(index < nrElements)) 
		return null;
	return elements[index];
}

function Vector::ToArray()
{
	local ret = array(nrElements);
	for(local i = 0; i < nrElements; i++)
		ret[i] = elements[i];
	return ret;
}

function Vector::CheckAndExpand()
{
	if(nrElements != size)
		return;

	size = size * 2;
	local tmpArray = array(size);

	// copy elements
	for(local i = 0; i < nrElements; i++)
		tmpArray[i] =  elements[i];

	// Set new array!
	elements = tmpArray;
}
