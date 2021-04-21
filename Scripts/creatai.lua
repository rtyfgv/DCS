do
	gai = mist.getGroupData('AI')
	gai.groupName = 'AI' .. unitNum
	copy(myUnits["P-51D"], gai.units[1], unitKeys);
	gai.units[1]  = myUnits[plane]
	gai = mist.dynAdd(gai)
end
