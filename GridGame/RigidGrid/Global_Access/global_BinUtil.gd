class_name BinUtil

static var maxInt = (2**63)-1
static var boxSize = 64

#region Bit Functions

static func bitCount(number:int):
	var bits = 0
	while number != 0: #While number still has relevant bits
		bits += 1
		number >>= 1
	return bits

static func bitsToStore(number:int) -> int:
	if (number == 1): #Slightly more complicated than bitCount, returns how many bits are required to store number of values
		return 1
	var bits:int = 1
	var oneCount:int = number & 1
	number >>= 1
	while number != 0: #While number still has relevant bits
		oneCount += number & 1 #Count the number of ones
		bits += 1
		number >>= 1
	if (oneCount == 1): #If number is a power of 2, it can be stored in one less bit (storing 4 (0b100) values takes 2 bits (0b00 through 0b11)
		return bits - 1
	return bits

static func findRightSetBit(number:int) -> int:
	return number & -number #Funny math trick, I don't really understand it

static func leftShift(number:int, bits:int) -> int:
	if (bits == 0): #Stupid stupid godot, won't shift negative numbers
		return number #This means that I have to make numbers positive before shifting them
	return (number & maxInt) << bits #And bc it's a leftshift, the sign bit will be lost anyways so I can just mask it out

static func rightShift(number:int, bits:int) -> int:
	if (bits == 0): #Same as above, except
		return number
	var shiftedNumber:int = (number & maxInt) >> bits
	if (number < 0): #Now we have to preserve the sign bit
		var saveSign:int = 1 << (63 - bits)
		shiftedNumber |= saveSign
	return shiftedNumber

#Idk if I like these two being here yet..
static func keyToCell(key:int, rowSize:int) -> Vector2i:
	return Vector2i(key%rowSize, key/rowSize)

static func cellToKey(cell:Vector2i, rowSize:int) -> int:
	return cell.y*rowSize + cell.x

#endregion

#region Mask Functions 

static func genMask(bits:int) -> int:
	var mask = 0
	for bit in bits:
		mask = (mask << 1) | 1
	return mask

#This function really really messed with me so I split it into it and the one above it
static func repMask(packSize:int, repetitions:int, mask:int) -> int:
	var newMask:int = 0
	for rep in repetitions:
		newMask = (newMask << packSize) | mask
	return newMask

#These three funcs are very similar, maybe can be merged/rewritten?
static func findMasksInInt(num:int) -> Array:
	var masks:Array = []
	var leading0s:int = 0
	while num != 0: #While relevant bits still exist, will cycle once for each continous mask
		var curMask:int = 0
		var maskSize:int = 0
		while num & 1 == 0: #Get rid of leading 0's
			num = rightShift(num, 1)
			leading0s += 1
		while num & 1 == 1: #While handling a mask
			curMask = (curMask << 1) | 1 #Expand the mask
			num = rightShift(num, 1)
			maskSize += 1
		curMask = leftShift(curMask, leading0s) #Shift the mask to the correct position
		masks.push_back([curMask, leading0s, maskSize]) #Preserve data so it doesn't need to be rederived later
		leading0s += maskSize #The current mask will become leading 0's for the next mask
	return masks

static func findFirstMask(num:int):
	var mask:int = findRightSetBit(num) #Cheating to skip all leading 0s
	var size = 1 #Preserve size so it doesn't need to be rederived later
	while true: #Not an inf loop, trust
		var nextMask = (leftShift(mask, 1) | mask) & num #Expand mask one to the left
		if (mask == nextMask): #If mask doesn't change (lefter bit is a 0)
			break
		mask = nextMask
		size += 1
	return [mask, size]

