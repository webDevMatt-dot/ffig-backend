#!/bin/bash

# Usage: ./git_actions.sh [optional_commit_message]

MSG="$1"

# If no argument is provided, prompt the user
if [ -z "$MSG" ]; then
  echo -n "Enter commit message: "
  read MSG
fi

# detailed check for empty message
if [ -z "$MSG" ]; then
  echo "Error: Commit message cannot be empty."
  exit 1
fi

echo "Adding files..."
git add .

echo "Committing with message: '$MSG'..."
git commit -m "$MSG"

# Get current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "Pulling latest changes from remote..."
git pull --rebase origin "$BRANCH"

# Check if pull was successful
if [ $? -ne 0 ]; then
    echo "Error: Pull failed. You may have merge conflicts."
    echo "Please resolve conflicts, then run: git add . && git rebase --continue"
    echo "After that, you can try pushing again."
    exit 1
fi

echo "Pushing to remote..."
# Push and set upstream if it doesn't exist
git push -u origin "$BRANCH"
