#!/usr/bin/env bash
# Build main's current commit and publish the generated site to gh-pages.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
if [ -n "$(git status --porcelain)" ]; then
  echo "Please commit all changes before publishing with this script"
  exit 1
fi
if [ ! -f "_config.yml" ]; then
  echo "Please run this script from the website repository"
  exit 1
fi

commit_hash=$(git rev-parse HEAD)
publish_root=$(mktemp -d "${TMPDIR:-/tmp}/owenh-publish.XXXXXX")
cleanup() {
  if [ -d "$publish_root/checkout" ]; then
    git worktree remove --force "$publish_root/checkout"
  fi
  rm -rf -- "$publish_root"
}
trap cleanup EXIT

bundle exec jekyll build --destination "$publish_root/site"
git fetch origin gh-pages
git worktree add --detach "$publish_root/checkout" origin/gh-pages
# Delete tracked files only in the temporary publishing worktree.
git -C "$publish_root/checkout" rm -r --ignore-unmatch -- .
cp -a "$publish_root/site/." "$publish_root/checkout/"

for script in "$PWD"/_scripts/publish.d/*.sh; do
  [ -f "$script" ] || continue
  (cd "$publish_root/checkout" && bash "$script")
done

git -C "$publish_root/checkout" add --all
if git -C "$publish_root/checkout" diff --cached --quiet; then
  echo "The published site is already up to date."
else
  git -C "$publish_root/checkout" commit -m "Publish source commit $commit_hash"
  git -C "$publish_root/checkout" push origin HEAD:gh-pages
fi
