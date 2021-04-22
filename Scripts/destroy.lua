do
	gai = ais[destroyAI]
	ais[destroyAI]= ais.nextAI
	ais.nextAI = destroyAI
	gai = Group.getByName(gai) 
	trigger.action.deactivateGroup(gai)
end
