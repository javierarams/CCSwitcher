# About this fork

This repository is a personal fork of [XueshiQiao/CCSwitcher](https://github.com/XueshiQiao/CCSwitcher),
branched at `ed09ce5` (v1.12.0, build 66). It exists to carry a small set of
security and privacy fixes applied after a source audit of that release. It is
not a competing project and it is not a redistribution: upstream remains the
place to file bugs and read release notes.

No feature was removed, and no upstream behaviour was changed beyond what the
fixes below require.

## Security changes relative to upstream

**The OAuth token no longer travels in `argv`.** Upstream wrote the Claude Code
credential by passing it as `security add-generic-password -w <token>`. On macOS
a process's argument list is readable by any other process running as the same
user (`ps -ww ax`, `sysctl KERN_PROCARGS2`), so both the access token and the
refresh token were observable during every account switch. The credential is now
fed to `security` over stdin, keeping it out of `argv` entirely.

**Account emails are masked in the log.** `~/Library/Logs/CCSwitcher-app.log`
recorded email addresses in the clear at 25 call sites, despite the code stating
the opposite intent and already shipping masking helpers. That log rotates and is
the natural thing to attach to a bug report. Every site now masks.

**Sparkle is pinned to exactly 2.9.0.** Upstream declared `from: 2.9.0`, which
resolves to any 2.x, and `Package.resolved` is gitignored — so no commit recorded
which version of the only external dependency actually went into a build. The
version is now exact, matching the Sparkle version CI already pins for its
signing tools.

## Why auto-update is disabled

`SUFeedURL` still points at the upstream project's appcast, which advertises
upstream's builds. If automatic checking were left on, Sparkle would find an
upstream release, install it over this fork, and silently revert the fixes above
— putting the token back into `argv` without anyone choosing that.

So automatic checking is off, in two places, because one is not enough:

- `SUEnableAutomaticChecks: false` in `project.yml` sets the default.
- `automaticallyChecksForUpdates = false` in `UpdateChecker.init()` is what
  actually holds. This fork keeps the upstream bundle identifier, so a machine
  that ever ran an upstream build already has that preference persisted, and
  Sparkle prefers the stored value over the Info.plist default.

**Sparkle itself is deliberately still present, and so is `SUPublicEDKey`.**
Starting the updater with the public key in place keeps EdDSA signature
verification wired up, so pointing `SUFeedURL` at this fork's own releases later
is a one-line change rather than a re-integration. The "Check for Updates" button
in Settings still works — an explicit, user-initiated check is the user's call —
but be aware that it currently checks the *upstream* feed, and accepting an
update it offers will replace this fork.

Consequence to accept: **this fork does not update itself.** To pick up upstream
changes, rebase this branch onto upstream and rebuild.

## Installing the CI build

The DMG is produced by `.github/workflows/build.yml` on every push to `main` and
every pull request, so no local Xcode is needed.

1. Open the workflow run on the Actions tab and download the artifact named
   **`CCSwitcher-macOS`**. It contains `CCSwitcher.dmg`.
2. Mount the DMG and drag `CCSwitcher.app` to `/Applications`.

### macOS will warn, and that is expected

This build is **not signed with a Developer ID and not notarized**. Signing and
notarization in the workflow are gated on Apple secrets that this fork does not
have, so those steps are skipped and the app is built with
`CODE_SIGNING_ALLOWED=NO`. macOS will therefore refuse the first launch with a
message about an unidentified developer or damaged application. That is Gatekeeper
reporting the absence of a Developer ID, not a sign that anything is wrong with
the build.

Choose one of these to get past it:

- **Remove the quarantine attribute** that the browser and DMG set:

  ```sh
  xattr -d com.apple.quarantine /Applications/CCSwitcher.app
  ```

  If that reports that the attribute does not exist on the bundle itself, clear
  it across the whole bundle:

  ```sh
  xattr -r -d com.apple.quarantine /Applications/CCSwitcher.app
  ```

- **Or open it once from the shortcut menu:** right-click (or Control-click)
  `CCSwitcher.app` in Finder, choose **Open**, and confirm. macOS remembers the
  exception for that copy of the app.

Only do either of these for a DMG you built yourself from this repository. The
whole point of Gatekeeper is that it stops you doing it for a binary of unknown
origin, and this fork gives up that protection by not being signed.

## The keychain prompt: answer "Allow", never "Always Allow"

CCSwitcher reads and writes the Claude Code credential through `/usr/bin/security`,
so macOS asks for permission to access the keychain item `Claude Code-credentials`.

**Answer `Allow` each time. Do not answer `Always Allow`.**

`Always Allow` persists the grant permanently, and it grants it to
`/usr/bin/security` — a general-purpose tool any process running as you can
invoke. From then on, any local process could read the access token and the
refresh token silently, with no prompt and no record. That is a permanent change
to the machine's security posture, granted by one click.

The cost of answering `Allow` is real and worth stating: the permission is not
remembered, so you get a dialog on every credential access, **including the token
refreshes the app performs in the background**. The benefit is that nothing reads
those tokens without you seeing it and authorising it at that moment.

The risk to watch for is prompt fatigue — clicking `Always Allow` by reflex after
the tenth dialog.

### If "Always Allow" was granted by mistake

It can be revoked:

1. Open **Keychain Access** (`/System/Applications/Utilities/`).
2. Select the **login** keychain and find the item **`Claude Code-credentials`**.
3. Open it, go to the **Access Control** tab.
4. Remove `/usr/bin/security` from the list of allowed applications, and make
   sure **"Confirm before allowing access"** is selected rather than "Allow all
   applications to access this item".
5. Save the change (it will ask you to authenticate).

The prompts will come back on the next access, which is the intended state.
