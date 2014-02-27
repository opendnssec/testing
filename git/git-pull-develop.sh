#!/bin/sh

# Fetch updates from upstream
git fetch upstream

# Update your local develop branch
git checkout develop &&
git merge --ff-only upstream/develop &&
git push origin develop &&
echo "develop pull OK" || echo "develop pull FAILED"
