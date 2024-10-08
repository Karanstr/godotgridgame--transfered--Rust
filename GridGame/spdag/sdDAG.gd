class_name SparseDimensionalDAG

#For now we're going to use arrays and o(n) it instead of hashing/lookups.
class Nodes:
	var pot:Array = []
	
	class Branch:
		var children:Array[int]
		var refCount:int = 0
		func _init(kids:Array[int] = [-1, -1]):
			children = kids.duplicate()
		func duplicate():
			var newBranch = Branch.new(children)
			return newBranch
	
	func _init(layers:int):
		for layer in layers:
			pot.push_back([])
		addNode(layers - 1, Branch.new())
	
	#This feels like it should be reworked at some point, doesn't matter yet tho
	func findFirstOpenSpot(layer):
		for i in pot[layer].size():
			if typeof(pot[layer][i]) == 2:
				return i
		pot[layer].push_back(-1)
		return pot[layer].size() - 1
	
	func findFirstSet(layer):
		for i in pot[layer].size():
			if typeof(pot[layer][i]) != 2:
				return i
	
	func getNodeIndex(layer, node) -> int:
		for index in pot[layer].size():
			if typeof(pot[layer][index]) == 2: #Is type int
				continue
			if pot[layer][index].children == node.children:
				return index
		return -1
	
	func getNode(layer, index):
		if index == -1:
			return -1
		var node = pot[layer][index]
		if typeof(node) == 2 || index == -1:
			return -1 #Node isn't set
		return node
	
	func addNode(layer, node) -> int:
		var potIndex = getNodeIndex(layer, node)
		if potIndex != -1:
			return potIndex
		var index = findFirstOpenSpot(layer)
		pot[layer][index] = node
		return index
	
	func getNodeWithModifiedChildren(layer, index, childDirection, childIndex):
		var preNode = getNode(layer, index)
		var newNode
		if typeof(preNode) == 2: #There is no node at index
			newNode = Branch.new()
		else:
			newNode = preNode.duplicate()
		newNode.children[childDirection] = childIndex
		if layer != 0:
			for child in newNode.children:
				if child != -1: #If child is set
					pot[layer - 1][child].refCount += 1 #We are referencing child here
		return newNode
		
	func decRef(layer, index):
		var node = getNode(layer, index)
		if typeof(node) != 2:
			node.refCount -= 1
			if node.refCount <= 0:
				if layer != 0:
					for child in node.children:
						if child != -1:
							decRef(layer - 1, child) #I hate recursion
				pot[layer][index] = -1

var nodes:Nodes
var topLayer:int

func _init(layerCount:int = 1):
	nodes = Nodes.new(layerCount)
	topLayer = layerCount - 1

func getPathIndi(path) -> Array[int]:
	var trail:Array[int] = []
	trail.resize(topLayer + 1)
	trail.fill(-1)
	var root:int = nodes.findFirstSet(topLayer)
	trail[topLayer] = root
	var curLayer = topLayer
	var curNode = nodes.getNode(topLayer, root)
	while curLayer != 0: #Descend until we're at the bottom
		var kidDirection = (path >> curLayer) & 0b1
		if curNode.children[kidDirection] == -1: #The path ends
			return trail
		var kidIndex = curNode.children[kidDirection & 0b1]
		trail[curLayer - 1] = kidIndex
		curNode = nodes.getNode(curLayer - 1, kidIndex)
		curLayer -= 1
	return trail

func addData(path:int):
	var pathIndexes:Array[int] = getPathIndi(path) #Path from leaf[0] to root[size-1]
	if pathIndexes[0] != -1 && nodes.getNode(0, pathIndexes[0]).children[path & 0b1] == 1: 
		return #Node exists and is already set
	var lastIndex:int = 1 #We want to set our leaf to 1
	for layer in pathIndexes.size():
		var node = nodes.getNodeWithModifiedChildren(layer, pathIndexes[layer], (path >> layer) & 0b1, lastIndex)
		lastIndex = nodes.addNode(layer, node)
		nodes.decRef(layer, pathIndexes[layer])

func readLeaf(path:int):
	var leafAddr = getPathIndi(path)[0] #Path from leaf to root
	if leafAddr == -1:
		return 0
	return nodes.getNode(0, leafAddr).children[path & 0b1]

func expandTree(_filledQuadrant:int):
	pass
