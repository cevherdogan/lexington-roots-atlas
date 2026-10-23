#!/bin/bash
set -Eeuo pipefail
VERSION=v0.1.0
REPO_NAME=lexington-roots-atlas
OWNER=${GITHUB_OWNER:-cevherdogan}
REMOTE_ROOT=${REMOTE_ROOT:-"$HOME/github"}
TARGET="$REMOTE_ROOT/$REPO_NAME"
PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ echo "ERROR: $*" >&2; exit 1; }
command -v git >/dev/null || fail 'git missing'
command -v gh >/dev/null || fail 'GitHub CLI missing: brew install gh'
command -v python3 >/dev/null || fail 'python3 missing'
gh auth status >/dev/null 2>&1 || fail 'Run gh auth login first'
python3 "$PKG/tests/validate.py"
mkdir -p "$REMOTE_ROOT"
if [ -e "$TARGET" ] && [ ! -d "$TARGET/.git" ]; then fail "Target exists but is not a git repository: $TARGET"; fi
if [ -d "$TARGET/.git" ]; then
  [ -z "$(git -C "$TARGET" status --porcelain)" ] || fail 'Existing repo has uncommitted changes; no files touched'
  BRANCH=$(git -C "$TARGET" branch --show-current)
  [ "$BRANCH" = main ] || fail "Expected main branch, got $BRANCH"
  git -C "$TARGET" fetch origin --tags
  git -C "$TARGET" merge-base --is-ancestor origin/main HEAD || fail 'Local main diverged from origin/main'
  git -C "$TARGET" merge-base --is-ancestor HEAD origin/main || fail 'Local main is ahead of origin/main; publish it separately first'
  git -C "$TARGET" pull --ff-only origin main
else
  if gh repo view "$OWNER/$REPO_NAME" >/dev/null 2>&1; then
    gh repo clone "$OWNER/$REPO_NAME" "$TARGET"
    [ -z "$(git -C "$TARGET" status --porcelain)" ] || fail 'Clone dirty'
  else
    mkdir -p "$TARGET"
    git -C "$TARGET" init -b main
    gh repo create "$OWNER/$REPO_NAME" --public --description 'Lexington Roots Atlas: US history, culture, education and Appalachian associations' --confirm
    git -C "$TARGET" remote add origin "https://github.com/$OWNER/$REPO_NAME.git"
  fi
fi
if git -C "$TARGET" rev-parse "$VERSION" >/dev/null 2>&1; then fail "Tag $VERSION already exists: refusing to overwrite"; fi
for f in README.md CHANGELOG.md; do cp "$PKG/$f" "$TARGET/$f"; done
mkdir -p "$TARGET/site" "$TARGET/tests" "$TARGET/bin"
cp "$PKG/site/"* "$TARGET/site/"
cp "$PKG/tests/"* "$TARGET/tests/"
cp "$PKG/bin/deploy.sh" "$TARGET/bin/deploy.sh"
python3 "$TARGET/tests/validate.py"
git -C "$TARGET" add README.md CHANGELOG.md site tests bin/deploy.sh
git -C "$TARGET" diff --cached --quiet && fail 'No changes to commit'
git -C "$TARGET" commit -m "release: Lexington Roots Atlas $VERSION"
git -C "$TARGET" tag -a "$VERSION" -m "Lexington Roots Atlas $VERSION"
git -C "$TARGET" push -u origin main
git -C "$TARGET" push origin "$VERSION"
if ! gh release view "$VERSION" --repo "$OWNER/$REPO_NAME" >/dev/null 2>&1; then
  gh release create "$VERSION" "$PKG.zip" --repo "$OWNER/$REPO_NAME" --title "Lexington Roots Atlas $VERSION" --notes-file "$PKG/CHANGELOG.md"
fi
# GitHub Pages API configuration: deploy from main /site
if ! gh api --method POST "repos/$OWNER/$REPO_NAME/pages" -f 'source[branch]=main' -f 'source[path]=/site' >/dev/null 2>&1; then
  gh api --method PUT "repos/$OWNER/$REPO_NAME/pages" -f 'source[branch]=main' -f 'source[path]=/site' >/dev/null || fail 'Could not configure Pages; check permissions/plan'
fi
REMOTE_SHA=$(git -C "$TARGET" ls-remote origin refs/heads/main | cut -f1)
LOCAL_SHA=$(git -C "$TARGET" rev-parse HEAD)
[ "$REMOTE_SHA" = "$LOCAL_SHA" ] || fail 'Remote commit mismatch'
gh release view "$VERSION" --repo "$OWNER/$REPO_NAME" >/dev/null || fail 'Release verification failed'
gh api "repos/$OWNER/$REPO_NAME/pages" --jq '.source.branch + ":" + .source.path' | grep -qx 'main:/site' || fail 'Pages configuration verification failed'
echo "PASS: commit $LOCAL_SHA; tag $VERSION; release; Pages configured"
echo "Site URL (build may take minutes): https://$OWNER.github.io/$REPO_NAME/"
