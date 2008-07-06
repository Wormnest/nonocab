
//////////////////////////////// UTILS /////////////////////////////////////////////
/**
 * These classes provide some basic data algorithms like
 * trees, priority queues, etc. All algorithms work on the
 * annotated AITile class (annotated with heuristic information
 * to be used for pathfinding).
 */
class PriorityQueue
{
	queue = null;	// The array containing all objects
	nrElements = 0;	// Number of elements in the array
	size = 0;	// The size of the actual queue

	/**
	 * Create the Qeueu with an initial size.
	 */
	constructor(size)
	{
		this.size = size;
		this.nrElements = 0;
		queue = array(this.size);
	}

	function insert(data);		// Insert data to the queue
	function remove();		// Remove data from the front of the queue
	function peek();		// Look at the first element in the queue
	function checkAndExpand();	// Expand the queue if it's getting to small
}

function PriorityQueue::insert(data)
{
	// Check if we're inserting  the right kind of data (should be AnnotatedTile)
	if(!(data instanceof AnnotatedTile)) 
	{
		print("PriorityQueue::insert -> Wrong data type!");
		return false;
	}

	// See if we need to expand the array
	checkAndExpand();

	// Find the new location of data
	if(nrElements == 0)
		queue[nrElements++] = data;	// Insert at 0
	else
	{
		local i;
		for(i = nrElements - 1; i >= 0; i--)	// Start at the end
		{
			if(data.getHeuristic() > queue[i].getHeuristic())	// If the distance is smaller
				queue[i + 1] = queue[i];	// shift old value upwards
			else if(data.tile == queue[i].tile)
				return;	// No double values!
			else	// If the distance is equal or larger
				break;	// Done shifting
		}
		queue[i + 1] = data;
		nrElements++;
	}

//	for(local j = 0; j < nrElements; j++)
		//print("Element after adding: " + queue[j]);
	return true;
}

/**
 * The smallest values are placed on top! So we return the top
 * value, while leaving the queue untouched (we don't need to
 * resize the queue since it's removed after pathfinding is done;
 * This function is only here for completeness).
 */
function PriorityQueue::remove()
{
	if(nrElements == 0)
		return null;

	return queue[--nrElements];
}

/**
 * Get the upper variable.
 */
function PriorityQueue::peek()
{
	if(size == 0)
		return null;
	return queue[nrElements - 1];
}

/**
 * Check if we need to enlarge the queue (only if it's filled
 * to the brim! We simply double the space of the array if it
 * needs to be expanded.
 */
function PriorityQueue::checkAndExpand()
{
	if(nrElements != size)
		return;

	size = size * 2;
	local tmpArray = array(size);

	// copy elements
	for(local i = 0; i < nrElements; i++)
		tmpArray[i] =  queue[i];

	// Set new array!
	queue = tmpArray;
}

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
