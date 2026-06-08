import Foundation

/// Device-local runtime toggles for the Viewgram fork.
///
/// These are intentionally backed by `UserDefaults.standard` rather than the
/// synced Postbox preferences: they are privacy switches that must stay on this
/// device only and must be readable from the low-level networking layer
/// (`TelegramCore`) without plumbing an account-specific preferences view into
/// every call site.
public final class ViewgramRuntimeSettings {
    private static let invisibleKey = "viewgram.invisibleEnabled"
    private static let noReadReceiptsKey = "viewgram.noReadReceiptsEnabled"
    private static let hiddenStarSubscriptionsKey = "viewgram.hiddenStarSubscriptionIds"
    private static let hideExpiredStarSubscriptionsKey = "viewgram.hideExpiredStarSubscriptions"
    private static let adsDisabledKey = "viewgram.adsDisabled"
    private static let mediaCompressionLevelKey = "viewgram.mediaCompressionLevel"

    /// "Невидимка" — when enabled the client never reports an online status to
    /// the server, so other users always see the account as offline.
    public static var invisibleEnabled: Bool {
        get { return UserDefaults.standard.bool(forKey: invisibleKey) }
        set { UserDefaults.standard.set(newValue, forKey: invisibleKey) }
    }

    /// "Нечиталка" — when enabled the client stops pushing incoming read state
    /// to the server, so senders never see read receipts (the blue checkmarks)
    /// for messages this account has read.
    public static var noReadReceiptsEnabled: Bool {
        get { return UserDefaults.standard.bool(forKey: noReadReceiptsKey) }
        set { UserDefaults.standard.set(newValue, forKey: noReadReceiptsKey) }
    }

    /// Device-local set of Star subscription ids that the user swiped to hide
    /// from the "Звёзды" settings screen. Stored as a plain string array.
    public static var hiddenStarSubscriptionIds: Set<String> {
        get { return Set(UserDefaults.standard.stringArray(forKey: hiddenStarSubscriptionsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: hiddenStarSubscriptionsKey) }
    }

    /// When enabled, expired Star subscriptions (past their `untilDate`) are
    /// not shown in the "Звёзды" settings screen.
    public static var hideExpiredStarSubscriptionsEnabled: Bool {
        get { return UserDefaults.standard.bool(forKey: hideExpiredStarSubscriptionsKey) }
        set { UserDefaults.standard.set(newValue, forKey: hideExpiredStarSubscriptionsKey) }
    }

    /// "Отключение рекламы" — when enabled (the default), the client never
    /// requests or displays sponsored messages (channel ads) nor sponsored
    /// search peers. Because no request is made, no view/click tracking is sent
    /// either. Stored device-local; default `true` (ads off out of the box).
    public static var adsDisabledEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: adsDisabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: adsDisabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: adsDisabledKey) }
    }

    /// "Качество отправляемых медиа" — global compression strength for outgoing
    /// photos and videos. 0 = strongest compression (smallest/lowest quality),
    /// 3 = best quality. Default 1 (matches stock Telegram behaviour: photo JPEG
    /// 60%, video ~Medium preset) so nothing changes until the user moves the
    /// slider. Stored device-local; readable from the legacy send pipeline.
    public static var mediaCompressionLevel: Int {
        get {
            if UserDefaults.standard.object(forKey: mediaCompressionLevelKey) == nil {
                return 1
            }
            return max(0, min(3, UserDefaults.standard.integer(forKey: mediaCompressionLevelKey)))
        }
        set { UserDefaults.standard.set(max(0, min(3, newValue)), forKey: mediaCompressionLevelKey) }
    }

    /// JPEG quality (0...1) applied to outgoing photos for the current
    /// `mediaCompressionLevel`. Level 1 keeps the stock 0.6.
    public static var mediaCompressionPhotoQuality: Float {
        switch self.mediaCompressionLevel {
        case 0: return 0.4
        case 2: return 0.8
        case 3: return 0.92
        default: return 0.6
        }
    }

    /// `TGMediaVideoConversionPreset` raw value matching the current
    /// `mediaCompressionLevel` (1 = VeryLow/480p … 5 = VeryHigh/1920p). Used to
    /// seed the legacy `TG_preferredVideoPreset_v0` default.
    public static var mediaCompressionVideoPresetRawValue: Int32 {
        switch self.mediaCompressionLevel {
        case 0: return 1
        case 2: return 4
        case 3: return 5
        default: return 3
        }
    }

    public static func hideStarSubscription(id: String) {
        var ids = self.hiddenStarSubscriptionIds
        ids.insert(id)
        self.hiddenStarSubscriptionIds = ids
    }

    /// Clears all hidden Star subscriptions ("Сбросить скрытые подписки").
    public static func resetHiddenStarSubscriptions() {
        UserDefaults.standard.removeObject(forKey: hiddenStarSubscriptionsKey)
    }
}
