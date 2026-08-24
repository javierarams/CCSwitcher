import Foundation
import AppKit
import Sparkle
import SwiftUI

/// Thin ObservableObject wrapper around Sparkle's `SPUStandardUpdaterController`.
/// Keeps the existing call-site API (`checkForUpdates(manual:)`,
/// `@Published var isChecking`) so `CCSwitcherApp.swift` and `SettingsView.swift`
/// don't need to change. Sparkle owns its own progress UI (download sheet,
/// release-notes window, restart prompt), so `isChecking` is kept for source
/// compatibility but is never flipped — clicking the button always shows
/// Sparkle's UI immediately, which provides its own feedback.
@MainActor
final class UpdateChecker: ObservableObject {
    /// Source-compat shim. Sparkle's UI is responsible for visible progress.
    @Published var isChecking = false

    private let controller: SPUStandardUpdaterController

    init() {
        // The updater still STARTS: that is what keeps SUPublicEDKey loaded and
        // EdDSA verification wired up, so re-pointing SUFeedURL at this fork's
        // own releases is a one-line change.
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // SUEnableAutomaticChecks in Info.plist is only the DEFAULT; Sparkle
        // lets a stored user default win. This fork keeps the upstream bundle
        // identifier, so a machine that ever ran an upstream build already has
        // that preference persisted as true and the Info.plist value would
        // never be consulted. Writing it here is what actually holds.
        controller.updater.automaticallyChecksForUpdates = false
        controller.updater.automaticallyDownloadsUpdates = false
    }

    /// User-initiated only, and shows Sparkle's full UI including the
    /// "you're up to date" result.
    ///
    /// `manual` is retained for source compatibility but no longer selects a
    /// background path: `checkForUpdatesInBackground()` ignores
    /// `automaticallyChecksForUpdates`, so honouring it would reintroduce
    /// exactly the silent upstream check this fork disables.
    func checkForUpdates(manual: Bool = true) {
        _ = manual
        controller.checkForUpdates(nil)
    }
}
