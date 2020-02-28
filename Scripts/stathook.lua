--                                                                            --
-- Author(s):                                                                 --
--   RTyfgv
--                                                                            --
-- Copyright (C) 2015                                                         --
--    RTyfgv
--                                                                            --
-- This source file may be used and distributed without restriction provided  --
-- that this copyright statement is not removed from the file and that any    --
-- derivative work contains  the original copyright notice and the associated --
-- disclaimer.                                                                --
--                                                                            --
-- This source file is free software; you can redistribute it and/or modify   --
-- it under the terms of the GNU General Public License as published by the   --
-- Free Software Foundation, either version 3 of the License, or (at your     --
-- option) any later version.                                                 --
--                                                                            --
-- This source is distributed in the hope that it will be useful, but WITHOUT --
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or      --
-- FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for   --
-- more details at http://www.gnu.org/licenses/.                              --
--                                                                            --


if stathook == nil then
	net.log('stathook.lua loading.')
	stathook = {};
	stathook.debug = true
	stathook.time  = 0

	stathook.net = {}

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

	function stathook.net.log (msg, debug)
		if debug == nil then
			if stathook.debug == true then
				net.log (msg)
			end
		elseif debug == true then
			net.log (msg)
		end
	end

	function stathook.net.sendData(data)
		stathook.net.log ('sendData - > ' .. stathook.net.ip .. ':' .. stathook.net.port)
		local succ, err = stathook.net.udp:sendto(data, stathook.net.ip, stathook.net.port)
		if succ == nil then
			stathook.net.log('sendData -> ' .. tostring(err));
		end
	end

	function stathook.net.sendJSON(data)
		stathook.net.log('sendJSON -> ' .. net.lua2json(data))
		stathook.net.sendData(net.lua2json(data));
	end

	function stathook.net.getTimeStamp ()
		return {
			os    = os.date("%Y-%m-%d %X",os.time()),
			real  = DCS.getRealTime(),
			model = DCS.getModelTime()}
	end

	function stathook.net.getServerStamp()
		return {
			ucid  = "00000000000000000000000000000000",
			alias = 'SERVER' }
	end

	function stathook.net.sendMsg(msg)
		msg.timeS = stathook.net.getTimeStamp()
		stathook.net.sendJSON(msg)
	end

	do
		local err;

		package.path    = package.path..';.\\LuaSocket\\?.lua'
		package.cpath   = package.cpath..';.\\LuaSocket\\?.dll'
		stathook.net.socket   = require('socket')
		stathook.net.host     = 'dcs-server';
		stathook.net.port     = '57001';

		stathook.net.ip, err  = stathook.net.socket.dns.toip(stathook.net.host)
		stathook.net.udp, err = stathook.net.socket.udp();
		if stathook.net.udp == nil then
			stathook.net.log(tostring(err));
		end;
	end
	stathook.net.log('net set')

	stathook.callbacks = {};

	function stathook.callbacks.onMissionLoadEnd()
		local data = stathook.net.getServerStamp()
		data.mname = DCS.getMissionName()
		data.fname = DCS.getMissionFilename()
		stathook.net.sendMsg({
			type = 'missionloaded',
			data = data })
	end

	function stathook.callbacks.onPlayerConnect(id)
--		Prevent Server from being resgistered into utmp and wtmp database
--		if testServer(id) then return end

		local data = net.get_player_info(id)
		if data == nil then return end

		data = renameName(data)
		data.id    = id;

		stathook.net.sendMsg({
			type = 'login',
			data = data})
	end

	function stathook.callbacks.onPlayerDisconnect(id, err_code)
