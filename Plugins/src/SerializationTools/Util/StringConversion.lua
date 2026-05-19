local CHARACTER_SET = {	'b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'm', 'p', 'q', 'r', 't', 'v', 'w', 'x', 'y',
						'3', '4', '6', '7', '8', '9', '!', '\"', '#', '$', '%', '&', '\'',	'(', ')', '*', '+', ',', '-', '.', '/',
						':', ';', '<', '=', '>', '?', '@', 'B', 'C', 'D', 'F', 'G', 'H', 'J', 'K', 'M', 'P', 'Q', 'R', 'T', 'V', 'W', 'X', 'Y',
						'[', '\\', ']', '^', '_', '`', '{', '|', '}', '~'}

local characterKeys = {}
local characterValues = {}
for i, v in pairs(CHARACTER_SET) do
    characterKeys[v] = i - 1;
    characterValues[i - 1] = v;
end

local CHAR_COUNT = #CHARACTER_SET
local stringConversion
stringConversion = {
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
		if math.isinf(number) then
			if math.sign(number) > 0 then
				local max = stringConversion.GetMaxNumber(charCount)
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
		local str = ""
		local iteration = 0
		while number >= 0 and iteration < charCount do
			local value = number % CHAR_COUNT
			str = characterValues[value] .. str
			number = math.floor(number / CHAR_COUNT)
			iteration += 1
		end
		return str
	end,

	GetMaxNumber = function(charCount)
		return math.pow(CHAR_COUNT, charCount) - 1
	end,
}

return stringConversion