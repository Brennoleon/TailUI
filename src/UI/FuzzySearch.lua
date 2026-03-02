local FuzzySearch = {}

local function normalize(text)
	text = tostring(text or ""):lower()
	text = text:gsub("[%c%p]", " ")
	text = text:gsub("%s+", " ")
	text = text:gsub("^%s+", "")
	text = text:gsub("%s+$", "")
	return text
end

local function levenshtein(a, b)
	local lenA = #a
	local lenB = #b
	if lenA == 0 then
		return lenB
	end
	if lenB == 0 then
		return lenA
	end

	local matrix = {}
	for i = 0, lenA do
		matrix[i] = { [0] = i }
	end
	for j = 0, lenB do
		matrix[0][j] = j
	end

	for i = 1, lenA do
		for j = 1, lenB do
			local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
			matrix[i][j] = math.min(
				matrix[i - 1][j] + 1,
				matrix[i][j - 1] + 1,
				matrix[i - 1][j - 1] + cost
			)
		end
	end

	return matrix[lenA][lenB]
end

local function subsequenceScore(query, target)
	local qi = 1
	local score = 0
	for i = 1, #target do
		if target:sub(i, i) == query:sub(qi, qi) then
			score = score + 1
			qi = qi + 1
			if qi > #query then
				break
			end
		end
	end
	if qi <= #query then
		return 0
	end
	return (score / #target) * 60
end

function FuzzySearch.score(query, text)
	query = normalize(query)
	text = normalize(text)
	if query == "" or text == "" then
		return 0
	end

	if text:find(query, 1, true) then
		return 120 - math.abs(#text - #query)
	end

	local distance = levenshtein(query, text)
	local maxLen = math.max(#query, #text)
	local distanceScore = math.max(0, 100 - ((distance / maxLen) * 100))

	return distanceScore + subsequenceScore(query, text)
end

function FuzzySearch.search(query, entries, limit)
	limit = limit or 20
	local results = {}
	local normalizedQuery = normalize(query)
	if normalizedQuery == "" then
		return {}
	end

	for _, entry in ipairs(entries) do
		local allText = table.concat({
			entry.title or "",
			entry.description or "",
			entry.kind or "",
			table.concat(entry.keywords or {}, " "),
		}, " ")

		local score = FuzzySearch.score(normalizedQuery, allText)
		if score > 25 then
			table.insert(results, {
				entry = entry,
				score = score,
			})
		end
	end

	table.sort(results, function(a, b)
		return a.score > b.score
	end)

	if #results > limit then
		for i = #results, limit + 1, -1 do
			table.remove(results, i)
		end
	end

	return results
end

return FuzzySearch
