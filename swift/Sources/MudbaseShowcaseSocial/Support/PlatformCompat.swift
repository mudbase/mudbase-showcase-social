import SwiftUI

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
/// The real target platform for this app is iOS; the secondary `.macOS(.v14)` platform in
/// `Package.swift` exists purely so `swift build` succeeds from the CLI in an environment with no
/// iOS Simulator (see README "Why SPM, not an `.xcodeproj`"). `PlatformImage` lets
/// `PostComposerViewModel`'s picked-photo preview compile on both.
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    /// Cross-platform `Image` init from a `PlatformImage` — `UIImage` on iOS, `NSImage` on macOS.
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

/// `.keyboardType` and `.textInputAutocapitalization` only exist on iOS/tvOS/watchOS — this
/// target also builds for macOS. These no-op on macOS instead of failing to compile. Ported
/// verbatim from the ecommerce Swift port's `Support/PlatformCompat.swift`.
extension View {
    @ViewBuilder
    func emailKeyboard() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS)
        self.keyboardType(.emailAddress).textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func urlKeyboard() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS)
        self.keyboardType(.URL).textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    /// `.navigationBarTitleDisplayMode` is unavailable on macOS entirely (there is no navigation
    /// bar to compress) — this project's real target is iOS/iPadOS, where it applies normally.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS) || os(tvOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
