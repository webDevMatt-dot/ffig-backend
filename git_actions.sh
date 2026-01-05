#!/bin/bash

# Usage: ./git_actions.sh "Your commit message"

if [ -z "$1" ]; then
  echo "Error: Please provide a commit message."
  echo "Usage: ./git_actions.sh \"Your commit message\""
  exit 1
fi

git add .
git commit -m "$1"
git push
