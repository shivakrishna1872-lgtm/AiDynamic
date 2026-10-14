import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class FirestoreTaskStore: ObservableObject {
    static let shared = FirestoreTaskStore()
    @Published private(set) var pendingTasks: [ApprovalTask] = []
    @Published var errorMessage: String?
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private init() {}

    var currentUID: String? { Auth.auth().currentUser?.uid }

    func listenForPendingTasks() {
        guard let uid = currentUID else { stopListening(); pendingTasks = []; return }
        stopListening()
        listener = db.collection("approvalTasks")
            .whereField("ownerUID", isEqualTo: uid)
            .whereField("status", isEqualTo: ApprovalTaskStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error { self.errorMessage = error.localizedDescription; return }
                    self.pendingTasks = (snapshot?.documents ?? [])
                        .compactMap { ApprovalTask(documentID: $0.documentID, data: $0.data()) }
                        .sorted { $0.timestamp < $1.timestamp }
                }
            }
    }

    func stopListening() { listener?.remove(); listener = nil }

    func createApprovalTask(actionDescription: String) async throws -> String {
        guard let uid = currentUID else { throw TaskStoreError.signedOut }
        let ref = db.collection("approvalTasks").document()
        try await ref.setData([
            "id": ref.documentID,
            "ownerUID": uid,
            "actionDescription": actionDescription,
            "timestamp": Timestamp(date: Date()),
            "status": ApprovalTaskStatus.pending.rawValue
        ])
        return ref.documentID
    }

    func waitForResolution(taskID: String) async throws -> ApprovalTaskStatus {
        guard let uid = currentUID else { throw TaskStoreError.signedOut }
        let ref = db.collection("approvalTasks").document(taskID)
        return try await withCheckedThrowingContinuation { continuation in
            let waiter = ResolutionWaiter(continuation)
            let registration = ref.addSnapshotListener { snapshot, error in
                if let error { waiter.finish(.failure(error)); return }
                guard let snapshot, snapshot.exists,
                      let task = ApprovalTask(documentID: snapshot.documentID, data: snapshot.data() ?? [:]),
                      task.ownerUID == uid else {
                    waiter.finish(.failure(TaskStoreError.invalidTask)); return
                }
                switch task.status {
                case .pending: break
                case .approved, .declined: waiter.finish(.success(task.status))
                }
            }
            waiter.setRegistration(registration)
        }
    }

    func resolve(task: ApprovalTask, as status: ApprovalTaskStatus) async throws {
        guard status == .approved || status == .declined else { throw TaskStoreError.invalidStatus }
        guard currentUID == task.ownerUID else { throw TaskStoreError.signedOut }
        try await db.collection("approvalTasks").document(task.id)
            .updateData(["status": status.rawValue])
    }
}

private final class ResolutionWaiter {
    private let lock = NSLock()
    private var finished = false
    private let continuation: CheckedContinuation<ApprovalTaskStatus, Error>
    private var registration: ListenerRegistration?

    init(_ continuation: CheckedContinuation<ApprovalTaskStatus, Error>) { self.continuation = continuation }

    func setRegistration(_ registration: ListenerRegistration) {
        lock.lock()
        self.registration = registration
        let removeImmediately = finished
        lock.unlock()
        if removeImmediately { registration.remove() }
    }

    func finish(_ result: Result<ApprovalTaskStatus, Error>) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let registration = self.registration
        lock.unlock()
        registration?.remove()
        continuation.resume(with: result)
    }
}

enum TaskStoreError: LocalizedError {
    case signedOut, invalidTask, invalidStatus
    var errorDescription: String? {
        switch self {
        case .signedOut: return "Sign in on both devices using the same Firebase account."
        case .invalidTask: return "The approval task is missing or invalid."
        case .invalidStatus: return "Only approved or declined are valid resolutions."
        }
    }
}
