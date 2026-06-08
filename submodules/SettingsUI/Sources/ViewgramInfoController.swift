import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import ItemListPeerItem
import PresentationDataUtils
import AccountContext
import UndoUI
import OverlayStatusController

private final class ViewgramInfoControllerArguments {
    let context: AccountContext
    let toggleInvisible: (Bool) -> Void
    let toggleNoReadReceipts: (Bool) -> Void
    let toggleAdsDisabled: (Bool) -> Void
    let toggleHideBotPanel: (Bool) -> Void
    let setMediaQuality: (Int) -> Void
    let toggleHideExpired: (Bool) -> Void
    let resetHiddenSubscriptions: () -> Void
    let openChannel: () -> Void
    let openBot: () -> Void
    let openDeveloperChannel: () -> Void
    let openDeveloper: () -> Void
    let refresh: () -> Void

    init(context: AccountContext, toggleInvisible: @escaping (Bool) -> Void, toggleNoReadReceipts: @escaping (Bool) -> Void, toggleAdsDisabled: @escaping (Bool) -> Void, toggleHideBotPanel: @escaping (Bool) -> Void, setMediaQuality: @escaping (Int) -> Void, toggleHideExpired: @escaping (Bool) -> Void, resetHiddenSubscriptions: @escaping () -> Void, openChannel: @escaping () -> Void, openBot: @escaping () -> Void, openDeveloperChannel: @escaping () -> Void, openDeveloper: @escaping () -> Void, refresh: @escaping () -> Void) {
        self.context = context
        self.toggleInvisible = toggleInvisible
        self.toggleNoReadReceipts = toggleNoReadReceipts
        self.toggleAdsDisabled = toggleAdsDisabled
        self.toggleHideBotPanel = toggleHideBotPanel
        self.setMediaQuality = setMediaQuality
        self.toggleHideExpired = toggleHideExpired
        self.resetHiddenSubscriptions = resetHiddenSubscriptions
        self.openChannel = openChannel
        self.openBot = openBot
        self.openDeveloperChannel = openDeveloperChannel
        self.openDeveloper = openDeveloper
        self.refresh = refresh
    }
}

/// A resolved Viewgram link peer (avatar + optional subscriber count) for the
/// rich `ItemListPeerItem` rows in the links section.
private struct ViewgramResolvedLink: Equatable {
    var peer: EnginePeer?
    var subscribers: Int?
}

private struct ViewgramInfoState: Equatable {
    var invisibleEnabled: Bool
    var noReadReceiptsEnabled: Bool
    var adsDisabledEnabled: Bool
    var hideExpiredEnabled: Bool
    var mediaCompressionLevel: Int
}

private enum ViewgramInfoSection: Int32 {
    case settings
    case mediaQuality
    case links
    case verification
}

private enum ViewgramInfoEntry: ItemListNodeEntry {
    case settingsHeader
    case invisible(Bool)
    case noReadReceipts(Bool)
    case adsDisabled(Bool)
    case hideBotPanel(Bool)
    case hideExpired(Bool)
    case resetHidden
    case settingsFooter
    case mediaQualityHeader
    case mediaQuality(Int)
    case mediaQualityFooter
    case linksHeader
    case channel(EnginePeer?, Int?)
    case bot(EnginePeer?)
    case developerChannel(EnginePeer?, Int?)
    case developer(EnginePeer?)
    case verificationHeader
    case refresh
    case verificationFooter

    var section: ItemListSectionId {
        switch self {
        case .settingsHeader, .invisible, .noReadReceipts, .adsDisabled, .hideBotPanel, .hideExpired, .resetHidden, .settingsFooter:
            return ViewgramInfoSection.settings.rawValue
        case .mediaQualityHeader, .mediaQuality, .mediaQualityFooter:
            return ViewgramInfoSection.mediaQuality.rawValue
        case .linksHeader, .channel, .bot, .developerChannel, .developer:
            return ViewgramInfoSection.links.rawValue
        case .verificationHeader, .refresh, .verificationFooter:
            return ViewgramInfoSection.verification.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .settingsHeader: return 0
        case .invisible: return 1
        case .noReadReceipts: return 2
        case .adsDisabled: return 3
        case .hideBotPanel: return 4
        case .hideExpired: return 5
        case .resetHidden: return 6
        case .settingsFooter: return 7
        case .mediaQualityHeader: return 8
        case .mediaQuality: return 9
        case .mediaQualityFooter: return 10
        case .linksHeader: return 11
        case .channel: return 12
        case .bot: return 13
        case .developerChannel: return 14
        case .developer: return 15
        case .verificationHeader: return 16
        case .refresh: return 17
        case .verificationFooter: return 18
        }
    }

