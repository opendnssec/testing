#!/bin/sh

# Fetch updates from upstream
git fetch upstream
 
# If this is a fork of OpenDNSSEC, also update all MAJOR VERSION branches
git branch -r | grep 'origin/[0-9].[0-9]/' | sed 's%origin/%%' | while read branch; do \
	git checkout $branch || git checkout -b $branch origin/$branch || break; \
	git merge --ff-only upstream/$branch && git push origin $branch || break; \
done
