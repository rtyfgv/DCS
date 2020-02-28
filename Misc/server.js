const EventEmitter = require('events');
const dgram        = require('dgram');
const fs           = require('fs');
const exec         = require('child_process').exec;

var logFile = fs.createWriteStream(
	'debug.log',
	{flags : 'w'});
var log = console.log;

console.log = function(s) {
	const debug = true;

	if (debug) {
		logFile.write(s + '\n');
		log(s);
	}
};

//  //  //  //  //  //  //  //  //
//
// sb.json content file example 
//
// {	
// 	"db" : { 
// 		"host"     : "127.0.0.1",
// 		"user"     : "dcs",
// 		"password" : "dcs",
// 		"database" : "sb" },
// 	"dcs" : {
// 		"ip"   : "127.0.0.1",
// 		"port" : 57001 },
// 	"lapse" : 6
// }
//
//  //  //  //  //  //  //  //  //

const config = JSON.parse(fs.readFileSync('sb.json', 'utf8'));

var mysql;
if (typeof config.db != 'undefined') {
	mysql = require('mysql');
} else {
	mysql = {
		createConnection : function() {
		return {
			query   : function() { },
			on      : function() { },
			connect : function() { },
			end     : function() { } };
		}
	};
}

const airdrome = {
   	addEvent  : fs.readFileSync('airdrome/addevent.sql', 'utf8') };

const kill = {
   	addEvent  : fs.readFileSync('kill/addevent.sql', 'utf8') };

const users = {
	update    : fs.readFileSync('users/update.sql', 'utf8'),
   	signup    : fs.readFileSync('users/signup.sql', 'utf8') };

const utmp = {
   	empty     : fs.readFileSync('utmp/empty.sql',  'utf8'),
   	login     : fs.readFileSync('utmp/login.sql',  'utf8'),
	logout    : fs.readFileSync('utmp/logout.sql', 'utf8'),
	update    : fs.readFileSync('utmp/update.sql', 'utf8'),
	updateall : fs.readFileSync('utmp/updateall.sql', 'utf8') };

const wtmp = {
	addEvent  : fs.readFileSync('wtmp/addevent.sql', 'utf8') ,
	logout    : fs.readFileSync('wtmp/logout.sql', 'utf8') };

const missions = {
	insert    : fs.readFileSync('missions/insert.sql', 'utf8') }

class SBEmitter extends EventEmitter {}
const sbEmitter = new SBEmitter();

var watchdog;
var restartwd;
var msgRecv;
var numOfPlayers;
var restart;
var rebootTime;
var dcscmd;

function restartComputer () {
	var date = new Date();
	var day  = date.getDay();

	dcscmd = "restartComputer.bat";
	exec(dcscmd);
	restartwd = setInterval(function() { console.log("restart again " + dcscmd); exec(dcscmd); }, 10*60*1000);	// 5'
	console.log("restart " + dcscmd);
}

function startDCS () {
	var now = new Date();

	dcscmd = "startDCS1.bat";

	exec(dcscmd);
	console.log("restart " + dcscmd);
}

function addEventWtmp(dbCon, msg) {
	dbCon.query( {
		sql    : wtmp.addEvent,
		values : {
			alias : msg.data.alias, 
	   		date  : msg.timeS.os, 
			event : msg.type,
		   	ucid  : msg.data.ucid }},
		function(err, result) {
			if (err) console.log(err);
		});
}

function sqlStartTrans(dbCon)
{
	dbCon.query( {
		sql    : 'START TRANSACTION'},
		function(err, result) {
			if (err) console.log(err);
		});
}

function sqlCommitTrans(dbCon)
{
	dbCon.query( {
		sql    : 'START TRANSACTION'},
		function(err, result) {
			if (err) console.log(err);
		});
}

sbEmitter.on(
	'restart',
	function() {
		restartComputer();
		console.log("Restarting DCS");
		restart = "done";
	});

sbEmitter.on(
	'frame',
	function(msg) {
		if (typeof watchdog == 'undefined') {
			console.log("Initializing watchdog");
			watchdog = setInterval(
				function() {
					var now = new Date();
					console.log("Watchdog routine");
					if (msgRecv === 0) {
						numOfPlayers = 0;

						var dbCon = mysql.createConnection(config.db);
						dbCon.on (
							'error', 
							function (err) {
								console.log(err.code);
								console.log(err.fatal);
							});

						dbCon.connect();

						dbCon.query({
							sql: utmp.empty },
							function(err, result) {
								if (err) console.log(err);
							});

						addEventWtmp (dbCon, {
							type  : 'serverdown',
							timeS : {
								os : now },
							data  : {
								alias : 'WATCHDOG',
								ucid  : '00000000000000000000000000000000'}});

						dbCon.end();

						console.log('Server is down');
						restart = "ready";
					} else {
						console.log('Server is alive and kicking');
					}

					if (now.getTime() >= rebootTime.getTime()) {
						if (restart == "waiting")
							restart = "ready";
						if (typeof restart === "undefined")
							restart = "ready";
					} else { 
						if (restart == "done")
							restart = "waiting"
					}

					if (numOfPlayers < 1) {
						if (restart == "ready")  {
							clearInterval(watchdog);
							watchdog = undefined;
							sbEmitter.emit('restart');
						}
					} else
						console.log("Number of players : " + numOfPlayers);

					msgRecv = 0;
				},
				120*1000);	// 90 seconds
		}
	});

