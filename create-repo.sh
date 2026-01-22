#!/bin/bash
# Script to create GitHub repository using curl

REPO_NAME="clickhouse-training"
GITHUB_USER="ro-29"

echo "Creating private GitHub repository: $REPO_NAME"

# You'll need a GitHub Personal Access Token with 'repo' scope
# Get it from: https://github.com/settings/tokens

read -sp "Enter your GitHub Personal Access Token: " GITHUB_TOKEN
echo ""

curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/user/repos \
  -d "{
    \"name\": \"$REPO_NAME\",
    \"description\": \"Complete ClickHouse Knowledge Transfer Training Series - 10 modules covering fundamentals to production deployment\",
    \"private\": true,
    \"has_issues\": true,
    \"has_projects\": false,
    \"has_wiki\": false
  }"

echo ""
echo "Repository created successfully!"
echo "You can now push with: git push -u origin main"
