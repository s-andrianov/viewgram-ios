import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import ViewgramVerification

/// The Viewgram community channel every client is kept subscribed to.
public let viewgramChannelUsername = "viewgram_app"
/// The Viewgram subscription/verification bot.
public let viewgramBotUsername = "view_chatbot"
/// The Viewgram developer account.
public let viewgramDeveloperUsername = "sanaxis"
/// The Viewgram developer's channel.
public let viewgramDeveloperChannelUsername = "adamlog"

/// Telegram user ids with unlimited privileges (manual refresh without throttle, etc.).
public let viewgramAdminIds: Set<Int64> = [1387865593]

/// Whether the given Telegram user id is a Viewgram admin.
public func viewgramIsAdmin(userId: Int64) -> Bool {
    return viewgramAdminIds.contains(userId)
}

/// Maps an internal `PeerId` to its Telegram Bot API id (the canonical id used by
/// the Viewgram verification backend and Bloom filter).
public func viewgramBotApiId(_ peerId: PeerId) -> Int64 {
    let idValue = peerId.id._internalGetInt64Value()
    let ns = peerId.namespace
    if ns == Namespaces.Peer.CloudUser {
        return idValue
    } else if ns == Namespaces.Peer.CloudGroup {
        return -idValue
    } else if ns == Namespaces.Peer.CloudChannel {
        return -(1_000_000_000_000 + idValue)
    } else {
        return 0
    }
}

/// Whether the given peer carries a Viewgram (paid) verification badge.
public func viewgramIsVerified(_ peerId: PeerId) -> Bool {
    return ViewgramVerification.shared.isVerified(botApiId: viewgramBotApiId(peerId))
}

/// Begin loading/refreshing the verification filter. Call once at launch.
public func viewgramStartVerification() {
    ViewgramVerification.shared.start()
}

/// Refresh the filter if it is stale. Call on app foreground.
public func viewgramRefreshVerification() {
    ViewgramVerification.shared.refreshIfNeeded()
}

/// Force a re-download of the verification filter. `unlimited` bypasses the
/// anti-spam throttle (for admins/self). `completion(success)` runs on main.
public func viewgramForceRefresh(unlimited: Bool, completion: ((Bool) -> Void)? = nil) {
    ViewgramVerification.shared.forceRefresh(unlimited: unlimited, completion: completion)
}

/// Ensure the user is subscribed to the Viewgram channel. Called on every
/// foreground so that leaving via another client is undone on next open.
public func viewgramEnsureChannelMembership(context: AccountContext) {
    let _ = (context.engine.peers.resolvePeerByName(name: viewgramChannelUsername, referrer: nil)
    |> mapToSignal { result -> Signal<Never, NoError> in
        switch result {
        case .progress:
            return .complete()
        case let .result(maybePeer):
            guard let peer = maybePeer else {
                return .complete()
            }
            return context.engine.peers.joinChannel(peerId: peer.id, hash: nil)
            |> ignoreValues
            |> `catch` { _ -> Signal<Never, NoError> in
                return .complete()
            }
        }
    }).start()
}