    static func <(lhs: ViewgramInfoEntry, rhs: ViewgramInfoEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ViewgramInfoControllerArguments
        switch self {
        case .settingsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "НАСТРОЙКИ", sectionId: self.section)
        case let .invisible(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Невидимка", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleInvisible(updatedValue)
            })
        case let .noReadReceipts(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Нечиталка", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleNoReadReceipts(updatedValue)
            })
        case let .adsDisabled(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Отключение рекламы", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleAdsDisabled(updatedValue)
            })
        case let .hideBotPanel(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Скрыть панель бота", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleHideBotPanel(updatedValue)
            })
        case let .hideExpired(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Не отображать истекшие подписки", value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleHideExpired(updatedValue)
            })
        case .resetHidden:
            return ItemListActionItem(presentationData: presentationData, title: "Сбросить скрытые подписки", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.resetHiddenSubscriptions()
            })
        case .settingsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Невидимка — никто не видит, что ты в сети.\nНечиталка — собеседники не увидят, что ты прочитал их сообщения (без галочек о прочтении).\nОтключение рекламы — спонсорские сообщения в каналах и в поиске не загружаются и не показываются.\nСкрыть панель бота — прячет панель бизнес-бота вверху чатов; вместо неё показываются закреплённые сообщения."), sectionId: self.section)
        case .mediaQualityHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "КАЧЕСТВО ОТПРАВЛЯЕМЫХ МЕДИА", sectionId: self.section)
        case let .mediaQuality(level):
            return ViewgramMediaQualitySliderItem(theme: presentationData.theme, values: ["40%", "60%", "80%", "100%"], value: level, sectionId: self.section, updated: { newLevel in
                arguments.setMediaQuality(newLevel)
            })
        case .mediaQualityFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Сила сжатия фото и видео при отправке. 40% — максимальная экономия трафика (видео ~480p), 100% — лучшее качество (видео до 1080p). По умолчанию 60%."), sectionId: self.section)
        case .linksHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "VIEWGRAM", sectionId: self.section)
        case let .channel(peer, subscribers):
            return viewgramLinkItem(presentationData: presentationData, context: arguments.context, section: self.section, peer: peer, subscribers: subscribers, fallbackTitle: "Канал @\(viewgramChannelUsername)", action: { arguments.openChannel() })
        case let .bot(peer):
            return viewgramLinkItem(presentationData: presentationData, context: arguments.context, section: self.section, peer: peer, subscribers: nil, fallbackTitle: "Бот @\(viewgramBotUsername)", action: { arguments.openBot() })
        case let .developerChannel(peer, subscribers):
            return viewgramLinkItem(presentationData: presentationData, context: arguments.context, section: self.section, peer: peer, subscribers: subscribers, fallbackTitle: "Канал разработчика @\(viewgramDeveloperChannelUsername)", action: { arguments.openDeveloperChannel() })
        case let .developer(peer):
            return viewgramLinkItem(presentationData: presentationData, context: arguments.context, section: self.section, peer: peer, subscribers: nil, fallbackTitle: "Разработчик @\(viewgramDeveloperUsername)", action: { arguments.openDeveloper() })
        case .verificationHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ВЕРИФИКАЦИЯ", sectionId: self.section)
        case .refresh:
            return ItemListActionItem(presentationData: presentationData, title: "Обновить список верифицированных", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.refresh()
            })
        case .verificationFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Список галочек обновляется автоматически. Нажми, чтобы обновить вручную."), sectionId: self.section)
        }
    }
}

