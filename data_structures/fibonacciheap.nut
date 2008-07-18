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
		min = Node(null, 0x7FFFFFFF);
		min_index = 0;
		min_priority = 0x7FFFFFFF;
		rootList = [];
	}
	
	function Insert(x);
	function Pop(x);
}

function FibonacciHeap::Insert(item, priority) {
	local node = Node(item, priority);
	
	if (min_priority > priority) {
		min = node;
		min_index = rootList.len();
		min_priority = node.priority;
	} 
	
	rootList.append(node);
	Count++;
}

function FibonacciHeap::Pop() {

	if (Count == 0)
		return null;

	local z = min;
	
	// If there are any children, bring them all to the root
	// level.
	foreach (val in z.child)
		rootList.append(val);

	rootList.remove(min_index);	
	local rootCache = {};

	// Now we decrease the number of nodes on the root level by 
	// merging nodes which have the same degree. The node with
	// the lowest priority value will become the parent.
	foreach(x in rootList) {
		local y;
		
		// See if we encountered a node with the same degree already.
		while (y = rootCache.rawdelete(x.degree)) {

			// Check the priorities.
			if (x.priority > y.priority) {
				local tmp = x;
				x = y;
				y = tmp;
			}

			// Make y a child of x.
			x.child.append(y);
			x.degree++;
		}
	
		rootCache[x.degree] <- x;
	}

	rootList.resize(rootCache.len());
	local i = 0;
	min_priority = 0x7FFFFFFF;

	// Now we need to find the new minimum.
	foreach (val in rootCache) {
		if (val.priority < min_priority) {
			min = val;
			min_index = i;
			min_priority = val.priority;
		}

		rootList[i++] = val;
	}

	Count--;
	return z.item;
}

class Node {
	degree = null;		// The number of children under this node.
	child = null;		// The children under this node.
	
	item = null;		// The anotated tile we want to insert into this heap.
	priority = null;
	
	constructor(item_, priority_) {
		item = item_;
		priority = priority_;
		child = [];
		degree = 0;
	}
}
