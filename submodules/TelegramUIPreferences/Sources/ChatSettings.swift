import Foundation
import TelegramCore
import SwiftSignalKit

public struct ChatSettings: Codable, Equatable {
    public let sendWithCmdEnter: Bool
    public let hideBusinessBotPanel: Bool

    public static var defaultSettings: ChatSettings {
        return ChatSettings(sendWithCmdEnter: false, hideBusinessBotPanel: false)
    }

    public init(sendWithCmdEnter: Bool, hideBusinessBotPanel: Bool) {
        self.sendWithCmdEnter = sendWithCmdEnter
        self.hideBusinessBotPanel = hideBusinessBotPanel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.sendWithCmdEnter = (try container.decode(Int32.self, forKey: "sendWithCmdEnter")) != 0
        self.hideBusinessBotPanel = (try container.decodeIfPresent(Int32.self, forKey: "hideBusinessBotPanel") ?? 0) != 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.sendWithCmdEnter ? 1 : 0) as Int32, forKey: "sendWithCmdEnter")
        try container.encode((self.hideBusinessBotPanel ? 1 : 0) as Int32, forKey: "hideBusinessBotPanel")
    }

    public static func ==(lhs: ChatSettings, rhs: ChatSettings) -> Bool {
        return lhs.sendWithCmdEnter == rhs.sendWithCmdEnter && lhs.hideBusinessBotPanel == rhs.hideBusinessBotPanel
    }

    public func withUpdatedSendWithCmdEnter(_ sendWithCmdEnter: Bool) -> ChatSettings {
        return ChatSettings(sendWithCmdEnter: sendWithCmdEnter, hideBusinessBotPanel: self.hideBusinessBotPanel)
    }

    public func withUpdatedHideBusinessBotPanel(_ hideBusinessBotPanel: Bool) -> ChatSettings {
        return ChatSettings(sendWithCmdEnter: self.sendWithCmdEnter, hideBusinessBotPanel: hideBusinessBotPanel)
    }
}

public func updateChatSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (ChatSettings) -> ChatSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.chatSettings, { entry in
            let currentSettings: ChatSettings
            if let entry = entry?.get(ChatSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = ChatSettings.defaultSettings
            }
            return SharedPreferencesEntry(f(currentSettings))
        })
    }
}
