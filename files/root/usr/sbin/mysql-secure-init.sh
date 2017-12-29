#!/usr/bin/expect
set timeout 10
spawn mysql_secure_installation

expect "current password for root (enter for none):"
send "\r"

expect "root password?"
send "n\r"

expect "emove anonymous users?"
send "y\r"

expect "isallow root login remotely?"
send "y\r"

expect "emove test database and access to it?"
send "y\r"

expect "eload privilege tables now?"
send "y\r"

expect eof