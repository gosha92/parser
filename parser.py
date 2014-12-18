import datetime

FILE_OFFSET = 0x1acd990800
MFT_RECORD_SIZE = 0x400
FIRST_ATTRIBUTE_OFFSET = 0x14
FILE_RECORD_SIZE = 0x18
ATTRIBUTE_TYPE = 0
ATTRIBUTE_CONTENT_LENGTH = 0x10
ATTRIBUTE_CONTENT_OFFSET = 0x14

STANDART_INFORMATION = 0x10
FILE_NAME = 0x30
DATA = 0x80

def readValue(hexBytes, offset, length):
	result = 0
	for i in range(1,length+1):
		result *= 0x100
		result += hexBytes[offset+length-i]
	return result

def readHexValue(hexBytes, offset, length):
	return hexBytes[offset:offset+length]

def intToDateTime(number):
	number -= 116444736000000000
	number /= 10000000
	return datetime.datetime.fromtimestamp(number)

def handleFlags(flags):
	result = ""
	if flags & 0x1 != 0:
		result += "only read, "
	if flags & 0x2 != 0:
		result += "hidden, "
	if flags & 0x4 != 0:
		result += "system, "
	if flags & 0x20 != 0:
		result += "archive, "
	if flags & 0x40 != 0:
		result += "device, "
	if flags & 0x80 != 0:
		result += "simple, "
	if flags & 0x100 != 0:
		result += "temp, "
	if flags & 0x200 != 0:
		result += "razrezheny, "
	if flags & 0x400 != 0:
		result += "point connection, "
	if flags & 0x800 != 0:
		result += "compressed, "
	if flags & 0x1000 != 0:
		result += "autonomy, "
	if flags & 0x2000 != 0:
		result += "no index, "
	if flags & 0x4000 != 0:
		result += "cyphered, "
	return result.strip(' ,')

def handleStandartInformationAttributeContent(attributeContent):
	print("File created time: %s" % intToDateTime(readValue(attributeContent, 0, 8)))
	print("File last modified time: %s" % intToDateTime(readValue(attributeContent, 0x8, 8)))
	print("File record last modified time: %s" % intToDateTime(readValue(attributeContent, 0x10, 8)))
	print("File record last accessed time: %s" % intToDateTime(readValue(attributeContent, 0x18, 8)))
	print("File flags: %s" % handleFlags(readValue(attributeContent, 0x20, 4)))
	return

def handleFileNameAttributeContent(attributeContent):
	# print("File size: %dB" % readValue(attributeContent, 0x30, 8))
	fileNameLength = readValue(attributeContent, 0x40, 1)
	print("File name: '%s'" % readHexValue(attributeContent, 0x42, fileNameLength*2).decode('utf-16'))
	return

def handleDataAttributeContent(attributeContent):
	print("File content '%s'" % str(attributeContent))
	return

def handleAttribute(attribute):
	attributeType = readValue(attribute, ATTRIBUTE_TYPE, 4)
	attributeContentLength = readValue(attribute, ATTRIBUTE_CONTENT_LENGTH, 4)
	attributeContentOffset = readValue(attribute, ATTRIBUTE_CONTENT_OFFSET, 2)
	attributeContent = attribute[attributeContentOffset:attributeContentOffset+attributeContentLength]	

	if attributeType == STANDART_INFORMATION:
		handleStandartInformationAttributeContent(attributeContent)
	elif attributeType == FILE_NAME:
		handleFileNameAttributeContent(attributeContent)
	elif attributeType == DATA:
		handleDataAttributeContent(attributeContent)

def handle(attributeOffset):
	attributeLength = readValue(data, attributeOffset+4, 4)
	handleAttribute(data[attributeOffset:attributeOffset+attributeLength])
	return attributeOffset+attributeLength

volumeFD = open("\\\\.\\C:","rb")
volumeFD.seek(FILE_OFFSET)
data = volumeFD.read(MFT_RECORD_SIZE)
length = readValue(data, FILE_RECORD_SIZE, 4)
attributeOffset = readValue(data, FIRST_ATTRIBUTE_OFFSET, 2)
while attributeOffset < length:
	attributeOffset = handle(attributeOffset)