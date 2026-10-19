# Publish this repository

The folder is already a valid repository: it just has no `.git` yet. Two ways to get it onto
GitHub under `@acenkk13`.

---

## Before you start

Suggested repository settings:

| Field | Value |
| --- | --- |
| Owner | `acenkk13` |
| Name | `ACNX` |
| Description | `Windows optimization toolkit. Network, NVIDIA App and the Alt+Z overlay stay working.` |
| Visibility | Public |
| Topics | `windows`, `optimizer`, `gaming`, `nvidia`, `latency`, `batch`, `tweaks` |
| License | MIT (already in `LICENSE`) |

Do **not** initialize with a README — this folder already has one.

---

## Path A — GitHub web upload (nothing to install)

1. Create the repository on GitHub with the settings above, **without** any initial files.
2. On the empty repo page click **uploading an existing file**.
3. Drag the whole `ACNX` folder contents in. Keep the folder structure:
   `.github/`, `src/`, `dist/`, `docs/`, `releases/`, `tools/`.
4. Commit message: `Initial commit — ACNX v1.0.0`.
5. Go to **Releases → Draft a new release**:
   - Tag: `v1.0.0` (create it on publish)
   - Title: `ACNX v1.0.0`
   - Description: paste the contents of `releases/v1.0.0.md`
   - Attach: `dist/ACNX-v1.0.0.zip` and `dist/SHA256SUMS.txt`
   - Publish.

Path A does not run the CI audit. If you want the green checks, use Path B.

---

## Path B — git + gh (recommended)

Install once:

```powershell
winget install --id Git.Git -e --silent
winget install --id GitHub.cli -e --silent
```

Restart the terminal, then:

```powershell
gh auth login
```

Choose **GitHub.com → HTTPS → Login with a web browser** and authorize.

Then publish:

```powershell
cd C:\Users\Administrator\Desktop\111\ACNX

git init -b main
git config user.name  "acenkk13"
git config user.email "<your-github-email>"

git add .
git commit -m "Initial commit - ACNX v1.0.0"

# creates the repo, adds the remote, pushes
gh repo create ACNX --public --source=. --remote=origin --push `
   --description "Windows optimization toolkit. Network, NVIDIA App and the Alt+Z overlay stay working."

gh repo edit --add-topic windows,optimizer,gaming,nvidia,latency,batch,tweaks
```

Release:

```powershell
pwsh -File tools/build-release.ps1

git add .
git commit -m "chore(release): v1.0.0"
git tag v1.0.0
git push origin main --tags
```

The `release` workflow audits, builds, attaches `ACNX-v1.0.0.zip` and `SHA256SUMS.txt`, and
publishes the GitHub release automatically. Nothing else to do.

---

## What the release list looks like

Atlas-style, each version gets its own markdown file and a tag:

```text
releases/
├── v1.0.0.md     <- body of the GitHub release for tag v1.0.0
└── v1.1.0.md     <- next one
```

`tools/build-release.ps1` reads `releases/v<version>.md` and ships it as the release body, so the
GitHub Releases page and the repo never drift apart.

To cut the next release:

```text
1. Edit src/...
2. pwsh -File tools/audit-release.ps1
3. Add entries to CHANGELOG.md
4. Write releases/v1.1.0.md
5. Set VERSION to 1.1.0
6. pwsh -File tools/build-release.ps1
7. git tag v1.1.0 && git push origin main --tags
```

---

## Post-publish checklist

- [ ] `README.md` badges resolve (release, downloads, license).
- [ ] `v1.0.0` release exists with both assets attached.
- [ ] `SHA256SUMS.txt` in the release matches the zip you uploaded.
- [ ] Actions tab shows the `audit` job green.
- [ ] `docs/INSTALL.md` and `docs/TROUBLESHOOTING.md` render without broken relative links.
- [ ] `SECURITY.md` appears in the Security tab.
- [ ] Issue templates appear under **New issue**.

---

## Notes

- `dist/` is git-ignored. Release artifacts belong on the Releases page, not in the tree.
- The scripts in `src/` are stored byte-for-byte. `.gitattributes` blocks line-ending
  normalization; if you ever see a diff whose only change is line endings, **abort the commit**.
- Keep the audit green. A red audit means a script would break Wi-Fi, Ethernet or the overlay.
