import Foundation
import Postbox

// Fork: marker for messages that were deleted by others/admins/author but kept locally
public class GloballyDeletedMessageAttribute: MessageAttribute {
    public init() {
    }

    required public init(decoder: PostboxDecoder) {
    }

    public func encode(_ encoder: PostboxEncoder) {
    }
}
