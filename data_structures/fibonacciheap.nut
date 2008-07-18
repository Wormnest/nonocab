class FibonacciHeap {

	min = null;			// The pointer to the lowest value in the heap.
	min_index = 0;
	Count = 0;			// The number of nodes in this heap.
	rootList = null;		// The list with all nodes at the root level.
	
	/**
	 * Create a new fibonacci heap.
	 * http://en.wikipedia.org/wiki/Fibonacci_heap
	 */
	constructor() {
		Count = 0;
		min = null;
		min_index = 0;
		rootList = array(0);
	}
	
	function Insert(x);
	function Pop(x);
}

function FibonacciHeap::Insert(item, priority) {
	local node = Node(item, priority);
	
	if (min == null) {
		min = node;
	} 
	
	// The new node has the minimum value so place it right of the node with minimum priority.
	else if (min.priority > priority) {
		node.right = node;
		node.left = min;
		min.right = node;
		min = node;
		min_index = rootList.len();
	}
	
	// Insert this node on the left side of the node with the minimal priority.
	else {
		node.right = min;
		
		if (min.left != min) {
			min.left.right = node;
			node.left = min.left;
		} else {
			node.left = node;
		}
			
		min.left = node;		
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
	foreach (val in z.child) {
		rootList.append(val);
	}

	rootList.remove(min_index);
	
	// Now we decrease the number of nodes on the root level by 
	// merging nodes which have the same degree. The node with
	// the lowest priority value will become the parent.

	// Consolidate

	local rootCache = {};

	// Remove nodes from the root level by making nodes
	// with the same degree children so there are no
	// nodes with the same degree on the root level.
	foreach(x in rootList) {
		local d = x.degree;
		
		// See if we encountered a node with the same degree already.
		local y;
		while ((y = rootCache.rawdelete(d)) != null) {

			// Check the priorities.
			if (x.priority > y.priority) {
				local tmp = x;
				x = y;
				y = tmp;
			}

			// Make y a child of x.
			x.child.append(y);
			x.degree++;

			d++;
		}
	
		rootCache[d] <- x;
	}
	min = null;

	rootList.clear();

	// Now we need to find the new minimum and fix all neighbours.
	local lastFoundRootCache = null;
	
	foreach(val in rootCache) {
		if (min == null || val.priority < min.priority) {
			min = val;
			min_index = rootList.len();
		}

		// Update neighbours.
		if (lastFoundRootCache) {
			val.left = lastFoundRootCache;
			lastFoundRootCache.right = val;
		} else {
			val.left = val;
		}
		lastFoundRootCache = val;

		rootList.append(val);	
	}
	
	if (lastFoundRootCache)
		lastFoundRootCache.right = lastFoundRootCache;
	
	Count--;
	return z.item;
}

function FibonacciHeap::PrintHeap() {
	print("Size: " + Count);
	print("Min key: [" + min.priority + "]");
	print("Left side of min key: ");
	print(PrintNode(min.left, 0, false));
	print("Right side of min key: ");
	print(PrintNode(min.right, 0, true));
	print("Done! :)");
	print("");
}

function FibonacciHeap::PrintNode(node, level, goRight) {
	if (node == null || node.priority == null)
		print("FATAL ERROR: NODE IS NULL!");
		
	local spacing = "";
	for (local i = 0; i < level; i++)
		spacing += "|   ";
	local str = "";
	str += "[" + node.priority;
	
	if (node.child.len() > 0)
	 	str += ", children: [";
	else 
		str += "]";
	print(spacing + str);
	
	for (local i = 0; i < node.child.len(); i++) {
		PrintNode(node.child[i], level + 1, true);
		
		if (node.child[i].left != node.child[i].right)
			PrintNode(node.child[i], level + 1, false);
	}
	
	if (node.child.len() > 0)
		print(spacing + "]");
	
	if (goRight && node.right.priority != node.priority) {
		PrintNode(node.right, level, true);
	} else if(!goRight && node.left.priority != node.priority) {
		PrintNode(node.left, level, false);
	}
	
	if (node.left != node && node.left.right != node ||
	    node.right != node && node.right.left != node) {
	    	print("FATAL ERRORRRRR!!!");
	}
}

class Node {
	degree = null;			// The number of children under this node.
	child = null;			// The children under this node.
	left = null;			// The node to the left of this node.
	right = null;			// The node to the right of this node.
	
	item = null;		// The anotated tile we want to insert into this heap.
	priority = null;
	
	constructor(item, priority) {
		this.item = item;
		this.priority = priority;
		this.left = this;
		this.right = this;
		child = array(0);
		this.degree = 0;
	}
}
