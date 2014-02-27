#!/bin/sh

# Fetch updates from upstream
git fetch upstream

# Update your local master branch
git checkout master &&
git merge --ff-only upstream/master &&
git push origin master &&
echo "master pull OK" || echo "master pull FAILED"