static func extendMask(num:int, mask:int):
	var leftExpands:int = 0 #Preserve size so it doesn't need to be rederived later
	var rightExpands:int = 0 # ^^^
	while true: #Not inf loop
		var newMask = (leftShift(mask, 1) & num) | mask #Expand mask one to the left
		if (newMask == mask): #If mask doesn't change (lefter bit is a 0)
			break
		mask = newMask
		leftExpands += 1
	while true: #Read above but to the right
		var newMask = (rightShift(mask, 1) & num) | mask
		if (newMask == mask):
			break
		mask = newMask
		rightExpands += 1
	return [mask, [leftExpands, rightExpands]]

#endregion

#region binArray Deriving Functions

static func makeNextChecks(mask:int, rowNum:int, lowerBound:int, upperBound:int):
	if mask == 0: return []
	var checks = []
	if rowNum - 1 >= lowerBound: checks.push_back(Vector2i(mask, rowNum - 1)) #Check down a row
	#This logic looks weird, it's because arrays are 0 indexed but .size() isn't and I don't wanna subtract 1 from upperbound on each call
	if rowNum + 1 != upperBound: checks.push_back(Vector2i(mask, rowNum + 1)) #Check up a row
	return checks

#'Functions should be general tools which blah blah blah' I'll generalize it when I need it
static func checkIndexesForNon0(array:Array[int], startingIndex:int, endingIndex:int):
	for index in endingIndex - startingIndex:
		if array[startingIndex + index] != 0:
			return true
	return false

class Group: #Data class
	var blockCount:int
	var binGrid:Array[int]
	var grid:Array = [] 
	var fittedGrid:Array = []
	var topLeftCell:Vector2i = Vector2i(-1, -1)
	
	func _init(data:Array[int], blocks:int):
		binGrid = data
		blockCount = blocks
		grid.resize(binGrid.size())
	
	func convertBinGridToGrid(referenceGrid:Array):
		var minStart:int = packedGrid.blocksPerBox + 1
		var endIndex:int = 0
		for row in referenceGrid.size():
			var rowData = BinUtil.intToPackedArray(referenceGrid[row], binGrid[row])
			grid[row] = rowData[0]
			if binGrid[row] != 0:
				if rowData[1][0] < minStart: 
					minStart = rowData[1][0]
				if rowData[1][1] + rowData[1][0] > endIndex: 
					endIndex = rowData[1][1] + rowData[1][0]
		topLeftCell.x = minStart
		return [minStart, endIndex - minStart]
	
	func copyGridToGroup(referenceGrid:Array):
		var fittedGridInfo:Array = convertBinGridToGrid(referenceGrid)
		for row in binGrid.size():
			if binGrid[row] != 0:
				if topLeftCell.y == -1:
					topLeftCell.y = row
				fittedGrid.push_back(BinUtil.readSection(grid[row], fittedGridInfo[1], fittedGridInfo[0], packedGrid.bitsPerBlock))
			elif topLeftCell.y != -1:
				break #If an entire row is null, we know the object can't extend through it and are done

static func findGroups(binArray:Array[int], numOfRows:int):
	var binaryArray = binArray.duplicate()
	var groups:Array = []
	var lowerBound = 0
	while (checkIndexesForNon0(binaryArray, lowerBound, numOfRows)): #While there is unmatched data
		var blockCount:int = 0 #Save size of group
		var groupArray:Array[int] = []
		groupArray.resize(numOfRows)
		for row in numOfRows: groupArray[row] = 0
		var searchQueue:Array = []
		for row in numOfRows - lowerBound:
			var realRow = row + lowerBound
			if (binaryArray[realRow] != 0): #Find first row with data
				lowerBound = realRow #First row with data means all rows below are 0
				var fullMask = findFirstMask(binaryArray[realRow]) #Where we'll start looking
				blockCount += fullMask[1]
				searchQueue.append_array(makeNextChecks(fullMask[0], realRow, lowerBound, numOfRows)) #Add requests to queue for search
				binaryArray[realRow] &= ~fullMask[0]
				groupArray[realRow] |= fullMask[0]
				break #We've found our mask
		while searchQueue.is_empty() == false: #While the queue isn't empty
			var curCheck = searchQueue.pop_back()
			var newMask = binaryArray[curCheck.y] & curCheck.x
			while newMask != 0: #While relevant bits still exist, find all masks within the data
				var foundMask = findFirstMask(newMask)
				blockCount += foundMask[1]
				newMask &= ~foundMask[0]
				var fullMask = extendMask(binaryArray[curCheck.y], foundMask[0]) #Found a mask
				binaryArray[curCheck.y] &= ~fullMask[0]
				groupArray[curCheck.y] |= fullMask[0]
				searchQueue.append_array(makeNextChecks(fullMask[0], curCheck.y, lowerBound, numOfRows)) #Make checks for the mask (up and down)
				blockCount += fullMask[1][0] + fullMask[1][1] #Count blocks in group
		groups.push_back(Group.new(groupArray, blockCount))
	return groups

