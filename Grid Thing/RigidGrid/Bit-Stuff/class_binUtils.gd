class_name Util

static var maxInt = (2**63)-1
static var boxSize = 64

#region Bit Functions

static func bitsToStore(number:int) -> int:
	if (number == 1):
		return 1
	var bits:int = 1;
	var oneCount:int = number & 1;
	number >>= 1;
	while number != 0:
		oneCount += number & 1;
		bits += 1;
		number >>= 1;
	if (oneCount == 1):
		return bits - 1
	return bits

static func findRightSetBit(number:int) -> int:
	return number & -number

static func leftShift(number:int, bits:int) -> int:
	if (bits == 0):
		return number
	return (number & maxInt) << bits

static func rightShift(number:int, bits:int) -> int:
	if (bits == 0):
		return number
	var shiftedNumber:int = (number & maxInt) >> bits;
	if (number < 0):
		var saveSign:int = 1 << (63 - bits)
		shiftedNumber |= saveSign
	return shiftedNumber

#Idk if I like these two being here yet..
static func decode(key:int, rowSize:int) -> Vector2i:
	return Vector2i(key%rowSize, key/rowSize)

static func encode(coord:Vector2i, rowSize:int) -> int:
	return coord.y*rowSize + coord.x

#endregion

#region Mask Functions 

static func genMask(packSize:int, numOfPacks:int, instanceMask:int) -> int:
	var mask:int = 0;
	for pack in numOfPacks:
		mask = (mask << packSize) | instanceMask
	return mask

static func findMasksInInt(num:int) -> Array:
	var masks:Array = [];
	var leading0s:int = 0;
	while num != 0:
		var curMask:int = 0;
		var maskSize:int = 0;
		while num & 1 == 0:
			num = rightShift(num, 1)
			leading0s += 1
		while num & 1 == 1:
			curMask = (curMask << 1) + 1
			num = rightShift(num, 1)
			maskSize += 1;
		curMask = leftShift(curMask, leading0s);
		masks.push_back([curMask, leading0s, maskSize]);
		leading0s += maskSize;
	return masks

static func findFirstMask(num:int) -> int:
	var mask:int = findRightSetBit(num);
	while true:
		var nextMask = ((mask << 1) | mask) & num
		if (mask == nextMask):
			break
		mask = nextMask
	return mask

static func extendMask(num:int, mask:int) -> int:
	while true:
		var newMask = (leftShift(mask, 1) & num) | mask
		if (newMask == mask):
			break
		mask = newMask
	while true:
		var newMask = (rightShift(mask, 1) & num) | mask
		if (newMask == mask):
			break
		mask = newMask
	return mask

#endregion

#region binArray Deriving Functions

static func makeNextChecks(mask:int, rowNum:int, maxRow:int):
	var checks:Array = [
	false if rowNum + 1 == maxRow else Vector2i(mask, rowNum + 1),
	false if rowNum - 1 == -1 else Vector2i(mask, rowNum - 1)
	]
	return checks 

static func findGroups(binArray:Array[int], gridDims:Vector2i):
	var binaryArray = binArray.duplicate()
	#Can't search an empty grid
	if (binaryArray.all(func(r): return r == 0)): return []
	var groups:Array = []
	while (binaryArray.any(func(r): return r != 0)):
		var groupArray:Array[int] = []
		groupArray.resize(gridDims.y)
		groupArray.fill(0)
		groups.push_back(groupArray)
		var checks:Array = []
		for row in binaryArray.size(): #Find first row with data
			if (binaryArray[row] != 0):
				var fullMask = findFirstMask(binaryArray[row])
				checks.append_array(makeNextChecks(fullMask, row, binaryArray.size()))
				binaryArray[row] &= ~fullMask
				groupArray[row] |= fullMask
				break
		while checks.is_empty() == false:
			var curCheck = checks.pop_back()
			while typeof(curCheck) == 1: curCheck = checks.pop_back()
			if curCheck == null: break #checks is empty
			var newMask = binaryArray[curCheck.y] & curCheck.x
			while newMask != 0:
				var foundMask = findFirstMask(newMask)
				newMask &= ~foundMask
				var fullMask = extendMask(binaryArray[curCheck.y], foundMask) 
				binaryArray[curCheck.y] &= ~fullMask
				groupArray[curCheck.y] |= fullMask
				checks.append_array(makeNextChecks(fullMask, curCheck.y, binaryArray.size()))
	return groups

