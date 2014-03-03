#!/bin/sh

# Fetch updates from upstream
git fetch upstream

# Update your local master branch
git checkout master &&
git merge --ff-only upstream/master &&
git push origin master &&
echo "master pull OK" || echo "master pull FAILED"

# Update your local develop branch
git checkout develop &&
git merge --ff-only upstream/develop &&
git push origin develop &&
echo "develop pull OK" || echo "develop pull FAILED"

# If this is a fork of OpenDNSSEC, also update all MAJOR VERSION branches
git branch -r | grep 'origin/[0-9].[0-9]/' | sed 's%origin/%%' | while read branch; do \
	git checkout $branch || git checkout -b $branch origin/$branch || break; \
	git merge --ff-only upstream/$branch && git push origin $branch || break; \
done && echo "versions pull OK" || echo "versions pull FAILED"