static func greedyRect(binArray:Array) -> Array:
	var binaryArray = binArray.duplicate()
	var meshedBoxes:Array = []
	#Actual meshing
	for row in binaryArray.size(): #Search each row
		var rowData:int = binaryArray[row]
		if (rowData == 0):
			continue #Row is empty, go on to next row
		#else: At least one mask exists in current row
		var masks:Array = findMasksInInt(rowData)
		for maskData in masks: #For each mask found
			var curMask:int = maskData[0]
			var box:Rect2i = Rect2i(0,0,0,0)
			box.position.y = row
			box.position.x = maskData[1]
			box.size.x = maskData[2]
			for curRowSearching in range(row, binaryArray.size()): #Search each remaining row
				if (binaryArray[curRowSearching] & curMask == curMask): #Mask exists in row
					binaryArray[curRowSearching] &= ~curMask #Eliminate mask from row
					box.size.y += 1
				else:
					break #Mask does not exist in row, shape is complete
			meshedBoxes.push_back(box)
	return meshedBoxes

#endregion

#region binArray Handling Functions

class fixedPackedArray: #Stores data packed at a set number of bits within integers (boxes). Data does not transcend boxes (boxes don't do partial data)
	var array:Array[int] = []
	var totalPacks:int
	var packSize:int
	var packMask:int
	var packsPerBox:int
	var totalBoxes:int
	func _init(storageNeeded:int, sizeOfPack:int):
		totalPacks = storageNeeded
		packSize = sizeOfPack
		packMask = 2**packSize - 1
		packsPerBox = BinUtil.boxSize/packSize
		totalBoxes = ceili(float(totalPacks)/packsPerBox)
		for box in totalBoxes:
			array.push_back(0)

static func packArray(array:Array[int]):
	if array.min() < 0: #Negative numbers are all silly with their bits
		print("Packing negative numbers, how silly")
		return "NOPE"
	var packedArray = fixedPackedArray.new(array.size(), bitsToStore(array.max())) #Get all my helper variables set up
	var curPack = 0
	for box in packedArray.totalBoxes:
		for pack in packedArray.packsPerBox:
			packedArray.array[box] |= array[box*packedArray.packsPerBox + pack] << pack*packedArray.packSize #Shift the data to it's index and mask it in
			curPack += 1 
			if (curPack >= packedArray.totalPacks): break #If we've packed all data, don't keep going, we don't need to fill the box
	return packedArray

static func unpackArray(packedArray:fixedPackedArray):
	var unpackedArray = []
	var curPack = 0
	for box in packedArray.totalBoxes:
		for pack in packedArray.packsPerBox:
			unpackedArray.push_back(rightShift(packedArray.array[box], pack*packedArray.packSize) & packedArray.packMask) #Shift the data back and mask it out
			curPack += 1 
			if (curPack >= packedArray.totalPacks): break #If we've read all the data, don't keep unpacking the empty box
	return unpackedArray

