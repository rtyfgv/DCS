--[[
Script: flakv3_2.lua
Author: Stonehouse of RAAF No457 vSQD
Date: 14/11/2014
Prerequisites: 
*Mistv3.3a or higher must be loaded prior to this script being used.
*The script must be loaded prior to any of the functions being run. ie ensure that Mist and this script is loaded before any flak is triggered
*Load on a MISSION START trigger using DO SCRIPT FILE 

Update log:
v0.3 - 	Initial release
v0.4 - 	Tweaks to skill based errors to better balance lethality of flak batteries.
v0.5 - 	Further tweaks to accuracy and rof, incorporated the old fill and attack functions from the vector flak version, renamed to flakv2_0.lua
v2.1 - 	Change to using spherical zones for tof flak and vecflak as the battery is assumed to be at the centre of the zone and using a cylinder as in earlier versions 
		meant attacks occurred on aircraft that are actually out of range. As the mist function getUnitsInZone takes land height into account for spherical zones
		it means that the radius of the zone becomes the max effective range for the battery and only min altitude needs to be checked. Additionally create a version of addtgt and vecflak that can be 
		associated with a moving battery to simulate naval AAA using mist function getUnitsInMovingZones. Correct Flak41 suggested rates of fire.
v3.0	Add proper rate of fire control and number of batteries/flak guns (which equates to number of targets 
		can be engaged at once). 
v3.1 	Tweaked explosion strength,rof and errors for skill
v3.2 	Add helicopters as possible flak targets
		
Overview:
Simulation of a 88mm flak 36/18 battery based on conversations between Stonehouse, Sithspawn and GGTharos in this thread http://forums.eagle.ru/showthread.php?t=121894
using time of flight of the shell and the known position and vector of a target aircraft to predict a future position at which to create a box of flak bursts as well as 
when it should happen. 

An average 88mm flak battery consists of 4 guns linked to a and fire control and analogue targeting data computer (TDC). This computer would track targets and provide elevation, range and bearing 
information to the individual guns corrected for their position relative to the TDC. The muzzle velocity of a Flak 88 was around 820 m/s and the rate of fire for a gun crew was between 15 and 25 rounds per minute
depending on the skill and experience of the crew. 6 batteries formed a flak regiment of 24 guns. The individual accuracy of a gun was very high if the TDC crew provided good firing solutions.
To keep things sensible I've made the vecflak and movvecflak functions simulate individual guns - I suggest these are used to simulate flak from maritime units or lightly defended zones. The minimum number of guns is 1 and the maximum is 24. 
Note that 24 flak guns is a flak regiment and anything more than 4-6 guns I suggest is better simulated by the addtgt and movaddtgt functions which simulate batteries of flak guns - groups of 4 guns.
I may reduce the upper limit of 24 to something much lower in future versions if it seems like the 24 guns setting is causing problems.
The addtgt and movaddtgt functions allow you to enter between 1 and 6 batteries. Each battery is 4 guns so again this works out to a single flak regiment. My intention being that a single trigger 
action supports at most a single flak regiment. My reasoning for this is that the skill level is applied at the function call and while I could see an entire green flak regiment being 'low' skill I don't believe it should 
cover more than that. 

This set of scripts assigns an average skill the level of the function call and applies to gun crews and TDC crew, the skill levels are high, med or low. So if I call the vecflak or movvecflak with 2 guns on a single trigger action 
then both guns will get the skill assigned in the function call. Likewise if I called the addtgt or movaddtgt functions with 3 batteries then all 3 batteries will get the same skill.

Some assumptions are made on accuracy based on this skill and these are presented by a random circle of error in altitude, north and east target position prediction. 
Similarly the rate of fire is affected by this skill and should approximate low skill crews achieving 15 rounds per minute (1 shot every 4 secs), medium skill crews 20 rounds per minute 
(1 shot every 3 secs) while a high skill crew will achieve approximately 25 rounds per minute (which I've taken as 1 shot every 2 secs). Note that I have introduced a slight randomness in this rate of 
fire at the individual gun or battery level which will randomly give a gun a slightly better or worse reload rate on the next shot. This stops a synchronised "wave" of flak bursts and instead you get slight variations
on each shot that you would expect in real crews.

Note the Flak41 model which was introduced in 1943 and served mostly in Germany had a muzzle velocity of 1000m/s, rof 20-25 rounds per minute
and an effective ceiling of 10675m (reference http://forum.armyairforces.com/88mm-Antiaircraft-guns-a-potent-weapon-against-USAAF-formations-m182739.aspx and
http://en.wikipedia.org/wiki/8.8_cm_Flak_18/36/37/41#Second_generation:_Flak_41) In order to simulate this weapon do the following:
* change _maxAlt to 10675
* change _muzvel to 1000
* change _shotRate to 3 for low skill, _lowShot to 0 and _hiShot to 1
* change _shotRate to 2 for med skill, _lowShot to -1 and _hiShot to 1
* change _shotRate to 2 for high skill, _lowShot to -1 and _hiShot to 0
* trigger zones should be 10675m radius.

Note The fill function is very closely based on the original script authored by SithSpawn with minor tweaks to 
add altitude and damage limits by Stonehouse and all credit and acknowledgment should be given to 
SithSpawn for this function which creates random flak bursts in a zone every second. 

The vecflak & movvecflak function is based on the idea of using the target's velocity vector to create a "tracking" algorithm 
to loosely simulate flak guns trying to track targets and calculate a lead firing solution for them and 
attempting to incorporate an average crew skill to control shot accuracy, spread and rate of fire

The addtgt & movaddtgt functions calculate a predicted target point for each engaged target and writes the co-ordinates and a time the burst should happen to a table. The flakmgr function reads this 
table and if a burst should be created at the current time it will create the explosions as a box of 4 around the target co-ordinates. The error governing the dispersion of this box is given
by the skill level of the batteries involved as is the rate of fire. The addtgt, movaddtgt and flak mgr form a system that creates and manages flak explosions over the entire map.

The addtgt and vecflak scripts require a trigger zone to be placed in the mission editor and the radius of the zone becomes the maximum effective range of the flak. Therefore for Flak 36s this
should be 8000m radius zones. These zones are now treated as spheres so that target slant range is correctly evaluated whereas earlier versions of the script used cylindrical zones and targets
were invalidly attacked at times.

Note that the script no longer scales the flak bursts for each target and each gun or battery will target a single aircraft. So if you said in an addtgt or movaddtgt there are 6 batteries 
then even if there are 10 targets only 6 will be attacked. Likewise the number of guns in the vecflak and movvecflak. 

Usage of time of flight based flak:
* Mission start trigger to load Mist and then this script using DO SCRIPT FILE, note Mist MUST BE LOADED BEFORE this script
* A continuously evaluated trigger with no conditions to run the flakmgr function. The flakmgr function is run with a DO SCRIPT and the entry DO flakmgr() END
* A continuously evaluated trigger with a condition that is true when a target exists in the trigger zone associated with this trigger 
  to run the addtgt function. Each zone can have one or more instances of addtgt where each instance simulates a number of flak batteries of a given skill defending the trigger zone
  depending on how heavily defended the area was. The flak generated is quite deadly so be careful how many batteries are attached to a single zone or exist in  
  overlapping zones. The addtgt function is run with a DO SCRIPT and the entry DO addtgt('side','zone','skill', number of batteries) END, where red or blue would substitute for 
  the word side, the name of the associated zone would substitute (exactly) for the word zone and high, med or low would substitute for the word skill and a integer between 1 and 6 substitutes for number of batteries.
  eg: DO addtgt('blue','redflak1','high',3) END  
* The trigger zone for the addtgt functions should be 8000m in radius as this was the effective range of a Flak36 or 10675 if using Flak41s.
* You can have as many trigger zones for areas defended by flak as you wish within the limits of what you judge is satisfactory performance for DCS World. 
* For the movaddtgt function you do roughly the same thing BUT you do not place a trigger zone and instead a unit name (not a group name) of a unit on the map is passed to the function so the trigger action 
  might look like DO movaddtgt('blue','Unit #01','high',2) This gives 2 BATTERIES of flak guns to Unit #01 allowing up to 2 targets to be engaged each cycle. The flak zone around the unit is a "virtual" one
  and has the radius of _maxAlt. Things like ships make good units for movaddtgt and you would want to add a condition of the unit being alive on the continuous trigger.
   
Usage of fill based flak:
Create a trigger zone with a unique name to represent the flak battery zone of fire and if desired create smaller zones 
within this main trigger zone over towns, airfields etc. so that you use the main trigger zone for the condition to control
the start of the flak bursts and the smaller zones to get the right volume of fire to suit how you want it to look.
Then for the trigger actions add a DO SCRIPT for each smaller zone that executes DO flak.fill('XXXX') END where XXXX 
is the name of the small trigger zone/s. While the flak generated by the fill function is deadly if it hits this function is largely 
meant to give the effect of a flak barrage without the danger. The larger the number of small zones the denser the flak "effect".

Usage of the vector based flak function:
Create a trigger zone with a unique name to represent the flak battery zone of fire
For trigger zone create a continuous trigger with at least a condition like "part of coalition red/blue in zone" 
and then for the trigger actions add a DO SCRIPT that executes DO vecflak('SSSS','YYYY','KKKK',n) END where SSSS is either red or 
blue according to which side is to be attacked by the flak, YYYY is the name of the main zone and KKKK is either low, med or high according to the skill of the flak and 
n is the number of guns between 1 and 24. Combining the fill and vecflak function gives the effect of a heavily defended target with lots of flak guns
as well as a dangerous flak attack that tracks individual targets, although generally speaking the time of flight based flak function is a better
representation of a flak defended area like a city or airfield. The vector based flak function may be more appropriate for representing a defense with
a small amount of heavy flak like a lightly defended area or maritime unit. 
For the movvecflak function there is no zone placed in the ME and instead of a zone name a unit name of a unit on the map is passed in. So in the above vecflak becomes movvecflak and YYYY becomes the unit name. 
So for example the trigger action might be DO movvecflak('blue','Unit #01','high',3) END.

Again just to reinforce that for both cases of the moving flak there is no need to create a moving or normal trigger zone in the ME as the Mist function getUnitsInMovingZones is based on finding the units in
an circular area centered on a moving unit given that the position of the moving unit and radius of the area are known. So to use these functions all that is needed is 
a moving (or static) unit (which was intended as a naval unit but might not be) which is going to be defended by flak and a continuously evaluated trigger which has a condition that the moving unit
is alive and then a trigger action of either DO SCRIPT DO movvecflak('ssss','uuuuuuuuu','kkkk',n) END or DO SCRIPT DO movaddtgt('ssss','uuuuuuuuu','kkkk',n) END,
where 'ssss' is either 'blue' or 'red', 'uuuuuuuuu' is the name of the moving unit as given in the ME and 'kkkk' is either 'high','med' or 'low' and n is an integer.


It should be possible to mix and match the various flak functions on the same zone as suits the mission being built. Ditto that you can mix and match different flak 
functions in the same mission to get what you want to see.

On the explosion strength I found a few unconfirmed sources on the net that gave an 88mm shell a lethal
radius of 30ft or about 10m. I tested using ramp parked AI aircraft and set explosions at 10m until I found a strength that made the pilot bailout. 
This was strength 9.  As the vector scripts are a single burst and wider errors I made them 1 point stronger
--]]
do
--global constants
--9 strength explosive to represent 9.4 kg for FLAK 88 for tof based flak
_tofDmg = 9
--10 strength explosive to represent 9.4 kg for FLAK 88 for fill & vector based flak
_vecfDmg = 10

--compared to _shotRate to decide whether a battery fires and thereby statistically achieve correct rate of fire
_hiDelay = 60
_minAlt = 250 --min altitude for valid heavy flak shot in meters??
_maxAlt = 8000 --max effective altitude range is 8000m
_muzvel = 820 --820m/s shell velocity 

--tables to contain flak burst info and timing
flakcoords = {} --predicted target position
flaktof = {} --predicted time of flight in whole seconds to reach target position.
flakskill = {} --battery skill to use for creating burst
flakrof = {} --battery/gun rate of fire info. This is used in conjunction with skill values to give appropriate rate of fire.

--debug stuff, set to false to stop displaying errors and comment/uncomment calls to debug function to stop debug

env.setErrorMessageBoxEnabled(false)

--[[
Name: flakmgr
Parameters: nil
Trigger: Continuous and under most circumstances without condition. ie it is designed to run every second.

Example of usage: 

Do
flakmgr()
End

--]]
 
 function flakmgr()
 
 --Debug("Debugmessage: #flakcoords = ".. #flakcoords)
 --Debug"Debugmessage: #flaktof = ".. #flaktof)
--if any entries exist in the table flak then process them

if (#flakcoords > 0) then

	for f=1,#flakcoords do

		local _tofsecs =  flaktof[f]

		if _tofsecs ~= nil then

			_tofsecs = _tofsecs - 1

			--Debug"Debugmessage: tofsecs = " .. _tofsecs)
 
			if _tofsecs <= 0 then

--time of flight has expired so create explosions
				local _tgtpos = flakcoords[f]
				local _skill = flakskill[f]

--set skill attributes 
				if _skill == 'low' then
					_altSprd = 60
					_NthErr = 60
					_EstErr = 60
					elseif _skill == 'med' then
						_altSprd = 50
						_NthErr = 50
						_EstErr = 50
						elseif _skill == 'high' then
							_altSprd = 40
							_NthErr = 40
							_EstErr = 40
				end
--Calc lower spread/accuracy value 

				_lowaltSprd = _altSprd * -1
				_lowNthErr = _NthErr * -1
				_lowEstErr = _EstErr * -1

--Calc positions of the 4 shots, based on skill values
				local v1 = {x=_tgtpos.x + mist.random(_lowNthErr,_NthErr), y=_tgtpos.y + mist.random(_lowaltSprd,_altSprd), z=_tgtpos.z+ mist.random(_lowEstErr,_EstErr)}
				local v2 = {x=_tgtpos.x + mist.random(_lowNthErr,_NthErr), y=_tgtpos.y + mist.random(_lowaltSprd,_altSprd), z=_tgtpos.z+ mist.random(_lowEstErr,_EstErr)}
				local v3 = {x=_tgtpos.x + mist.random(_lowNthErr,_NthErr), y=_tgtpos.y + mist.random(_lowaltSprd,_altSprd), z=_tgtpos.z+ mist.random(_lowEstErr,_EstErr)}
				local v4 = {x=_tgtpos.x + mist.random(_lowNthErr,_NthErr), y=_tgtpos.y + mist.random(_lowaltSprd,_altSprd), z=_tgtpos.z+ mist.random(_lowEstErr,_EstErr)}

--so trigger box of flak bursts within skill based errors of current position
				trigger.action.explosion(v1, mist.random(1,_tofDmg))
				trigger.action.explosion(v2, mist.random(1,_tofDmg))
				trigger.action.explosion(v3, mist.random(1,_tofDmg))
				trigger.action.explosion(v4, mist.random(1,_tofDmg))

--remove entry from tables for flak now shells exploded

				flakcoords[f] = nil
				flaktof[f] = nil
				flakskill[f] = nil

			else
--set new time of flight since the shells didn't arrive this time but are 1 second closer
				flaktof[f]=_tofsecs
			end --flight time reached check
		end --don't do nil entries
	end --process entries in table flak
end --entries exist in table flak

return flakcoords, flaktof, flakskill, flakrof
 
end --end function flakmgr

--[[
Name: addtgt
Parameters: 
_var1 = the side that should be attacked by the flak battery. Valid values are blue and red
_var2 = the name of the associated trigger zone being defended by the battery. Valid values are the name of the zone exactly as it appears in the ME
_var3 = the overall skill of the battery. This is a collective skill for the TDC and gun crews. Valid values are high, med and low.
_var7 = number of batteries between 1 and 6
Trigger: Continuous with a suitable condition that will evaluate to true when a target enters the trigger zone and should be engaged by the battery.

Example of usage: 

Do
addtgt('blue','redflak1','high',3)
End
--]]

function addtgt(_var1, _var2, _var3, _var7)

--parameters
local _side = _var1 -- eg 'blue'
local _aaaZone = _var2 --eg 'flak'
local _bttyskill = _var3 --eg 'high', 'med' or 'low'
local _numofbttys = _var7 -- integer value from 1 to n representing the number of flak batteries 
 
--if battery skill passed a bad value then default to med
if ((_bttyskill ~= 'low') and (_bttyskill ~= 'med') and (_bttyskill ~= 'high')) then
	_bttyskill = 'med'
end

--set number of batteries to 1 if less than zero passed in.
if ((_numofbttys < 1) or (_numofbttys == nil)) then _numofbttys = 1 end

--set number of batteries to 6 if more than 6 passed in. Forcing max of 1 flak regiment per trigger action
if _numofbttys > 6 then _numofbttys = 6 end

local _shotRate = 0
local _lowShot = 0
local _hiShot = 0

--set skill attributes, recalling that this script is attached to a continuous trigger so is executed every second  
if _bttyskill == 'low' then
	_shotRate = 4 --1 shot every 4 secs  
	_lowShot = 0 --won't be better than 1 shot per 4 secs
	_hiShot = 3 --might be as bad as 1 shot per 7 secs
	elseif _bttyskill == 'med' then
		_shotRate = 3 --1 shot every 3 secs 
		_lowShot = -1 --might be as good as 1 shot per 2 secs
		_hiShot = 2 --might be as bad as 1 shot per 5 secs
		elseif _bttyskill == 'high' then
			_shotRate = 2 --1 shot every 2 secs
			_lowShot = 0 --won't be better than 1 shot per 2 secs
			_hiShot = 2 --might be as bad as 1 shot per 4 secs
end


--init table
local sidePlanes = {}

--get units for side 
if _side == 'red' then 
	sidePlanes = mist.makeUnitTable({'[red][plane]','[red][helicopters]'}) --v3.2 add helos
	elseif _side == 'blue' then
		sidePlanes = mist.makeUnitTable({'[blue][plane]','[blue][helicopters]'}) --v3.2 add helos
end

--set up table entry for flak zone so it can be passed to getUnitsInZones
local _zone = {}
_zone[1] = _aaaZone
--get the units in the flak zone
local inZoneUnits = mist.getUnitsInZones(sidePlanes, _zone, 'sphere') 

if (#inZoneUnits > 0) then

	--Debug"Debugmessage: units in zone = ".. #inZoneUnits)
	
	for j = 1, _numofbttys do
	
		local _index = _aaaZone..j
		local _rof = flakrof[_index]
--check if reloaded	
		if _rof ~= nil then
			_rof = _rof - 1
		else
			_rof = 0 --initially loaded
		end
--decide whether to shoot or not  		
			if _rof <= 0 then
--get target aircraft
				local i = mist.random(1,#inZoneUnits)

--get current position and current velocity vector 
				local _targetpos = inZoneUnits[i]:getPosition().p
				local _targetvel = inZoneUnits[i]:getVelocity()

--get distance from flak to current target position and then calculate flight time of shells, flak battery is assumed to be at the zone centre
				local _zonectr=trigger.misc.getZone(_aaaZone)
				local _zonepos = {x=_zonectr.point.x, y=land.getHeight({x=_zonectr.point.x,y=_zonectr.point.z}), z=_zonectr.point.z}
				local _curpos = {x=_targetpos.x, y=_targetpos.y, z=_targetpos.z}
		
--only do MIST tableShow call if in debug
				-- local _message = mist.utils.tableShow(_zonepos)	
				--Debug("Debugmessage: _zonepos = ".. _message)
				--_message = mist.utils.tableShow(_curpos)	
				--Debug("Debugmessage: _curpos = ".. _message)

--get3DDist gives slant range in meters between 2 vec3 points
				local _range = mist.utils.get3DDist(_curpos, _zonepos)
				--Debug("Debugmessage: _range = ".. _range)
--flight time of shell is slant range divided by muzzle velocity in m/s. eg range 820, velocity 820 gives time of 1 sec for shell to arrive at the 
--predicted coordinates.
				local _fltTime = mist.utils.round(_range / _muzvel)
				--Debug("Debugmessage: _fltTime = ".. _fltTime)

--add target position and velocity vector times flight time (in seconds) to get forecast future position
				local _aaAlt = _targetpos.y + (_targetvel.y * _fltTime) 
				local _aaNth = _targetpos.x + (_targetvel.x * _fltTime)
				local _aaEst = _targetpos.z + (_targetvel.z * _fltTime)

--get land height at forecast position 
				local _landht = land.getHeight{x=_aaNth, y = _aaEst}

--adjust _aaAlt by land height to allow for flak on hills or in hollows
				local _aaAlt = _aaAlt - _landht 

				if _aaAlt >= _minAlt then 
--If above min height for flak and within zone (recalling that radius of zone = max effective flak range)
--then create flak table entries, remembering to add back the land height so the burst is at right altitude
					local vec3= {
								x=_aaNth,
								y=_aaAlt+_landht,
								z=_aaEst
								} 

--set up new table entries, first get the new index and then initialise the new entries. Then move the values into the entries.
					local _flakidx = #flakcoords + 1

					flakcoords[_flakidx] = {}
					flaktof[_flakidx] = {}
					flakskill[_flakidx] = {}
					flakcoords[_flakidx] = vec3
					flaktof[_flakidx] =_fltTime
					flakskill[_flakidx] = _bttyskill
					flakrof[_index] = _shotRate + mist.random(_lowShot,_hiShot) -- set reload time as btty has fired

				end --within flak height limits
			else
				flakrof[_index] = _rof --decrement secs until reloaded	
			end --decision to shoot
	end --process all batteries 
else
	for r=1,_numofbttys do
		flakrof[_aaaZone..r]=nil
	end
end --units exist in zone
 
 return flakcoords, flaktof, flakskill, flakrof
 
end --function addtgt

--[[
Name: fill
Parameters: 
_parm1 = the name of the associated trigger zone being defended by the battery. Valid values are the name of the zone exactly as it appears in the ME

Example of usage: 

Do
fill('redflak1')
End


--]]

function fill(_parm1)

local _zonename = _parm1
local pos = trigger.misc.getZone(_zonename) 
 
--get a random point in the zone 
local newpoint = mist.getRandPointInCircle(pos.point, pos.radius) 
 
--taking into account terrain height generate a vec3 position at the random point in the zone at a 
-- random altitude 
local vec3 = { 
x = newpoint.x, 
y = land.getHeight(newpoint) + mist.random(_minAlt, _maxAlt), 
z = newpoint.y 
} 

-- create a single flak explosion at the position 
trigger.action.explosion(vec3, _vecfDmg)
end

--[[
Name: vecflak
Parameters:
_parm2 = the side to be attacked by the flak. Valid values are red or blue 
_parm3 = the name of the associated trigger zone being defended by the battery. Valid values are the name of the zone exactly as it appears in the ME
_parm4 = the skill of the flak guns. Valid values are low, med or high. 
_parm8 = number of flak guns between 1 and 24

Example of usage: 

Do
vecflak('blue' 'redflak1' 'low', 8)
End


--]]

function vecflak(_parm2, _parm3, _parm4, _parm8)

--parameters 
local _side = _parm2 -- eg 'blue'
local _aaaZone = _parm3 -- eg 'flak'
local _bttyskill = _parm4 -- eg 'high'
local _numofguns = _parm8 -- eg integer value like 2 or 5

-- init table
local sidePlanes = {}

--declare skill variables
local _shotRate = 0
local _lowShot = 0
local _hiShot = 0
local _altSprd = 0
local _NthErr = 0
local _EstErr = 0
local _factor1 = 0
local _factor2 = 0

-- battery skill is optional parm and will default to med
if ((_bttyskill ~= 'low') and (_bttyskill ~= 'med') and (_bttyskill ~= 'high')) then
	_bttyskill = 'med'
end

--set number of guns to 1 if less than zero passed in.
if ((_numofguns < 1) or (_numofguns == nil)) then 
	_numofguns = 1 
	end

--set number of guns to 24 if more than 24 passed in. Forcing max of 1 flak regiment per trigger action
if _numofguns > 24 then 
	_numofguns = 24 
	end

-- set skill attributes, recall that this script is attached to a continuous trigger so is executed every second  
if _bttyskill == 'low' then
	_shotRate = 4 --1 shot every 4 secs 
	_lowShot = 0
	_hiShot = 3
	_altSprd = 125
	_NthErr = 100
	_EstErr = 100
	_factor1 = 1.5
	_factor2 = 3
	elseif _bttyskill == 'med' then
		_shotRate = 3 --1 shot every 3 secs per target
		_lowShot = -1
		_hiShot = 2
		_altSprd = 75
		_NthErr = 50
		_EstErr = 50
		_factor1 = 1.25
		_factor2 = 2
		elseif _bttyskill == 'high' then
			_shotRate = 2 --1 shot every 2 secs per target
			_lowShot = 0
			_hiShot = 2
			_altSprd = 60
			_NthErr = 35
			_EstErr = 35
			_factor1 = 1
			_factor2 = 1.5
end --skill setting

-- calc lower spread/accuracy value 
local _lowaltSprd = _altSprd * -1
local _lowNthErr = _NthErr * -1
local _lowEstErr = _EstErr * -1

-- get units for side 
if _side == 'red' then 
	sidePlanes = mist.makeUnitTable({'[red][plane]','[red][helicopters]'}) --v3.2 add helicopters
else
	sidePlanes = mist.makeUnitTable({'[blue][plane]','[blue][helicopters]'}) --v3.2 add helicopters
end --get side

-- set up table entry for flak zone
local _zone = {}
_zone[1] = _aaaZone

-- get the target units in the flak zone
local inZoneUnits = mist.getUnitsInZones(sidePlanes, _zone, 'sphere') 

-- for each target
if (#inZoneUnits > 0) then
	for v = 1, _numofguns do
	
	local _index = _aaaZone..v
	local _rof = flakrof[_index]
	
--check if reloaded	
	if _rof ~= nil then
		_rof = _rof - 1
	else
		_rof = 0 --initially loaded
	end
--decide whether to shoot or not  		
			if _rof <= 0 then
--get target aircraft
				local u = mist.random(1,#inZoneUnits)

-- get current position and velocity vector
				local _targetpos = inZoneUnits[u]:getPosition().p
				local _targetvel = inZoneUnits[u]:getVelocity()

-- get the land height at target position
				local _landht = land.getHeight{x = _targetpos.x, y = _targetpos.z}
-- get neg velocity vector components
				local _lowNthvel = _targetvel.x * -1
				local _lowEstvel = _targetvel.z * -1
				local _lowAltvel = _targetvel.y * -1

-- get target true altitude above ground level
				local _tgtAlt = _targetpos.y + _targetvel.y + math.random(_lowAltvel * _factor1, _targetvel.y * _factor2) - _landht + math.random(_lowaltSprd,_altSprd)
-- get north and east bearing of shot according to skill
				local _aaNth = _targetpos.x + math.random(_lowNthvel * _factor1,_targetvel.x * _factor2) + math.random(_lowNthErr,_NthErr)
				local _aaEst = _targetpos.z + math.random(_lowEstvel * _factor1,_targetvel.z * _factor2) + math.random(_lowEstErr,_EstErr)

-- If the target above min altitude limits of flak gun & within the zone (recalling that zone radius = max effective flak range)
				if _tgtAlt >= _minAlt then
-- get shot final 3D co-ords  
					local vec3= {
								x=_aaNth,
								y=_tgtAlt+_landht,
								z=_aaEst
								} 

-- explode the shell, strength of attack between 1 and max damage (throwing some luck into the mix)
					trigger.action.explosion(vec3, math.random(1,_vecDmg))
					flakrof[_index] = _shotRate + mist.random(_lowShot,_hiShot) -- set reload time as gun has fired
				end --min height
			else
				flakrof[_index] = _rof --decrement secs until reloaded				
			end --decide to shoot
		end --for loop 
else
	for b=1,_numofguns do
		flakrof[_aaaZone..b]=nil
	end	
end --units in zone
return flakrof
end --vecflak

--[[
Name: movaddtgt
Parameters:
_var4 = the side to be attacked by the flak. Valid values are red or blue 
_var5 = the name of the associated moving unit with flak. Valid values are the name of the unit exactly as it appears in the ME
_var6 = the skill of the flak battery. Valid values are low, med or high. 
_var8 = number of batteries between 1 and 6

Example of usage: 

Do
movaddtgt('blue','Unit #01','low',4)
End


--]]
function movaddtgt(_var4, _var5, _var6, _var8)

--parameters
local _side = _var4 -- eg 'blue'
local _aaaUnit = _var5 --eg 'Unit #01'
local _unitskill = _var6 --eg 'high', 'med' or 'low'
local _numofbttys = _var8 --eg integer 1 or 6 etc
  
--Debug("Debugmessage: AA unit = ".. _aaaUnit)
--Debug("Debugmessage: num of bttys = ".._numofbttys)

--if unit skill passed a bad value then default to med
if ((_unitskill ~= 'low') and (_unitskill ~= 'med') and (_unitskill ~= 'high')) then
	_unitskill = 'med'
end

--set number of batteries to 1 if less than zero passed in.
if ((_numofbttys < 1) or (_numofbttys == nil)) then _numofbttys = 1 end

--set number of batteries to 6 if more than 6 passed in. Forcing max of 1 flak regiment per trigger action
if _numofbttys > 6 then _numofbttys = 6 end
 
local _shotRate = 0
local _lowShot = 0
local _hiShot = 0

--set skill attributes, recalling that this script is attached to a continuous trigger so is executed every second  
if _unitskill == 'low' then
	_shotRate = 4 --1 shot every 4 secs
	_lowShot = 0 --won't be better than 1 shot per 4 secs
	_hiShot = 3 --might be as bad as 1 shot per 7 secs
	elseif _unitskill == 'med' then
		_shotRate = 3 --1 shot every 3 secs
		_lowShot = -1 --might be as good as 1 shot per 2 secs
		_hiShot = 2 --might be as bad as 1 shot per 5 secs
		elseif _unitskill == 'high' then
			_shotRate = 2 --1 shot every 2 secs
			_lowShot = 0 --no better than 1 shot per 2 secs
			_hiShot = 2 --might be as bad as 1 shot per 4 secs
end --set skill


--init table
local sidePlanes = {}

--get units for side 
if _side == 'red' then 
	sidePlanes = mist.makeUnitTable({'[red][plane]','[red][helicopters]'}) --v3.2 add helicopters
	elseif _side == 'blue' then
		sidePlanes = mist.makeUnitTable({'[blue][plane]','[blue][helicopters]'}) --v3.2 add helicopters
end --get side

--set up table entry for flak zone so it can be passed to getUnitsInMovingZones
local _AAunits = {}
_AAunits[1] = _aaaUnit
--get the units in the moving flak zone
local inZoneUnits = mist.getUnitsInMovingZones(sidePlanes, _AAunits, _maxAlt, 'sphere') 

if (#inZoneUnits > 0) then

	--Debug("Debugmessage: units in zone = ".. #inZoneUnits)

	for s = 1, _numofbttys do
	
		local _index = _aaaUnit..s
		local _rof = flakrof[_index]
--check if reloaded	
		if _rof ~= nil then
			_rof = _rof - 1
		else
			_rof = 0 --initially loaded
		end
--decide whether to shoot or not  		
		if _rof <= 0 then
--get target aircraft
			local e = mist.random(1,#inZoneUnits)

--get current position and current velocity vector 
			local _targetpos = inZoneUnits[e]:getPosition().p
			local _targetvel = inZoneUnits[e]:getVelocity()
			local _aaUnitpos = Unit.getByName(_aaaUnit):getPosition().p 
 

--get distance from flak to current target position and then calculate flight time of shells 
		
			local _flakpos = {x=_aaUnitpos.x, y=_aaUnitpos.y, z=_aaUnitpos.z}
			local _curpos = {x=_targetpos.x, y=_targetpos.y, z=_targetpos.z}
		
--only do MIST tableShow call if in debug
			--local _message = mist.utils.tableShow(_flakpos)	
			--Debug("Debugmessage: _zonepos = ".. _message)
			--_message = mist.utils.tableShow(_curpos)	
			--Debug("Debugmessage: _curpos = ".. _message)

--get3DDist gives slant range in meters between 2 vec3 points
			local _range = mist.utils.get3DDist(_curpos, _flakpos)
			--Debug("Debugmessage: _range = ".. _range)
--flight time of shell is slant range divided by muzzle velocity in m/s. eg range 820, velocity 820 gives time of 1 sec for shell to arrive at the 
--predicted coordinates.
			local _fltTime = mist.utils.round(_range / _muzvel)
			--Debug("Debugmessage: _fltTime = ".. _fltTime)

--add target position and velocity vector times flight time (in seconds) to get forecast future position
			local _aaAlt = _targetpos.y + (_targetvel.y * _fltTime) 
			local _aaNth = _targetpos.x + (_targetvel.x * _fltTime)
			local _aaEst = _targetpos.z + (_targetvel.z * _fltTime)

--get land height at forecast position 
			local _landht = land.getHeight{x=_aaNth, y = _aaEst}

--adjust _aaAlt by land height to allow for flak on hills or in hollows
			local _aaAlt = _aaAlt - _landht 

			if _aaAlt >= _minAlt then 
--If above min height for flak and within zone (recalling that radius of zone = max effective flak range)
--then create flak table entries, remembering to add back the land height so the burst is at right altitude
				local vec3= {
							x=_aaNth,
							y=_aaAlt+_landht,
							z=_aaEst
							} 

--set up new table entries, first get the new index and then initialise the new entries. Then move the values into the entries.
				local _flakidx = #flakcoords + 1

				flakcoords[_flakidx] = {}
				flaktof[_flakidx] = {}
				flakskill[_flakidx] = {}
				flakrof[_index]={}
				flakcoords[_flakidx] = vec3
				flaktof[_flakidx] =_fltTime
				flakskill[_flakidx] = _bttyskill
				flakrof[_index] = _shotRate + mist.random(_lowShot,_hiShot) -- set reload time as btty has fired

			end --within flak height limits
		else
			flakrof[_index] = _rof --decrement secs until reloaded
		end --decision to shoot
	end --for loop
else
	for q=1,_numofbttys do
		flakrof[_aaaUnit..q]=nil
	end
end --units exist in zone
 
 return flakcoords, flaktof, flakskill, flakrof
 
end --function movaddtgt

--[[
Name: movvecflak
Parameters:
_parm5 = the side to be attacked by the flak. Valid values are red or blue 
_parm6 = the name of the associated moving unit being defended by the battery. Valid values are the name of the unit exactly as it appears in the ME
_parm7 = the skill of the flak guns. Valid values are low, med or high. 
_parm9 = number of flak guns between 1 and 24

Example of usage: 

Do
movvecflak('blue','Unit #01','low',2)
End


--]]
function movvecflak(_parm5, _parm6, _parm7, _parm9)

--parameters 
local _side = _parm5 -- eg 'blue'
local _aaaUnit = _parm6 -- eg 'Unit #01'
local _unitskill = _parm7 -- eg 'med'
local _numofguns = _parm9 -- eg integer value like 2 or 3

-- init table
local sidePlanes = {}

-- unit skill is optional parm and will default to med
if ((_unitskill ~= 'low') and (_unitskill ~= 'med') and (_unitskill ~= 'high')) then
	_unitskill = 'med'
end

--declare skill variables
local _shotRate = 0
local _lowShot = 0
local _hiShot = 0
local _altSprd = 0
local _NthErr = 0
local _EstErr = 0
local _factor1 = 0
local _factor2 = 0

--set number of guns to 1 if less than zero passed in.
if ((_numofguns < 1) or (_numofguns == nil)) then 
	_numofguns = 1 
	end

--set number of guns to 24 if more than 24 passed in. Forcing max of 1 flak regiment per trigger action
if _numofguns > 24 then 
	_numofguns = 24 
	end
	
-- set skill attributes, recall that this script is attached to a continuous trigger so is executed every second  
if _unitskill == 'low' then
	_shotRate = 4 --1 shot every 4 secs 
	_lowShot = 0
	_hiShot = 3
	_altSprd = 125
	_NthErr = 100
	_EstErr = 100
	_factor1 = 1.5
	_factor2 = 3
	elseif _unitskill == 'med' then
		_shotRate = 3 --1 shot every 3 secs
		_lowShot = -1
		_hiShot = 2		
		_altSprd = 75
		_NthErr = 50
		_EstErr = 50
		_factor1 = 1.25
		_factor2 = 2
		elseif _unitskill == 'high' then
			_shotRate = 2 --1 shot every 2 secs
			_lowShot = 0
			_hiShot = 2
			_altSprd = 60
			_NthErr = 35
			_EstErr = 35
			_factor1 = 1
			_factor2 = 1.5
end --unitskill

-- calc lower spread/accuracy value 
local _lowaltSprd = _altSprd * -1
local _lowNthErr = _NthErr * -1
local _lowEstErr = _EstErr * -1

-- get units for side 
if _side == 'red' then 
	sidePlanes = mist.makeUnitTable({'[red][plane]','[red][helicopters]'}) --v3.2 add helicopters
else
	sidePlanes = mist.makeUnitTable({'[blue][plane]','[blue][helicopters]'}) --v3.2 add helicopters
end --get side

-- set up table entry for flak zone
local _AAunits = {}
_AAunits[1] = _aaaUnit

-- get the target units in the flak zone
local inZoneUnits = mist.getUnitsInMovingZones(sidePlanes, _AAunits, _maxAlt, 'sphere') 

-- for each target
if (#inZoneUnits > 0) then
	for x = 1, _numofguns do
	 
		local _index = _aaaUnit..x
		local _rof = flakrof[_index]
	
--check if reloaded	
		if _rof ~= nil then
			_rof = _rof - 1
		else
			_rof = 0 --initially loaded
		end
--decide whether to shoot or not  		
		if _rof <= 0 then
--get target aircraft
			local c = mist.random(1,#inZoneUnits)
-- get current position and velocity vector
			local _targetpos = inZoneUnits[c]:getPosition().p
			local _targetvel = inZoneUnits[c]:getVelocity()
 

-- get the land height at target position
			local _landht = land.getHeight{x = _targetpos.x, y = _targetpos.z}
-- get neg velocity vector components
			local _lowNthvel = _targetvel.x * -1
			local _lowEstvel = _targetvel.z * -1
			local _lowAltvel = _targetvel.y * -1

-- get target true altitude above ground level
			local _tgtAlt = _targetpos.y + _targetvel.y + math.random(_lowAltvel * _factor1, _targetvel.y * _factor2) - _landht + math.random(_lowaltSprd,_altSprd)
-- get north and east bearing of shot according to skill
			local _aaNth = _targetpos.x + math.random(_lowNthvel * _factor1,_targetvel.x * _factor2) + math.random(_lowNthErr,_NthErr)
			local _aaEst = _targetpos.z + math.random(_lowEstvel * _factor1,_targetvel.z * _factor2) + math.random(_lowEstErr,_EstErr)

-- If the target above min altitude limits of flak gun & within the moving zone (recalling that zone radius = _range)
			if _tgtAlt >= _minAlt then
-- get shot final 3D co-ords  
				local vec3= {
				x=_aaNth,
				y=_tgtAlt+_landht,
				z=_aaEst
							} 

-- explode the shell, strength of attack between 1 and max damage (throwing some luck into the mix)
				trigger.action.explosion(vec3, math.random(1,_vecDmg))
				flakrof[_index] = _shotRate + mist.random(_lowShot,_hiShot) -- set reload time as gun has fired
			end --above min height
		else
			flakrof[_index] = _rof --decrement secs until reloaded			
		end --decide to shoot
	end --for loop
else
	for h=1,_numofguns do
		flakrof[_aaaUnit..h]=nil
	end		
end --units exist in zone
end --movvecflak

--[[
Name: Debug
Parameters: 
content = a string containing a debug message
 
Example of usage: 

Debug("Debugmessage: _range = ".. _range)

displays a debug message like "_range = 8000" on screen and in dcs.log
--]]

function Debug(content) 
	
	local message = content

	trigger.action.outText(message, 60000000)
	env.info(message)

end

end --script