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

# Function to handle git operations for a directory
sync_repo() {
    DIR=$1
    echo "------------------------------------------------"
    echo "Processing $DIR..."
    
    # Store original director to ensure we can return if cd fails (though script exits on fail)
    ORIG_DIR=$(pwd)
    
    if [ "$DIR" != "." ]; then
        cd "$DIR" || { echo "Failed to enter $DIR"; exit 1; }
    fi
    
    echo "Items to add:"
    git status -s
    
    echo "Adding files..."
    git add .
    
    # Check if there are changes to commit
    if git diff-index --quiet HEAD --; then
        echo "No changes to commit in $DIR."
    else
        echo "Committing..."
        git commit -m "$MSG"
    fi

    # Get current branch name
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo "Current branch: $BRANCH"

    echo "Pulling latest changes..."
    # strict error checking
    if ! git pull --no-rebase origin "$BRANCH"; then
        echo "Error: Pull failed in $DIR. Please resolve conflicts manually."
        exit 1
    fi

    echo "Pushing to remote..."
    if ! git push -u origin "$BRANCH"; then
        echo "Error: Push failed in $DIR."
        exit 1
    fi
    
    if [ "$DIR" != "." ]; then
        cd "$ORIG_DIR" || exit
    fi
}

# 1. Sync Submodules First
sync_repo "backend"
sync_repo "mobile_app"

# 2. Sync Root Repo
# The root repo needs to be synced LAST because it tracks the specific commit hashes 
# of the submodules. Only after the submodules update can the root "see" 
# that the submodules have changed.
sync_repo "."

echo "------------------------------------------------"
echo "All repositories synced successfully!"
