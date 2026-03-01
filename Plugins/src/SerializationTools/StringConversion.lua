local CHARACTER_SET = {
	"b",
	"c",
	"d",
	"f",
	"g",
	"h",
	"j",
	"k",
	"m",
	"p",
	"q",
	"r",
	"t",
	"v",
	"w",
	"x",
	"y",
	"3",
	"4",
	"6",
	"7",
	"8",
	"9",
	"!",
	'"',
	"#",
	"$",
	"%",
	"&",
	"'",
	"(",
	")",
	"*",
	"+",
	",",
	"-",
	".",
	"/",
	":",
	";",
	"<",
	"=",
	">",
	"?",
	"@",
	"B",
	"C",
	"D",
	"F",
	"G",
	"H",
	"J",
	"K",
	"M",
	"P",
	"Q",
	"R",
	"T",
	"V",
	"W",
	"X",
	"Y",
	"[",
	"\\",
	"]",
	"^",
	"_",
	"`",
	"{",
	"|",
	"}",
	"~",
}

local characterKeys = {}
local characterValues = {}
for i, v in pairs(CHARACTER_SET) do
	characterKeys[v] = i - 1
	characterValues[i - 1] = v
end

local CHAR_COUNT = #CHARACTER_SET
return {
	StringToNumber = function(str, cursor, size)
		local total = 0
		for i = cursor, cursor + size - 1 do
			local char = str:sub(cursor, cursor)
			total = total * CHAR_COUNT + characterKeys[char]
			cursor += 1
		end
		return total
	end,

	NumberToString = function(number, charCount)
		local buf = table.create(charCount)
		for i = charCount, 1, -1 do
			local value = number % CHAR_COUNT
			buf[i] = characterValues[value]
			number = math.floor(number / CHAR_COUNT)
		end
		return table.concat(buf)
	end,

	GetMaxNumber = function(charCount)
		return math.pow(CHAR_COUNT, charCount) - 1
	end,
}
