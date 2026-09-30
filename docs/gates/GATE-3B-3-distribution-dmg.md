# TodoSticky Gate 3B-3 — Distribution DMG

Date: 2026-09-30
Baseline: `5b230713da84be9702856231bea0802ce92a8d0c` (`main`)

## Closure

`GATE 3B-3 — PASS / CLOSED / FROZEN`

`FINAL DMG — SIGNED`
`FINAL DMG — NOTARIZED`
`FINAL DMG — STAPLED`
`INSTALL ARTIFACT — VALIDATED`

This Gate closes validation of the exact accepted distribution DMG. No rebuild,
DMG recreation, re-signing, or additional Apple notarization submission was
performed in this run. Gate 3B-4 GitHub remote, tag, and release publication
remain outside this Gate.

## Source and repository baseline

- Source commit: `5b230713da84be9702856231bea0802ce92a8d0c`
- Branch: `main`
- Parent: `446af4aa2ede23f05ff37bb41671c23168903079`
- Index and tracked worktree were clean before validation.
- The only pre-existing untracked file was `default.profraw`; it was not read,
  modified, deleted, staged, or committed.

## App notarization

- Submission: `fc1be8ec-269e-465a-903e-9225ffe9e68c`
- Status: `Accepted`

## DMG and controlled Apple submission history

- Filename: `TodoSticky-0.1.0-arm64.dmg`
- Artifact used: `/tmp/todosticky-gate3b3.r0QseG/TodoSticky-0.1.0-arm64.dmg`
- Developer ID identity: `Developer ID Application: DEGENG CHEN (P5949MJ486)`
- TeamIdentifier: `P5949MJ486`
- Pre-staple SHA-256:
  `54e8e3027cebf358a6910fb0dee5c996ec22e4d9a937e57824b924ea8869000a`
- The exact unchanged artifact was verified with this SHA-256 before the one
  authorized controlled resubmission.

The first DMG submission was not characterized as an artifact rejection:

- Submission: `84f82f27-5dca-40ea-96dd-5aa5f25acc92`
- Initially observed: `In Progress`
- It subsequently disappeared from Apple notary history.
- Later `notarytool info` reported that the submission did not exist or did
  not belong to the team.

The controlled resubmission of the unchanged DMG was accepted:

- Submission: `1c85b537-9e5a-49e9-9821-effc9661ee3c`
- Status: `Accepted`
- Status summary: `Ready for distribution`
- Status code: `0`
- Issues: `null`
- Archive filename: `TodoSticky-0.1.0-arm64.dmg`
- Apple log SHA-256: `54e8e3027cebf358a6910fb0dee5c996ec22e4d9a937e57824b924ea8869000a`
- Ticket architecture: `arm64`
- Ticket app CDHash: `000871f480a1cd90eb7d57a7b47f1ec0660e0da5`
- Ticket executable CDHash: `000871f480a1cd90eb7d57a7b47f1ec0660e0da5`
- Ticket DMG CDHash: `935426df7562aa29804e1cc9f943469f00125874`

## Stapling and final signature verification

- `xcrun stapler staple`: **PASS** (`The staple and validate action worked!`).
- `xcrun stapler validate`: **PASS** (`The validate action worked!`).
- `codesign --verify --verbose=2`: **PASS**.
- Signature authority chain: Developer ID Application → Developer ID
  Certification Authority → Apple Root CA.
- Signature subject: `DEGENG CHEN (P5949MJ486)`.
- Secure timestamp: `Sep 29, 2026 at 15:04:33`.
- `Notarization Ticket=stapled`.
- `spctl --assess --type open --verbose=4`: `accepted`, with
  `override=security disabled` and `source=Insufficient Context`.

The local Mac reports Gatekeeper assessments disabled. The `spctl` result is
therefore auxiliary evidence and does not claim clean-machine Gatekeeper
behavior.

## Final artifact identity

Stapling changed the DMG bytes. The canonical artifact for the eventual
release upload is the post-staple artifact:

- Final post-staple SHA-256:
  `aac0f967972fb5646f0ed3f444d0d6b9d4e94c6eebea495982f8b2cd58503c29`
- Final byte size: `2164235`

## Final mount audit

The final stapled DMG was mounted read-only. Its user-facing top level was
exactly:

- `TodoSticky.app`
- `Applications -> /Applications`

No unexpected top-level files were present.

The embedded app was independently verified:

- `codesign --verify --deep --strict --verbose=2`: **PASS**.
- `xcrun stapler validate`: **PASS**.
- Bundle ID: `com.jasminstudio.TodoSticky`.
- Version: `0.1 (1)`.
- Architecture: arm64.
- Developer ID identity and TeamIdentifier remained
  `DEGENG CHEN (P5949MJ486)` / `P5949MJ486`.
- `Notarization Ticket=stapled`.
- `CFBundleIconFile` and `CFBundleIconName` remained `AppIcon`; the embedded
  `Contents/Resources/AppIcon.icns` resource was present.

## Install simulation and runtime smoke

The embedded app was copied from the mounted final DMG to an isolated
temporary installation directory outside the repository. The copied app
passed codesign verification and stapler validation, preserving the same
Developer ID identity, Bundle ID, version, and stapled ticket.

The copied app launched successfully and was inspected through its native
accessibility/UI state and screenshot:

- `Todo Sticky` main window appeared.
- Input field with placeholder `添加待办事项…` appeared.
- Existing Todo list appeared.
- Menu bar entries `TodoSticky`, `Edit`, `View`, `Window`, and `Help` appeared.
- The expected yellow sticky-note UI rendered normally.
- No immediate crash occurred.
- The exact temporary install process was terminated cleanly.
- The final DMG mount was detached cleanly.
- The temporary installation directory was moved to the user's Trash after
  verification; no repository path was affected.

## Diff review and exact staging

The expected repository change is only:

`docs/gates/GATE-3B-3-distribution-dmg.md`

`git diff --check`: **PASS**.

Only this Gate document was staged. The DMG, app, ZIP, certificates, keys,
credentials, and `default.profraw` were not staged.

No source, project configuration, credentials, certificate, key, tag, GitHub
release, or push was changed by this Gate.

Next Gate: Gate 3B-4 — GitHub Remote + Tag + GitHub Release Publication.