--		Prevent Server from being resgistered into utmp and wtmp database
--		if testServer(id) then return end

		stathook.net.sendMsg({
			type = 'logout',
			data = { 
				id    = id }})
	end

	function stathook.callbacks.onSimulationFrame()
		local now  = DCS.getRealTime()
		if (now-stathook.time) < 60 then return end
		stathook.time = now

		stathook.net.sendMsg({
			type = 'frame',
			data = stathook.net.getServerStamp()})
	end

	function stathook.callbacks.onSimulationStart()
		stathook.net.sendMsg({
			type = 'start',
			data = stathook.net.getServerStamp()})
	end

	function stathook.callbacks.onSimulationStop()
		stathook.net.sendMsg({
			type = 'stop',
			data = stathook.net.getServerStamp()})
	end

	function stathook.callbacks.onGameEvent(eventName, playerID, arg2, arg3, arg4, arg5, arg6, arg7)
		local calls = {};
		local function onGameStub (eventName, playerID, arg2, arg3, arg4, arg5, arg6, arg7)
			stathook.net.log('onGameStub -> ' .. eventName)
		end

		stathook.net.log('onGameEvent -> ' .. eventName .. ' : ' ..
			net.lua2json ( {
				playerID = playerID,
				arg2     = arg2,
				arg3     = arg3,
				arg4     = arg4,
				arg5     = arg5,
				arg6     = arg6,
				arg7     = arg7 }), true)

		calls.change_slot   = stathook.change_slot
		calls.connect       = onGameStub
		calls.crash         = stathook.crash
		calls.disconnect    = onGameStub
		calls.eject         = stathook.eject
		calls.friendly_fire = onGameStub
		calls.kill          = stathook.kill
		calls.landing       = stathook.landing
		calls.mission_end   = onGameStub
		calls.pilot_death   = stathook.pilot_death
		calls.self_kill     = stathook.self_kill
		calls.takeoff       = stathook.takeoff

		local call = calls[eventName]
		if call == nil then
			stathook.net.log('onGameEvent -> Event not registered : ' .. eventName)
		else
			if not testServer(playerID) then
				call(eventName, playerID, arg2, arg3, arg4, arg5, arg6, arg7)
			end
		end
  	
	end

	DCS.setUserCallbacks(stathook.callbacks)
	net.log('callbacks set')

	function stathook.change_slot (eventName, playerID, slotID, prevSide)
		local data = net.get_player_info(playerID)
		data = renameName(data);
		data.prevSide = prevSide

		stathook.net.sendMsg({
			type = eventName, 
			data = data })
	end 

	function stathook.crash (eventName, playerID, unit_missionID)
		stathook.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'),
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID }})
	end

	function stathook.disconnect (eventName, playerID, name, playerSide, reason_code)
		local data = {}

		stathook.net.sendMsg({
			type = eventName, 
			data = { 
				id    = playerID,
				alias = name,
				side  = playerSide,
				err   = reason_code}})
	end

	function stathook.friendly_fire (eventName, playerID, weaponName, victimPlayerID)
		stathook.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'),
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID }})
	end

	function stathook.eject (eventName, playerID, unit_missionID)
		stathook.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'),
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID }})
	end

	function stathook.kill (eventName, killerPlayerID, killerUnitType, killerSide, victimPlayerID, victimUnitType, victimSide, weaponName)
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

		stathook.net.sendMsg({
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

	function stathook.landing (eventName, playerID, unit_missionID, airdromeName)
		stathook.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'), 
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID,
				airdromeName   = airdromeName }})
	end

	function stathook.pilot_death (eventName, playerID, unit_missionID)
		stathook.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'), 
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID }})
	end

	function stathook.self_kill (eventName, playerID)
		stathook.net.sendMsg({
			type = eventName, 
			data = {
				ucid           = net.get_player_info(playerID, 'ucid'),
				alias          = net.get_player_info(playerID, 'name') }})
	end

	function stathook.takeoff (eventName, playerID, unit_missionID, airdromeName)
		stathook.net.sendMsg({
			type = eventName, 
			data = { 
				ucid           = net.get_player_info(playerID, 'ucid'), 
				alias          = net.get_player_info(playerID, 'name'),
				unit_missionID = unit_missionID,
				airdromeName   = airdromeName }})
	end


	do
		stathook.net.sendMsg ({
			type = 'ready',
			data = stathook.net.getServerStamp() });
		
	end

	net.log('stathook.lua loaded.')
end
