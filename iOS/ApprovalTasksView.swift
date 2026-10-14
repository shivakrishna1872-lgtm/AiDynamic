import SwiftUI

@MainActor
final class ApprovalTasksViewModel: ObservableObject {
    @Published private(set) var tasks: [ApprovalTask] = []
    @Published private(set) var busyIDs = Set<String>()
    @Published var errorMessage: String?

    private var store: FirestoreTaskStore { .shared }

    func start() { store.listenForPendingTasks() }
    func stop() { store.stopListening() }

    func decide(_ task: ApprovalTask, as status: ApprovalTaskStatus) async {
        guard !busyIDs.contains(task.id) else { return }
        busyIDs.insert(task.id)
        defer { busyIDs.remove(task.id) }
        do { try await store.resolve(task: task, as: status); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
}

struct ApprovalTasksView: View {
    let ownerUID: String
    @StateObject private var model = ApprovalTasksViewModel()
    @StateObject private var auth = AuthSession.shared
    @ObservedObject private var store = FirestoreTaskStore.shared
    @ObservedObject private var push = PushNotifications.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                PhoneIslandCompanionStage(isWaitingForApproval: !store.pendingTasks.isEmpty)
                    .padding(.top, 6)

                HStack(spacing: 12) {
                    DotBuddyAvatar(mood: store.pendingTasks.isEmpty ? .idle : .waiting)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Island Agent").font(.headline)
                        Text(store.pendingTasks.isEmpty ? "All clear" : "Approval needed")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Sign Out") {
                        do { try auth.signOut() }
                        catch { model.errorMessage = error.localizedDescription }
                    }
                    .font(.caption)
                }
                .padding(.horizontal)

                if !push.permissionGranted {
                    Button {
                        Task { await push.enableNotifications() }
                    } label: {
                        Label("Enable notifications when away", systemImage: "bell.badge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }

                if let error = model.errorMessage ?? store.errorMessage ?? push.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red).padding(.horizontal)
                }

                if store.pendingTasks.isEmpty {
                    ContentUnavailableView("No Pending Actions", systemImage: "checkmark.circle",
                                           description: Text("New Mac actions appear here in real time."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(store.pendingTasks) { task in
                                ApprovalCard(
                                    task: task,
                                    busy: model.busyIDs.contains(task.id),
                                    allow: { Task { await model.decide(task, as: .approved) } },
                                    decline: { Task { await model.decide(task, as: .declined) } }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Approvals")
            .task { model.start() }
            .onDisappear { model.stop() }
        }
    }
}

private struct ApprovalCard: View {
    let task: ApprovalTask
    let busy: Bool
    let allow: () -> Void
    let decline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(task.actionDescription).font(.headline).fixedSize(horizontal: false, vertical: true)
            Text(task.timestamp, style: .date).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Decline", action: decline).frame(maxWidth: .infinity).buttonStyle(.bordered)
                Button("Allow", action: allow).frame(maxWidth: .infinity).buttonStyle(.borderedProminent)
            }
            .disabled(busy)
            if busy { ProgressView().frame(maxWidth: .infinity) }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.1), lineWidth: 1))
    }
}
