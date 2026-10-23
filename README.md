# Lexington Roots Atlas v0.1.0

Evidence-first, searchable static Magic HTML site. Initial Lexington, Virginia scope with US-history associations.

## Run
`bash ~/Downloads/lexington-roots-atlas-v0.1.0/bin/deploy.sh`

Prerequisites: macOS, git, GitHub CLI (`gh`), authenticated `gh auth login`, permission to create repositories. Deployment is intentionally non-destructive.

Repository: `cevherdogan/lexington-roots-atlas` (created by deployer if absent). GitHub Pages from main branch /site.

## Workflow
Baseline → migration → validation → release. Every release validates, checks existing Git state, commits, tags, pushes, publishes release, and verifies remote state. Existing changes are never overwritten. If a remote repository already exists, deployment requires a clean clone with compatible ancestry.
