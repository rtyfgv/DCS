do
	local msg = {} 
	if ais.nextAI < 5 then
		gai = mist.getGroupData('AI')
		gai.groupName = 'GAI' .. ais.nextAI
		local plane = planes[planeID]
		msg.text = gai.groupName .. ' -> ' .. plane
		copy(aiPlanes[plane], gai.units[1], unitKeys);
		gai.units[1]  = aiPlanes[plane]
		unitName = 'AI' .. ais.nextAI
		gai.units[1].unitName = unitName
		gai = mist.dynAdd(gai)

		nextAI = ais[ais.nextAI]
		ais[ais.nextAI] = unitName
		ais.nextAI = nextAI
		missionCommands.addCommandForCoalition(coalition.side.BLUE, unitName, destroyMenu, destroyCallback, 1) 
		trigger.action.setUserFlag('1', 0)
	end 
--	msg.displayTime = 25  
--	msg.msgFor = {coa = {'all'}} 
--	mist.message.add(msg)
end