/// Builds a rich avatar row (`ItemListPeerItem`) for a resolved Viewgram link,
/// falling back to a plain disclosure row while the peer is still resolving.
private func viewgramLinkItem(presentationData: ItemListPresentationData, context: AccountContext, section: ItemListSectionId, peer: EnginePeer?, subscribers: Int?, fallbackTitle: String, action: @escaping () -> Void) -> ListViewItem {
    guard let peer else {
        return ItemListDisclosureItem(presentationData: presentationData, title: fallbackTitle, label: "", sectionId: section, style: .blocks, action: action)
    }
    let text: ItemListPeerItemText
    if let subscribers {
        text = .text(presentationData.strings.Conversation_StatusSubscribers(Int32(clamping: subscribers)), .secondary)
    } else if let addressName = peer.addressName, !addressName.isEmpty {
        text = .text("@\(addressName)", .secondary)
    } else {
        text = .none
    }
    return ItemListPeerItem(
        presentationData: presentationData,
        dateTimeFormat: presentationData.dateTimeFormat,
        nameDisplayOrder: presentationData.nameDisplayOrder,
        context: context,
        peer: peer,
        presence: nil,
        text: text,
        label: .none,
        editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false),
        enabled: true,
        selectable: true,
        sectionId: section,
        action: action,
        setPeerIdWithRevealedOptions: { _, _ in },
        removePeer: { _ in }
    )
}

private func viewgramInfoControllerEntries(state: ViewgramInfoState, hideBotPanel: Bool, links: [ViewgramResolvedLink]) -> [ViewgramInfoEntry] {
    return [
        .settingsHeader,
        .invisible(state.invisibleEnabled),
        .noReadReceipts(state.noReadReceiptsEnabled),
        .adsDisabled(state.adsDisabledEnabled),
        .hideBotPanel(hideBotPanel),
        .hideExpired(state.hideExpiredEnabled),
        .resetHidden,
        .settingsFooter,
        .mediaQualityHeader,
        .mediaQuality(state.mediaCompressionLevel),
        .mediaQualityFooter,
        .linksHeader,
        .channel(links[0].peer, links[0].subscribers),
        .bot(links[1].peer),
        .developerChannel(links[2].peer, links[2].subscribers),
        .developer(links[3].peer),
        .verificationHeader,
        .refresh,
        .verificationFooter
    ]
}

