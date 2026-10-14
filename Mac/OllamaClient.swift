import Foundation

struct OllamaClient {
    let endpoint = URL(string: "http://localhost:11434/api/chat")!
    let model = "llama3.1"

    struct Message: Codable {
        var role: String
        var content: String?
        var toolCalls: [ToolCall]?
        var toolName: String?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
            case toolName = "tool_name"
        }
    }

    struct ToolCall: Codable {
        struct Function: Codable {
            let name: String
            let arguments: [String: JSONValue]
        }
        let function: Function
    }

    struct Request: Encodable {
        let model: String
        let messages: [Message]
        let tools: [ToolDefinition]
        let stream: Bool
    }

    struct ToolDefinition: Encodable {
        let type = "function"
        let function: Function
        struct Function: Encodable {
            let name: String
            let description: String
            let parameters: [String: JSONValue]
        }
    }

    struct Chunk: Decodable {
        struct ResponseMessage: Decodable {
            let role: String?
            let content: String?
            let toolCalls: [ToolCall]?
            enum CodingKeys: String, CodingKey {
                case role, content
                case toolCalls = "tool_calls"
            }
        }
        let message: ResponseMessage?
        let done: Bool?
        let error: String?
    }

    private struct ToolCallRequest: Encodable {
        let function: Function
        struct Function: Encodable {
            let name: String
            let arguments: [String: JSONValue]
        }
    }

    private struct HistoryMessage: Encodable {
        let role: String
        let content: String?
        let toolCalls: [ToolCallRequest]?
        let toolName: String?
        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
            case toolName = "tool_name"
        }
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [HistoryMessage]
        let tools: [ToolDefinition]
        let stream: Bool
    }

    enum JSONValue: Codable {
        case object([String: JSONValue]), array([JSONValue]), string(String)
        case integer(Int64), number(Double), bool(Bool), null

        init(from decoder: Decoder) throws {
            let box = try decoder.singleValueContainer()
            if box.decodeNil() { self = .null }
            else if let v = try? box.decode(Bool.self) { self = .bool(v) }
            else if let v = try? box.decode(Int64.self) { self = .integer(v) }
            else if let v = try? box.decode(Double.self) { self = .number(v) }
            else if let v = try? box.decode(String.self) { self = .string(v) }
            else if let v = try? box.decode([JSONValue].self) { self = .array(v) }
            else if let v = try? box.decode([String: JSONValue].self) { self = .object(v) }
            else { throw DecodingError.dataCorruptedError(in: box, debugDescription: "Invalid JSON value") }
        }
        func encode(to encoder: Encoder) throws {
            var box = encoder.singleValueContainer()
            switch self {
            case .object(let v): try box.encode(v)
            case .array(let v): try box.encode(v)
            case .string(let v): try box.encode(v)
            case .integer(let v): try box.encode(v)
            case .number(let v): try box.encode(v)
            case .bool(let v): try box.encode(v)
            case .null: try box.encodeNil()
            }
        }
    }

    enum OllamaError: LocalizedError {
        case badHTTP(Int), server(String), invalidTool, tooManyRounds
        var errorDescription: String? {
            switch self {
            case .badHTTP(let code): return "Ollama returned HTTP \\(code). Is it running locally?"
            case .server(let message): return message
            case .invalidTool: return "Ollama requested an unsupported or invalid local action."
            case .tooManyRounds: return "Stopped after too many tool-call rounds."
            }
        }
    }

    private let toolDefinitions: [ToolDefinition] = [
        ToolDefinition(function: .init(
            name: "create_note",
            description: "Create a plain-text note in the app's private Notes folder. Requires user approval.",
            parameters: ["type": .string("object"), "required": .array([.string("title"), .string("content")]),
                         "properties": .object(["title": .object(["type": .string("string")]), "content": .object(["type": .string("string")])])]
        )),
        ToolDefinition(function: .init(
            name: "delete_note",
            description: "Delete a note by its exact filename from the app's private Notes folder. Requires user approval.",
            parameters: ["type": .string("object"), "required": .array([.string("filename")]),
                         "properties": .object(["filename": .object(["type": .string("string")])])]
        ))
    ]

    func respond(to prompt: String, onText: @escaping @MainActor (String) -> Void,
                 onApproval: @escaping @MainActor (String) async throws -> Bool) async throws {
        var messages: [HistoryMessage] = [
            HistoryMessage(role: "system", content: "You are a private local assistant. For any note creation or deletion, call the appropriate tool. Never claim a tool succeeded before receiving its result. Tool actions require human approval.", toolCalls: nil, toolName: nil),
            HistoryMessage(role: "user", content: prompt, toolCalls: nil, toolName: nil)
        ]

        for _ in 0..<4 {
            let streamResult = try await stream(messages: messages, onText: onText)
            let callRequests = streamResult.calls.map {
                ToolCallRequest(function: .init(name: $0.function.name, arguments: $0.function.arguments))
            }
            messages.append(HistoryMessage(role: "assistant", content: streamResult.text, toolCalls: callRequests.isEmpty ? nil : callRequests, toolName: nil))
            guard !streamResult.calls.isEmpty else { return }

            for call in streamResult.calls {
                guard let description = Self.actionDescription(for: call) else { throw OllamaError.invalidTool }
                let allowed = try await onApproval(description)
                guard allowed else {
                    messages.append(HistoryMessage(role: "tool", content: "User declined this action.", toolCalls: nil, toolName: call.function.name))
                    continue
                }
                let result = try Self.perform(call)
                messages.append(HistoryMessage(role: "tool", content: result, toolCalls: nil, toolName: call.function.name))
            }
        }
        throw OllamaError.tooManyRounds
    }

    private func stream(messages: [HistoryMessage], onText: @escaping @MainActor (String) -> Void) async throws -> (text: String, calls: [ToolCall]) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(model: model, messages: messages, tools: toolDefinitions, stream: true))
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaError.badHTTP(-1) }
        guard (200..<300).contains(http.statusCode) else { throw OllamaError.badHTTP(http.statusCode) }

        var text = ""
        var calls: [ToolCall] = []
        for try await line in bytes.lines where !line.isEmpty {
            let chunk = try JSONDecoder().decode(Chunk.self, from: Data(line.utf8))
            if let error = chunk.error { throw OllamaError.server(error) }
            if let fragment = chunk.message?.content, !fragment.isEmpty {
                text += fragment
                await onText(fragment)
            }
            if let receivedCalls = chunk.message?.toolCalls { calls.append(contentsOf: receivedCalls) }
        }
        return (text, calls)
    }

    private static func actionDescription(for call: ToolCall) -> String? {
        switch call.function.name {
        case "create_note":
            guard case .string(let title)? = call.function.arguments["title"],
                  case .string(let content)? = call.function.arguments["content"],
                  !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  title.count <= 100, content.count <= 20_000 else { return nil }
            return "Create note ‘\\(title)’ (\\(content.count) characters)"
        case "delete_note":
            guard case .string(let filename)? = call.function.arguments["filename"],
                  Self.isSafeFilename(filename) else { return nil }
            return "Delete note ‘\\(filename)’ from the app’s Notes folder"
        default: return nil
        }
    }

    private static func perform(_ call: ToolCall) throws -> String {
        let directory = try notesDirectory()
        switch call.function.name {
        case "create_note":
            guard case .string(let title)? = call.function.arguments["title"],
                  case .string(let content)? = call.function.arguments["content"],
                  title.count <= 100, content.count <= 20_000 else { throw OllamaError.invalidTool }
            let filename = safeSlug(title) + ".txt"
            let url = directory.appendingPathComponent(filename).standardizedFileURL
            guard url.deletingLastPathComponent() == directory.standardizedFileURL else { throw OllamaError.invalidTool }
            try content.write(to: url, atomically: true, encoding: .utf8)
            return "Created note \\(filename)."
        case "delete_note":
            guard case .string(let filename)? = call.function.arguments["filename"], isSafeFilename(filename) else { throw OllamaError.invalidTool }
            let url = directory.appendingPathComponent(filename).standardizedFileURL
            guard url.deletingLastPathComponent() == directory.standardizedFileURL,
                  FileManager.default.fileExists(atPath: url.path) else { throw OllamaError.invalidTool }
            try FileManager.default.removeItem(at: url)
            return "Deleted note \\(filename)."
        default: throw OllamaError.invalidTool
        }
    }

    private static func notesDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("IslandAgent/Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func isSafeFilename(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 120 && name.hasSuffix(".txt") &&
        name == URL(fileURLWithPath: name).lastPathComponent && !name.contains("/") && !name.contains("\\\\")
    }

    private static func safeSlug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let filtered = String(value.unicodeScalars.filter { allowed.contains($0) })
        let slug = filtered.replacingOccurrences(of: " ", with: "-").trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String((slug.isEmpty ? "note" : slug).prefix(80))
    }
}