sbEmitter.on(
	'ready',
	function (msg) {
		clearInterval(restartwd);
		restartwd = undefined;
		console.log(dcscmd + " was restarted");
		numOfPlayers = 0;

		rebootTime = new Date();
		rebootTime.setMilliseconds(000);
		rebootTime.setSeconds(00);
		rebootTime.setMinutes(00);
		console.log("today day  " + rebootTime.getDay());
		console.log("today hour " + rebootTime.getHours());
		if (5 <= rebootTime.getHours() && rebootTime.getHours() < 17) {
			rebootTime.setHours(17);
		} else {
			if (17 <= rebootTime.getHours()) {
				rebootTime.setTime(rebootTime.getTime() + 24*(60*60*1000));
			}
			rebootTime.setHours(05);
		}
		console.log("set restart day  " + rebootTime.getDay());
		console.log("set restart hour " + rebootTime.getHours());

		var dbCon = mysql.createConnection(config.db);
		dbCon.on (
			'error', 
			function (err) {
				console.log(err.code);
				console.log(err.fatal);
			});

		dbCon.connect();

		dbCon.query({
			sql : utmp.empty },
			function(err, result) {
				if (err) console.log(err);
			});
		addEventWtmp (dbCon, msg);

		dbCon.end();
	});

sbEmitter.on(
	'stop',
	function (msg) {
		var dbCon = mysql.createConnection(config.db);
		dbCon.on (
			'error', 
			function (err) {
				console.log(err.code);
				console.log(err.fatal);
			});

		dbCon.connect();

		addEventWtmp (dbCon, msg);

		dbCon.end();
	});

sbEmitter.on(
	'start', 
	function(msg) {
		var dbCon = mysql.createConnection(config.db);

		dbCon.on (
			'error', 
			function (err) {
				console.log(err.code);
				console.log(err.fatal);
			});

		dbCon.connect();

		addEventWtmp (dbCon, msg);

		dbCon.end();

	});

sbEmitter.on(
	'missionloaded',
	function (msg) {

		var dbCon = mysql.createConnection(config.db);
		dbCon.on (
			'error', 
			function (err) {
				console.log(err.code);
				console.log(err.fatal);
			});

		dbCon.connect();

		dbCon.query({
			sql    : missions.insert,
	   		values : {
				date : msg.timeS.os, 
				name : msg.data.mname }},
			function(err, result) {
				if (err) console.log(err);
			});

		dbCon.query({
			sql    : utmp.updateall,
	   		values : {
				side : 0}},
			function(err, result) {
				if (err) console.log(err);
			});

		addEventWtmp (dbCon, msg);
		dbCon.end();
	});

sbEmitter.on(
	'login',
   	function(msg) {

		if (msg.data.id > 1)
			numOfPlayers++;

		console.log("Number of players : " + numOfPlayers);
		var dbCon = mysql.createConnection(config.db);
		dbCon.on (
			'error', 
			function (err) {
				console.log(err.code);
				console.log(err.fatal);
			});

		dbCon.connect();

		dbCon.query( {
			sql    : users.signup,
			values : { 
				date  : msg.timeS.os,
				alias : msg.data.alias,
				ucid  : msg.data.ucid }} ,
			function(err, result) {
				if (err) console.log(err);
			});

		dbCon.query( {
			sql    : users.update,
			values : [ { 
				ip    : msg.data.ipaddr.split(":")[0] }, {
				alias : msg.data.alias }, {
				ucid  : msg.data.ucid  }]} ,
			function(err, result) {
				if (err) console.log(err);
			});

		dbCon.query( {
			sql    : utmp.login, 
			values : { 
				alias : msg.data.alias, 
				date  : msg.timeS.os,
				id    : msg.data.id,
				side  : msg.data.side,
				ping  : msg.data.ping,
				ip    : msg.data.ipaddr.split(":")[0],
				slot  : msg.data.slot,
				ucid  : msg.data.ucid }},
			function(err, result) {
				if (err) console.log(err);
			});

		addEventWtmp (dbCon, msg);
		dbCon.end();
	});


