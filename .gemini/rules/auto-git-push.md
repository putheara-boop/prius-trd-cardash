# Auto Git Push Rule

Whenever any feature, bugfix, or code modification in this workspace is implemented, tested, or completed:
1. Stage the modified code files using `git add <files>`.
2. Commit with a meaningful, conventional commit message (e.g. `feat(...)`, `fix(...)`).
3. Always automatically push to the GitHub remote repository (`git push origin main`) without requiring the user to explicitly ask.
4. Report the commit hash and sync status to the user.
