import Foundation
import FirebaseFirestore

enum ApprovalTaskStatus: String, Codable {
    case pending
    case approved
    case declined
}

struct ApprovalTask: Identifiable {
    let id: String
    let ownerUID: String
    let actionDescription: String
    let timestamp: Date
    let status: ApprovalTaskStatus

    init?(documentID: String, data: [String: Any]) {
        guard
            let ownerUID = data["ownerUID"] as? String,
            let actionDescription = data["actionDescription"] as? String,
            let timestamp = data["timestamp"] as? Timestamp,
            let rawStatus = data["status"] as? String,
            let status = ApprovalTaskStatus(rawValue: rawStatus)
        else { return nil }

        id = documentID
        self.ownerUID = ownerUID
        self.actionDescription = actionDescription
        self.timestamp = timestamp.dateValue()
        self.status = status
    }
}
