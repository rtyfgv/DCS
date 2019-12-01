do
function dropbombs (_unitname, _bombsnumber, _size, _timing, _skill)
	local _bombsnum = 10
	local _bombsize = 1000
	local _ripple = 0.25
	local _lowskill = -150
	local _highskill = 150
	
	if _skill == 'low' then
		_highskill = 300
		_lowskill = -300
	end
	
	if _skill == 'med' then
		_highskill = 150
		_lowskill = -150
	end
	
	if _skill == 'high' then
		_highskill = 75
		_lowskill = -75
	end
	
	if _bombsnumber ~= nil and _bombsnumber > 1 then
		_bombsnum = _bombsnumber
	end
	
	if _size ~= nil and _size > 0 and _size <= 9999 then
		_bombsize = _size
	end
	
	if _timing ~= nil and _timing >= 0.01 and _timing <= 2 then
		_ripple = _timing
	end	
	
	function drop (_unitname)
		local _dropdirect = {x = 0, y = -1, z = 0}
		local _unitposn = Unit.getByName(_unitname):getPosition().p
		local _unitposn = {x=_unitposn.x + mist.random(_lowskill,_highskill), y=_unitposn.y, z = _unitposn.z + mist.random(_lowskill,_highskill)}
		local _explcord = land.getIP(_unitposn, _dropdirect, 8000)
		trigger.action.explosion(_explcord, _bombsize)
		_bombsnum = _bombsnum - 1
			if _bombsnum > 0 then
			local _timefornext = timer.getTime() + _ripple
			timer.scheduleFunction(drop, _unitname, _timefornext)
			end
		end
	drop (_unitname)
end
end