#!/usr/bin/bash
# Publish to GitHub Pages on gh-pages branch and push to origin + mirror

if [ -n "$(git status --porcelain)" ]; then
  echo "Please commit all changes before publishing with this script"
  exit 1
fi

if [ ! -f "_config.yml" ]; then
  echo "Please run this script from the base project directory"
  exit 1
fi

commit_hash=$(git rev-parse HEAD)
branch=$(git rev-parse --abbrev-ref HEAD)

if [ -d "_scripts/publish.d" ]; then
  rm -rf "/tmp/publish.d"
  cp -r "_scripts/publish.d" "/tmp/publish.d"
fi

bundle exec jekyll b -d /tmp/gh-pages-publish

git checkout gh-pages
git pull

git ls-files -z -- . ':!:.git*' | xargs -0 rm -f
cp -r /tmp/gh-pages-publish/* .

# Run any extra publish hooks, if they exist
if [ -d "/tmp/publish.d" ]; then
  for script in /tmp/publish.d/*; do
    [ -f "$script" ] && "$script"
  done
fi

git add .
git commit -m "publish commit ${commit_hash}"

# Push to origin
git push origin gh-pages

# Push to mirror if it exists
if git remote get-url mirror >/dev/null 2>&1; then
  git push mirror gh-pages
else
  echo "Remote 'mirror' not found, skipping mirror push."
fi

git checkout "${branch}"