class Address: #Data class
	var box:int
	var shift:int
	func _init(boxNum:int, padding:int):
		box = boxNum
		shift = padding

static func getPosition(index, packSize:int = 1):
	var packsPerBox:int = boxSize/packSize
	var boxNum = index/packsPerBox #Integer division trunc()s
	var padding = (index - boxNum*packsPerBox)*packSize #Figure out how many bits are between the start of the box and my index
	return Address.new(boxNum, padding)

static func accessIndex(data:Array[int], index:int, packSize:int, modify:int = 0):
	var pos = getPosition(index, packSize)
	var curVal = rightShift(data[pos.box], pos.shift) & genMask(packSize) #Shift the data over and mask it out
	if (modify != 0):
		data[pos.box] += leftShift(modify - curVal, pos.shift) #Funny trick to change value quickly
	return curVal

static func readSection(array:Array, packs:int, startIndex:int, packSize:int):
	var packMask = genMask(packSize)
	var packsPerBox:int = boxSize/packSize
	var section:Array[int] = []
	var pos = getPosition(startIndex, packSize)
	var remPacksInCurBox:int = (boxSize - pos.shift)/packSize
	while packs > 0:
		var rightSideMask:int = repMask(packSize, min(remPacksInCurBox, packs), packMask) #Mask for the packs in the current box
		var packsInNextBox = min(boxSize, packs) - remPacksInCurBox #Do I need to concat two boxes together?
		var leftSideMask:int = repMask(packSize, packsInNextBox, packMask) if (remPacksInCurBox > packs) else 0 #Mask for the next box (if needed else 0)
		var rightSide = rightShift(array[pos.box], pos.shift) & rightSideMask #Data from current box
		var leftSide = leftShift(array[pos.box+1] & leftSideMask, remPacksInCurBox * packSize) if leftSideMask != 0 else 0 #Data from next box (if needed else 0)
		section.push_back(rightSide | leftSide) #Combine the data
		packs -= packsPerBox #Mark those packs as handled
		pos.box += 1
		remPacksInCurBox = boxSize - packsInNextBox
	return section

static func intToPackedArray(mirrorPackedArray:Array, bitRow:int):
	var row:Array[int] = []
	var rowMask:Array[int] = [0]
	var length:int = 0
	var start:int = 0
	var curBlock:int = 0
	var curBox:int = 0
	while bitRow != 0:
		if (curBlock == packedGrid.blocksPerBox): #Yeah I could do this with division instead of two variables, shut up this is better
			curBlock = 0
			curBox += 1
			rowMask.push_back(0)
		if bitRow & 1: rowMask[curBox] |= packedGrid.blockMask << curBlock * packedGrid.bitsPerBlock #Put in the blockMask on the current block
		if bitRow & 1 || length != 0: length += 1 #If current block is set, we've found a block which is set
		if length == 0: start += 1 #If current block isn't set but there was already at least one set block, this unset block is sandwiched by set ones
		bitRow = BinUtil.rightShift(bitRow, 1)
		curBlock += 1
	for box in mirrorPackedArray.size():
		row.push_back(mirrorPackedArray[box] & rowMask[box])
	return [row, [start, length]] #Preserve start and length for grid culling later

static func packedArrayToInt(packedArray:Array, matchedValues:Dictionary) -> Dictionary:
	var bitRows:Dictionary = {}
	for block in matchedValues: 
		bitRows[block] =  0
	var curMask = 1
	var row = packedArray.duplicate()
	for box in row.size():
		for block in packedGrid.blocksPerBox:
			var curVal:int = row[box] & packedGrid.blockMask
			row[box] = BinUtil.rightShift(row[box], packedGrid.bitsPerBlock)
			if matchedValues.has(curVal): bitRows[curVal] |= curMask
			if (curMask > 0): curMask <<= 1 #Stop from shifting negative number on the last check of a 64 block row (bc godot is stupid)
	return bitRows

#endregion

#
