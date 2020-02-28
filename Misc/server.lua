if sb == nil then
	sb = {};
	sb.debug = true
	sb.time  = 0

	sb.net = {}

	local function renameName (data)
		data.alias = data.name
		data.name  = nil
		return data
	end

	local function testServer(id)
		if true then return false end
		if id == net.get_server_id() then 
			return true 
		end
		return false
	end

	function sb.net.log (msg, debug)
		if debug == nil then
			if sb.debug == true then
				net.log (msg)
			end
		elseif debug == true then
			net.log (msg)
		end
	end

	function sb.net.sendData(data)
		sb.net.log ('sendData - > ' .. sb.net.ip .. ':' .. sb.net.port)
		local succ, err = sb.net.udp:sendto(data, sb.net.ip, sb.net.port)
		if succ == nil then
			sb.net.log('sendData -> ' .. tostring(err));
		end
	end

	function sb.net.sendJSON(data)
		sb.net.log('sendJSON -> ' .. net.lua2json(data))
		sb.net.sendData(net.lua2json(data));
	end

	function sb.net.getTimeStamp ()
		return {
			os    = os.date("%Y-%m-%d %X",os.time()),
			real  = DCS.getRealTime(),
			model = DCS.getModelTime()}
	end

	function sb.net.getServerStamp()
		return {
			ucid  = "00000000000000000000000000000000",
			alias = 'SERVER' }
	end

	function sb.net.sendMsg(msg)
		msg.timeS = sb.net.getTimeStamp()
		sb.net.sendJSON(msg)
	end

	do
		local err;

		package.path    = package.path..';.\\LuaSocket\\?.lua'
		package.cpath   = package.cpath..';.\\LuaSocket\\?.dll'
		sb.net.socket   = require('socket')
		sb.net.host     = '127.0.0.1';
		sb.net.port     = '57001';

		sb.net.ip, err  = sb.net.socket.dns.toip(sb.net.host)
		sb.net.udp, err = sb.net.socket.udp();
		if sb.net.udp == nil then
			sb.net.log(tostring(err));
		end;
	end
	sb.net.log('net set')

	sb.callbacks = {};

	function sb.callbacks.onMissionLoadEnd()
		local data = sb.net.getServerStamp()
		data.mname = DCS.getMissionName()
		data.fname = DCS.getMissionFilename()
		sb.net.sendMsg({
			type = 'missionloaded',
			data = data })
	end

	function sb.callbacks.onPlayerConnect(id)
--		Prevent Server from being resgistered into utmp and wtmp database
		if testServer(id) then return end

		local data = net.get_player_info(id)
		if data == nil then return end

		data = renameName(data)
		data.id    = id;

		sb.net.sendMsg({
			type = 'login',
			data = data})
	end

	function sb.callbacks.onPlayerDisconnect(id, err_code)
--		Prevent Server from being resgistered into utmp and wtmp database
		if testServer(id) then return end

		sb.net.sendMsg({
			type = 'logout',
			data = { 
				id    = id }})
	end

	function sb.callbacks.onSimulationFrame()
		local now  = DCS.getRealTime()
		if (now-sb.time) < 60 then return end
		sb.time = now

		sb.net.sendMsg({
			type = 'frame',
			data = sb.net.getServerStamp()})
	end

	function sb.callbacks.onSimulationStart()
		sb.net.sendMsg({
			type = 'start',
			data = sb.net.getServerStamp()})
	end

	function sb.callbacks.onSimulationStop()
		sb.net.sendMsg({
			type = 'stop',
			data = sb.net.getServerStamp()})
	end

	function sb.callbacks.onGameEvent(eventName, playerID, arg2, arg3, arg4, arg5, arg6, arg7)
		local calls = {};
		local function onGameStub (eventName, playerID, arg2, arg3, arg4, arg5, arg6, arg7)
			sb.net.log('onGameStub -> ' .. eventName)
		end

		sb.net.log('onGameEvent -> ' .. eventName .. ' : ' ..
			net.lua2json ( {
				playerID = playerID,
				arg2     = arg2,
				arg3     = arg3,
				arg4     = arg4,
				arg5     = arg5,
				arg6     = arg6,
				arg7     = arg7 }), true)

		calls.change_slot   = sb.change_slot
		calls.connect       = onGameStub
		calls.crash         = sb.crash
		calls.disconnect    = onGameStub
		calls.eject         = sb.eject
		calls.friendly_fire = onGameStub
		calls.kill          = sb.kill
		calls.landing       = sb.landing
		calls.mission_end   = onGameStub
		calls.pilot_death   = sb.pilot_death
		calls.self_kill     = sb.self_kill
		calls.takeoff       = sb.takeoff

		local call = calls[eventName]
		if call == nil then
			sb.net.log('onGameEvent -> Event not registered : ' .. eventName)
		else
			if not testServer(playerID) then
				call(eventName, playerID, arg2, arg3, arg4, arg5, arg6, arg7)
			end
		end
  	
	end

	DCS.setUserCallbacks(sb.callbacks)
	net.log('callbacks set')

	function sb.change_slot (eventName, playerID, slotID, prevSide)
		local data = net.get_player_info(playerID)
		data = renameName(data);
		data.prevSide = prevSide

		sb.net.sendMsg({
			type = eventName, 
			data = data })
	end 

	function sb.crash (eventName, playerID, unit_missionID)
		sb.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'),
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID }})
	end

	function sb.disconnect (eventName, playerID, name, playerSide, reason_code)
		local data = {}

		sb.net.sendMsg({
			type = eventName, 
			data = { 
				id    = playerID,
				alias = name,
				side  = playerSide,
				err   = reason_code}})
	end

	function sb.friendly_fire (eventName, playerID, weaponName, victimPlayerID)
		sb.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'),
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID }})
	end

	function sb.eject (eventName, playerID, unit_missionID)
		sb.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'),
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID }})
	end

	function sb.kill (eventName, killerPlayerID, killerUnitType, killerSide, victimPlayerID, victimUnitType, victimSide, weaponName)
		local kdata = net.get_player_info(killerPlayerID)
		local vdata = net.get_player_info(victimPlayerID)

		if kdata == nil then
			kdata = {}
			kdata.ucid = "00000000000000000000000000000000"
			kdata.name = "AI"
		end

		if vdata == nil then
			vdata = {}
			vdata.ucid = "00000000000000000000000000000000"
			vdata.name = "AI"
		end

		sb.net.sendMsg({
			type = eventName, 
			data = { 
				kucid  = kdata.ucid,
				kalias = kdata.name,
				kutype = killerUnitType,
				kside  = killerSide,

				vucid  = vdata.ucid,
				valias = vdata.name,
				vutype = victimUnitType,
				vside  = victimSide,

				wname  = weaponName }})
	end

	function sb.landing (eventName, playerID, unit_missionID, airdromeName)
		sb.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'), 
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID,
				airdromeName   = airdromeName }})
	end

	function sb.pilot_death (eventName, playerID, unit_missionID)
		sb.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'), 
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID }})
	end

	function sb.self_kill (eventName, playerID)
		sb.net.sendMsg({
			type = eventName, 
			data = {
				ucid           = net.get_player_info(playerID, 'ucid'),
				alias          = net.get_player_info(playerID, 'name') }})
	end

	function sb.takeoff (eventName, playerID, unit_missionID, airdromeName)
		sb.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'), 
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID,
				airdromeName   = airdromeName }})
	end

	do
		sb.net.sendMsg ({
			type = 'ready',
			data = sb.net.getServerStamp() });
		
	end

	net.log('SBGameGUI.lua loaded.')
end
