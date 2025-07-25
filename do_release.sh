#!/bin/bash
set e

PKGNAME=$(basename "$PWD")
VERSION=$(git cliff --bumped-version --unreleased |cut -dv -f2)

sed "s/^version:.*$/version: $VERSION/g" -i shard.yml
git add shard.yml
hace lint test
git cliff --bump -u -p CHANGELOG.md
git commit -a -m "bump: Release v$VERSION"
hace static
git tag "v$VERSION"
git push --tags
gh release create "v$VERSION" "bin/$PKGNAME-static-linux-amd64" "bin/$PKGNAME-static-linux-arm64" --title "Release v$VERSION" --notes "$(git cliff -l -s all)"
hace deploy
hace aur
