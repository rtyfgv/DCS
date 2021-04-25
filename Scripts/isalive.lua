do
	for i=1,4 do
		if type(ais[i]) ~= 'number' then
			if not Object.isExist(ais[i]) then
				return true
			end
		end
	end 
	return false
end
