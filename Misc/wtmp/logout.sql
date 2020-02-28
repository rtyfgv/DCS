INSERT INTO wtmp (ucid, alias, event, date) SELECT ucid, alias, "logout", ? FROM utmp WHERE ?