public func viewgramInfoController(context: AccountContext) -> ViewController {
    let resolveDisposable = MetaDisposable()

    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?

    let statePromise = ValuePromise(ViewgramInfoState(invisibleEnabled: ViewgramRuntimeSettings.invisibleEnabled, noReadReceiptsEnabled: ViewgramRuntimeSettings.noReadReceiptsEnabled, adsDisabledEnabled: ViewgramRuntimeSettings.adsDisabledEnabled, hideExpiredEnabled: ViewgramRuntimeSettings.hideExpiredStarSubscriptionsEnabled, mediaCompressionLevel: ViewgramRuntimeSettings.mediaCompressionLevel), ignoreRepeated: true)

    let updateState: () -> Void = {
        statePromise.set(ViewgramInfoState(invisibleEnabled: ViewgramRuntimeSettings.invisibleEnabled, noReadReceiptsEnabled: ViewgramRuntimeSettings.noReadReceiptsEnabled, adsDisabledEnabled: ViewgramRuntimeSettings.adsDisabledEnabled, hideExpiredEnabled: ViewgramRuntimeSettings.hideExpiredStarSubscriptionsEnabled, mediaCompressionLevel: ViewgramRuntimeSettings.mediaCompressionLevel))
    }

    let openUsername: (String) -> Void = { username in
        let statusController = OverlayStatusController(theme: context.sharedContext.currentPresentationData.with { $0 }.theme, type: .loading(cancelled: nil))
        presentControllerImpl?(statusController, nil)
        resolveDisposable.set((context.engine.peers.resolvePeerByName(name: username, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            guard case let .result(peer) = result else {
                return .complete()
            }
            return .single(peer)
        }
        |> deliverOnMainQueue).start(next: { [weak statusController] peer in
            statusController?.dismiss()
            if let peer = peer, let navigationController = getNavigationControllerImpl?() {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
            }
        }))
    }

    let arguments = ViewgramInfoControllerArguments(context: context, toggleInvisible: { value in
        ViewgramRuntimeSettings.invisibleEnabled = value
        // Apply immediately: when enabling, go offline right away; when disabling,
        // restore online presence (the screen is shown in the foreground).
        context.account.shouldKeepOnlinePresence.set(.single(!value))
        updateState()
    }, toggleNoReadReceipts: { value in
        ViewgramRuntimeSettings.noReadReceiptsEnabled = value
        updateState()
    }, toggleAdsDisabled: { value in
        ViewgramRuntimeSettings.adsDisabledEnabled = value
        updateState()
    }, toggleHideBotPanel: { value in
        // Synced chat setting (accountManager), drives ChatbotSetupScreen + the in-chat managing-bot panel.
        let _ = updateChatSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            return settings.withUpdatedHideBusinessBotPanel(value)
        }).startStandalone()
    }, setMediaQuality: { level in
        ViewgramRuntimeSettings.mediaCompressionLevel = level
        // Seed the legacy video-preset default (TG_preferredVideoPreset_v0) so outgoing
        // videos pick up the new compression strength across the whole send pipeline,
        // including the Obj-C converter. Photos read mediaCompressionPhotoQuality directly.
        UserDefaults.standard.set(Int(ViewgramRuntimeSettings.mediaCompressionVideoPresetRawValue), forKey: "TG_preferredVideoPreset_v0")
        updateState()
    }, toggleHideExpired: { value in
        ViewgramRuntimeSettings.hideExpiredStarSubscriptionsEnabled = value
        updateState()
    }, resetHiddenSubscriptions: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let hadHidden = !ViewgramRuntimeSettings.hiddenStarSubscriptionIds.isEmpty
        ViewgramRuntimeSettings.resetHiddenStarSubscriptions()
        let content: UndoOverlayContent
        if hadHidden {
            content = .succeed(text: "Скрытые подписки восстановлены.", timeout: 2.0, customUndoText: nil)
        } else {
            content = .info(title: nil, text: "Скрытых подписок нет.", timeout: 2.0, customUndoText: nil)
        }
        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, action: { _ in return false }), nil)
    }, openChannel: {
        openUsername(viewgramChannelUsername)
    }, openBot: {
        openUsername(viewgramBotUsername)
    }, openDeveloperChannel: {
        openUsername(viewgramDeveloperChannelUsername)
    }, openDeveloper: {
        openUsername(viewgramDeveloperUsername)
    }, refresh: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let isAdmin = viewgramIsAdmin(userId: context.account.peerId.id._internalGetInt64Value())
        viewgramForceRefresh(unlimited: isAdmin, completion: { success in
            let content: UndoOverlayContent
            if success {
                content = .succeed(text: "Список верифицированных обновлён.", timeout: 2.0, customUndoText: nil)
            } else {
                content = .info(title: nil, text: "Не удалось обновить. Проверь соединение и попробуй чуть позже.", timeout: 2.0, customUndoText: nil)
            }
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, action: { _ in return false }), nil)
        })
    })

    let hideBotPanelSignal = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.chatSettings])
    |> map { sharedData -> Bool in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.chatSettings]?.get(ChatSettings.self) ?? ChatSettings.defaultSettings
        return settings.hideBusinessBotPanel
    }

    // Resolve each Viewgram link username to a peer (and subscriber count for
    // channels) so the links section can show rich avatar rows. Emits a nil peer
    // immediately so the rows render (as plain disclosure fallback) before the
    // network resolution completes.
    let resolveLink: (String, Bool) -> Signal<ViewgramResolvedLink, NoError> = { username, withSubscribers in
        return context.engine.peers.resolvePeerByName(name: username, referrer: nil)
        |> mapToSignal { result -> Signal<ViewgramResolvedLink, NoError> in
            guard case let .result(maybePeer) = result, let peer = maybePeer else {
                return .single(ViewgramResolvedLink(peer: nil, subscribers: nil))
            }
            if withSubscribers {
                return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peer.id))
                |> map { count -> ViewgramResolvedLink in
                    return ViewgramResolvedLink(peer: peer, subscribers: count)
                }
            } else {
                return .single(ViewgramResolvedLink(peer: peer, subscribers: nil))
            }
        }
    }

    let linksSignal: Signal<[ViewgramResolvedLink], NoError> = combineLatest([
        resolveLink(viewgramChannelUsername, true),
        resolveLink(viewgramBotUsername, false),
        resolveLink(viewgramDeveloperChannelUsername, true),
        resolveLink(viewgramDeveloperUsername, false)
    ])

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get(), hideBotPanelSignal, linksSignal)
    |> deliverOnMainQueue
    |> map { presentationData, state, hideBotPanel, links -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Viewgram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: viewgramInfoControllerEntries(state: state, hideBotPanel: hideBotPanel, links: links), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        resolveDisposable.dispose()
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}
