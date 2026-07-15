local VersionConfig = require(script.Parent.VersionConfig)

local CHARACTER_SET_B72 = {	'b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'm', 'p', 'q', 'r', 't', 'v', 'w', 'x', 'y',
	'3', '4', '6', '7', '8', '9', '!', '\"', '#', '$', '%', '&', '\'',	'(', ')', '*', '+', ',', '-', '.', '/',
	':', ';', '<', '=', '>', '?', '@', 'B', 'C', 'D', 'F', 'G', 'H', 'J', 'K', 'M', 'P', 'Q', 'R', 'T', 'V', 'W', 'X', 'Y',
	'[', '\\', ']', '^', '_', '`', '{', '|', '}', '~'}

local CHARACTER_SET = {}
for i=0, 255 do
	CHARACTER_SET[i+1] = string.char(i)
end

local characterKeys = {
	B72  = {},
	B256 = {},
}

local characterValues = {
	B72  = {},
	B256 = {},
}

for _, cset in ipairs{CHARACTER_SET_B72, CHARACTER_SET} do
	local is_b72 = (cset == CHARACTER_SET_B72)
	local k = is_b72 and "B72" or "B256"

	local ckeys = characterKeys[k]
	local cvals = characterValues[k]
	for i, char in ipairs(cset) do
		ckeys[char] = i - 1
		cvals[i - 1] = char
	end
end

local function getCharSet(static)
	if VersionConfig.UseBase72 or static then
		return 72, characterKeys.B72, characterValues.B72
	else
		--warn("HOWHEAWOUIDHOUAWHOUIDHJANW")
		return 256, characterKeys.B256, characterValues.B256
	end
end

local stringConversion
stringConversion = {
	StringToNumber = function(str, cursor, size, static)
		local count, keys, _ = getCharSet(static)
		local total = 0
		for i = cursor, cursor + size - 1 do
			local char = str:sub(cursor, cursor)
			total = total * count + keys[char]
			cursor += 1
		end 
		return total
	end,

	NumberToString = function(number, charCount, static)
		if math.isinf(number) then
			if math.sign(number) > 0 then
				local max = stringConversion.GetMaxNumber(charCount, static)
				warn(`Converting +Inf to a finite number! Will use maximum representable number ({max}), fix if unintended`)
				number = max
			else
				warn(`Converting -Inf to a finite number! Will use minimum representable number (0), fix if unintended`)
				number = 0
			end
		elseif math.isnan(number) then
			warn("Converting NaN (not a number) to a number! Will use 0, fix if unintended")
			number = 0
		end
		local count, _, vals = getCharSet(static)
		local str = ""
		local iteration = 0
		while number >= 0 and iteration < charCount do
			local value = number % count
			str = vals[value] .. str
			number = math.floor(number / count)
			iteration += 1
		end
		return str
	end,

	GetMaxNumber = function(charCount, static)
		local count, _, _ = getCharSet(static)
		return math.pow(count, charCount) - 1
	end,
}

return stringConversion