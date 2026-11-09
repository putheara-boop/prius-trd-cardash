# Auto Git Push & Screenshot Archiving Rule

Whenever any feature, bugfix, or code modification in this workspace is implemented, tested, or completed:
1. **Screenshot Archiving:**
   - Always capture/fetch the live screenshot from the iPad Mini (`/var/mobile/h109-build/cardash.png`).
   - Save the screenshot to the `screenshots/` directory with a descriptive name (e.g. `screenshots/screen_<feature>_verified.png`).
2. **Git Staging & Commit:**
   - Stage modified code files AND new/updated screenshots in `screenshots/` using `git add`.
   - Commit with a clear, conventional commit message (e.g. `feat(...)`, `fix(...)`).
3. **Automatic Remote Push:**
   - Always automatically push to the GitHub remote repository (`git push origin main`) without requiring the user to explicitly ask.
4. **User Confirmation:**
   - Report the commit hash, pushed screenshot path(s), and sync status to พี่พุธ.
