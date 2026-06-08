import Foundation
import Postbox

// Fork: cached previous versions of an edited message (for the edit-history screen)
public final class EditHistoryMessageVersion: PostboxCoding {
    public let text: String
    public let entities: [MessageTextEntity]
    public let media: [Media]
    public let date: Int32

    public init(text: String, entities: [MessageTextEntity], media: [Media], date: Int32) {
        self.text = text
        self.entities = entities
        self.media = media
        self.date = date
    }

    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.entities = decoder.decodeObjectArrayWithDecoderForKey("e")
        self.media = decoder.decodeObjectArrayForKey("m").compactMap { $0 as? Media }
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeObjectArray(self.entities, forKey: "e")
        encoder.encodeGenericObjectArray(self.media.map { $0 as PostboxCoding }, forKey: "m")
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

public final class EditHistoryMessageAttribute: MessageAttribute {
    public let versions: [EditHistoryMessageVersion]

    public init(versions: [EditHistoryMessageVersion]) {
        self.versions = versions
    }

    required public init(decoder: PostboxDecoder) {
        self.versions = decoder.decodeObjectArrayWithDecoderForKey("v")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.versions, forKey: "v")
    }
}
