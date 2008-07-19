/**
 * Fibonacci heap.
 * This heap is heavily optimized for the Insert and Pop functions. Pop and
 * Pop and Peek always return the item with the lowest priority in the heap.
 * Insert is implemented as a lazy insert as it will simply add the new node
 * to the root list, the heap is sorted on every Pop operation.
 */
class FibonacciHeap {

	min = null;			// The pointer to the lowest value in the heap.
	min_index = 0;			// Index if the minimum node in the rootList.
	min_priority = 0;		// The priority of the minumum node.
	Count = 0;			// The number of nodes in this heap.
	rootList = null;		// The list with all nodes at the root level.
	
	/**
	 * Create a new fibonacci heap.
	 * http://en.wikipedia.org/wiki/Fibonacci_heap
	 */
	constructor() {
		Count = 0;
		min = Node();
		min.priority = 0x7FFFFFFF;
		min_index = 0;
		min_priority = 0x7FFFFFFF;
		rootList = [];
	}
	
	/**
	 * Insert a new entry in the heap.
	 *  The complexity of this operation is O(1).
	 * @param item The item to add to the list.
	 * @param priority The priority this item has.
	 */
	function Insert(item, priority);

	/**
	 * Pop the first entry of the list.
	 *  This is always the item with the lowest priority.
	 *  The complexity of this operation is O(ln n).
	 * @return The item of the entry with the lowest priority.
	 */
	function Pop();

	/**
	 * Peek the first entry of the list.
	 *  This is always the item with the lowest priority.
	 *  The complexity of this operation is O(1).
	 * @return The item of the entry with the lowest priority.
	 */
	function Peek();

	/**
	 * Get the amount of current items in the list.
	 *  The complexity of this operation is O(1).
	 * @return The amount of items currently in the list.
	 */
	function Count();

	/**
	 * Check if an item exists in the list.
	 *  The complexity of this operation is O(n).
	 * @param item The item to check for.
	 * @return True if the item is already in the list.
	 */
	function Exists(item);
}

function FibonacciHeap::Insert(item, priority) {

	/**
	 * Create a new node instance to add to the heap.
	 * Changing the parameters manualy is faster then adding them
	 * as parameters.
	 */
	local node = Node();
	node.item = item;
	node.priority = priority;

	/**
	 * Update the reference to the minimum node if this node has a
	 * smaller priority.
	 */
	if (min_priority > priority) {
		min = node;
		min_index = rootList.len();
		min_priority = priority;
	} 
	
	rootList.append(node);
	Count++;
}

function FibonacciHeap::Pop() {

	if (Count == 0)
		return null;

	/** 
	 * Bring variables from the class scope to this scope explicitly to
	 * optimize variable lookups by Squirrel.
	 */
	local z = min;
	local _rootList = rootList;
	
	/* If there are any children, bring them all to the root level. */
	_rootList.extend(z.child);

	/* Remove the minimum node from the rootList. */
	_rootList.remove(min_index);	
	local rootCache = {};

	/**
	 * Now we decrease the number of nodes on the root level by 
	 * merging nodes which have the same degree. The node with
	 * the lowest priority value will become the parent.
	 */
	foreach(x in _rootList) {
		local y;
		
		/* See if we encountered a node with the same degree already. */
		while (y = rootCache.rawdelete(x.degree)) {
		
			/* Check the priorities. */
			if (x.priority > y.priority) {
				local tmp = x;
				x = y;
				y = tmp;
			}

			/* Make y a child of x. */
			x.child.append(y);
			x.degree++;
		}
	
		rootCache[x.degree] <- x;
	}

	/**
	 * The rooCache contains all the nodes which will form the
	 * new rootList. We reset the priority to the maximum number
	 * for a 32 signed integer to find a new minumum.
	 */
	_rootList.resize(rootCache.len());
	local i = 0;
	local _min_priority = 0x7FFFFFFF;

	/* Now we need to find the new minimum among the root nodes. */
	foreach (val in rootCache) {
		if (val.priority < _min_priority) {
			min = val;
			min_index = i;
			_min_priority = val.priority;
		}

		_rootList[i++] = val;
	}
	
	/* Update global variables. */
	min_priority = _min_priority;	

	Count--;
	return z.item;
}

function FibonacciHeap::Peek() {
	return min.item;
}

function FibonacciHeap::Count() {
	return Count;
}

function FibonacciHeap::Exists(item) {
	return ExistsIn(rootList, item);
}

/**
 * Auxilary function to search through the whole heap.
 * @param list The list of nodes to look through.
 * @param item The item to search for.
 * @return True if the item is found, false otherwise.
 */
function FibonacciHeap::ExistsIn(list, item) {
	
	foreach (val in list) {
		if (val.item == item) {
			return true;
		}
		
		foreach (c in val.child) {
			if (ExistsIn(c, item)) {
				return true;
			}
		}
	}

	/* No luck, item doesn't exists in the tree rooted under _array. */
	return false;
}

/**
 * Basic class the fibonacci heap is composed of.
 */
class Node {
	degree = null;		// The number of children under this node.
	child = null;		// The children under this node.
	
	item = null;		// The anotated tile we want to insert into this heap.
	priority = null;	// The priority given to that item.
	
	/* item and priority are added manually for optimization purposes. */
	constructor() {
		child = [];
		degree = 0;
	}
}