static func greedyRect(binArray:Array) -> Array:
	var binaryArray = binArray.duplicate()
	var meshedBoxes:Array = []
	#Actual meshing
	while (binaryArray.any(func(r): return r != 0)): #While grid hasn't been fully swept
		for row in binaryArray.size(): #Search each row
			var rowData:int = binaryArray[row];
			if (rowData == 0): #Row is empty
				continue #Go on to next row
			else: #At least one mask exists in current row
				var masks:Array = findMasksInInt(rowData);
				for maskData in masks: #For each mask found
					var curMask:int = maskData[0]
					var box:Rect2i = Rect2i(0,0,0,0)
					box.position.y = row;
					box.position.x = maskData[1];
					box.size.x = maskData[2];
					for curRowSearching in range(row, binaryArray.size()): #Search each remaining row
						if (binaryArray[curRowSearching] & curMask == curMask): #Mask exists in row
							binaryArray[curRowSearching] &= ~curMask; #Eliminate mask from row
							box.size.y += 1
						else:
							break #Mask does not exist in row, shape is complete
					meshedBoxes.push_back(box);
	return meshedBoxes

#endregion

#region binArray Handling Functions

class fixedPackedArray:
	var array:Array[int] = [];
	var totalPacks:int;
	var packSize:int;
	var packMask:int;
	var packsPerBox:int;
	var totalBoxes:int;
	func _init(storageNeeded:int, sizeOfPack:int):
		totalPacks = storageNeeded
		packSize = sizeOfPack
		packMask = 2**packSize - 1;
		packsPerBox = Util.boxSize/packSize
		totalBoxes = ceili(float(totalPacks)/packsPerBox);
		for box in totalBoxes:
			array.push_back(0);

static func packArray(array:Array[int]):
	if array.min() < 0:
		print("Packing negative numbers, how silly")
		return "NOPE"
	var packedArray = fixedPackedArray.new(array.size(), bitsToStore(array.max()))
	var curPack = 0
	for box in packedArray.totalBoxes:
		for pack in packedArray.packsPerBox:
			packedArray.array[box] |= array[box*packedArray.packsPerBox + pack] << pack*packedArray.packSize
			curPack += 1 
			if (curPack >= packedArray.totalPacks): break
	return packedArray

static func unpackArray(packedArray:fixedPackedArray):
	var unpackedArray = [];
	var curPack = 0
	for box in packedArray.totalBoxes:
		for pack in packedArray.packsPerBox:
			unpackedArray.push_back(rightShift(packedArray.array[box], pack*packedArray.packSize) & packedArray.packMask)
			curPack += 1 
			if (curPack >= packedArray.totalPacks): break

	return unpackedArray

static func resizePackedArray(_packedArray:fixedPackedArray, _newPackSize:int):
	pass

static func getPosition(index, packSize:int = 1):
	var packsPerBox:int = boxSize/packSize
	var boxNum = index/packsPerBox
	var padding = (index - boxNum*packsPerBox)*packSize
	return Vector2i(boxNum, padding)

#Returns [value, position]
static func readIndex(section:Array[int], index:int, packSize:int):
	var position = getPosition(index, packSize);
	return [rightShift(section[position.x], position.y) & genMask(packSize, 1, 1), position]

#returns oldValue
static func modifyIndex(array:Array[int], index:int, newVal:int, packSize:int = 1):
	var oldValue:Array = readIndex(array, index, packSize);
	array[oldValue[1].x] += Util.leftShift(newVal - oldValue[0], oldValue[1].y)
	return oldValue[0]

static func readSection(array:Array[int], packs:int, startIndex:int, packSize:int = 1):
	var packsPerBox:int = boxSize/packSize
	var packMask = genMask(packSize, 1, 1)
	var section:Array[int] = [];
	var curPos = getPosition(startIndex, packSize)
	var remPacksInCurBox:int = (boxSize - curPos.y)/packSize
	while packs > 0:
		var rightSideMask:int = genMask(packSize, min(remPacksInCurBox, packs), packMask);
		var packsInNextBox = min(boxSize, packs) - remPacksInCurBox
		var leftSideMask:int = Util.genMask(packSize, packsInNextBox, packMask) if (remPacksInCurBox > packs) else 0;
		var rightSide = Util.rightShift(array[curPos.x], curPos.y) & rightSideMask;
		var leftSide = Util.leftShift(array[curPos.x+1] & leftSideMask, remPacksInCurBox * packSize) if (remPacksInCurBox < packs) else 0;
		section.push_back(rightSide + leftSide);
		packs -= packsPerBox;
		curPos.x += 1;
		remPacksInCurBox = boxSize - packsInNextBox;
	return section


#endregion

#
