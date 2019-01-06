#!/bin/bash

case $1 in
	"set") sudo pmset hibernatemode $2;;
	"rm") sudo rm -f $2;;
	*) echo "unknown command"; exit 1;;
esac