sbEmitter.on(
	'logout',
	function (msg) {

		if (msg.data.id > 1)
			numOfPlayers--;

		console.log("Number of players : " + numOfPlayers);
		var dbCon = mysql.createConnection(config.db);
		dbCon.on (
			'error', 
			function (err) {
				console.log(err.code);
				console.log(err.fatal);
			});

		dbCon.connect();

		dbCon.query( {
			sql    : wtmp.logout,
		   	values : [
				msg.timeS.os, 
				{ id : msg.data.id } ] },
			function(err, result) {
				if (err) console.log(err);
			});

		dbCon.query({
			sql    : utmp.logout,
		   	values : {
				id : msg.data.id }},
			function(err, result) {
				if (err) console.log(err);
			});

		dbCon.end();
	});

function cedsEvent(msg) {
	var dbCon = mysql.createConnection(config.db);
	dbCon.on (
		'error', 
		function (err) {
			console.log(err.code);
			console.log(err.fatal);
		});

	dbCon.connect();

	addEventWtmp (dbCon, msg);

	dbCon.end();
}

function killEvent(msg) {
	var dbCon = mysql.createConnection(config.db);
	dbCon.on (
		'error', 
		function (err) {
			console.log(err.code);
			console.log(err.fatal);
		});
	dbCon.connect();

	dbCon.query( {
		sql    : kill.addEvent, 
		values : {
	   		date   : msg.timeS.os, 
		   	kucid  : msg.data.kucid,
		   	kalias : msg.data.kalias,
		   	kutype : msg.data.kutype,
		   	kside  : msg.data.kside,
		   	valias : msg.data.valias,
		   	vucid  : msg.data.vucid,
		   	vutype : msg.data.vutype,
		   	vside  : msg.data.vside,
			wname  : msg.data.wname }},

		function(err, result) {
			if (err) console.log(err);
		});

	addEventWtmp (dbCon, {
		timeS : msg.timeS,
		type  : msg.type,
		data  : {
		  	alias : msg.data.kalias,
		   	ucid  : msg.data.kucid }});

	addEventWtmp (dbCon, {
		timeS : msg.timeS,
		type  : 'killedby',
		data  : {
		  	alias : msg.data.valias,
		   	ucid  : msg.data.vucid }});

	dbCon.end();
}

function airdromeEvent(msg) {
	var dbCon = mysql.createConnection(config.db);
	dbCon.on (
		'error', 
		function (err) {
			console.log(err.code);
			console.log(err.fatal);
		});
	dbCon.connect();


	dbCon.query( {
		sql    : airdrome.addEvent, 
		values : {
	   		date  : msg.timeS.os, 
			name  : msg.data.airdromeName,
		   	ucid  : msg.data.ucid }},
		function(err, result) {
			if (err) console.log(err);
		});

	addEventWtmp (dbCon, msg);

	dbCon.end();
}

sbEmitter.on(
	'change_slot',
 	function(msg){

		var dbCon = mysql.createConnection(config.db);
		dbCon.on (
			'error', 
			function (err) {
				console.log(err.code);
				console.log(err.fatal);
			});

		dbCon.connect();

		dbCon.query( {
			sql    : utmp.update, 
			values :  [ { 
				alias : msg.data.alias, 
			//	date  : msg.timeS.os,
				id    : msg.data.id,
				side  : msg.data.side,
				ping  : msg.data.ping,
				ip    : msg.data.ipaddr.split(":")[0],
				slot  : msg.data.slot },
				{ ucid  : msg.data.ucid } ]},
			function(err, result) {
				if (err) console.log(err);
			});

		addEventWtmp (dbCon, msg);

		dbCon.end();
	});

sbEmitter.on ('crash',         cedsEvent);
sbEmitter.on ('eject',         cedsEvent);
sbEmitter.on ('friendly_fire', killEvent);
sbEmitter.on ('kill',          killEvent);
sbEmitter.on ('landing',       airdromeEvent);
sbEmitter.on ('pilot_death',   cedsEvent);
sbEmitter.on ('self_kill',     cedsEvent);
sbEmitter.on ('takeoff',       airdromeEvent);

var server = dgram.createSocket('udp4');

server.on(
	'listening',
   	function () {
		const address = server.address();
		console.log('listening -> ' + address.address + ":" + address.port);
	});

server.on(
	'message',
	function (data, remote) {
		msgRecv = 1;
		const msg = JSON.parse(data.toString());
		console.log('message -> ' + data.toString());
		sbEmitter.emit(msg.type, msg);
	});

server.bind(config.dcs.port, config.dcs.ip);
startDCS();
