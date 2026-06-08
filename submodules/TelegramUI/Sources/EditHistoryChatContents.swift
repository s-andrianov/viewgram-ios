import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

// Fork: read-only chat contents showing the cached edit history of a message as separate version bubbles
final class EditHistoryChatContents: ChatCustomContentsProtocol {
    var kind: ChatCustomContentsKind
    private let messages: [Message]

    var historyView: Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        let entries = self.messages.map { message in
            MessageHistoryEntry(message: message, isRead: true, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false))
        }
        let view = MessageHistoryView(tag: nil, namespaces: .all, entries: entries, holeEarlier: false, holeLater: false, isLoading: false)
        return .single((view, .Initial))
    }

    var messageLimit: Int? {
        return nil
    }

    init(context: AccountContext, message: Message, versions: [EditHistoryMessageVersion]) {
        self.kind = .messageEditHistory

        var snapshots: [(text: String, entities: [MessageTextEntity], media: [Media], date: Int32)] = versions.map { ($0.text, $0.entities, $0.media, $0.date) }
        let currentEntities = (message.attributes.first(where: { $0 is TextEntitiesMessageAttribute }) as? TextEntitiesMessageAttribute)?.entities ?? []
        let currentDate = (message.attributes.first(where: { $0 is EditedMessageAttribute }) as? EditedMessageAttribute)?.date ?? message.timestamp
        snapshots.append((message.text, currentEntities, message.media, currentDate))

        var messages: [Message] = []
        var idValue: Int32 = 1
        for snapshot in snapshots {
            var attributes: [MessageAttribute] = []
            if !snapshot.entities.isEmpty {
                attributes.append(TextEntitiesMessageAttribute(entities: snapshot.entities))
            }
            var associatedMedia = message.associatedMedia
            for media in snapshot.media {
                if let id = media.id {
                    associatedMedia[id] = media
                }
            }
            let synthetic = Message(
                stableId: UInt32(idValue),
                stableVersion: 0,
                id: MessageId(peerId: message.id.peerId, namespace: Namespaces.Message.Local, id: idValue),
                globallyUniqueId: nil,
                groupingKey: nil,
                groupInfo: nil,
                threadId: nil,
                timestamp: snapshot.date,
                flags: [.Incoming],
                tags: [],
                globalTags: [],
                localTags: [],
                customTags: [],
                forwardInfo: nil,
                author: message.author,
                text: snapshot.text,
                attributes: attributes,
                media: snapshot.media,
                peers: message.peers,
                associatedMessages: message.associatedMessages,
                associatedMessageIds: message.associatedMessageIds,
                associatedMedia: associatedMedia,
                associatedThreadInfo: message.associatedThreadInfo,
                associatedStories: message.associatedStories
            )
            messages.append(synthetic)
            idValue += 1
        }
        self.messages = messages
    }

    func enqueueMessages(messages: [EnqueueMessage]) {
    }

    func deleteMessages(ids: [EngineMessage.Id]) {
    }

    func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
    }

    func quickReplyUpdateShortcut(value: String) {
    }

    func businessLinkUpdate(message: String, entities: [MessageTextEntity], title: String?) {
    }

    func loadMore() {
    }

    func hashtagSearchUpdate(query: String) {
    }

    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }
}
