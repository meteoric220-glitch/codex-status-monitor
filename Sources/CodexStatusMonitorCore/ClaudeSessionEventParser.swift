import Foundation

public final class ClaudeSessionEventParser: SessionEventParsing {
    private let decoder = JSONDecoder()
    private let isoFormatter = ISO8601DateFormatter()

    public init() {
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    public func parseEvents(from fileURL: URL) throws -> [SessionEvent] {
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        return contents
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseLine(String($0)) }
    }

    public func parseLine(_ line: String) -> SessionEvent? {
        guard let data = line.data(using: .utf8),
              let envelope = try? decoder.decode(ClaudeEventEnvelope.self, from: data)
        else {
            return nil
        }

        let timestamp = parseDate(envelope.timestamp) ?? Date.distantPast
        if envelope.isSidechain == true {
            return .other(timestamp: timestamp)
        }

        switch envelope.type {
        case "user":
            return parseUserEvent(envelope, timestamp: timestamp)
        case "assistant":
            return parseAssistantEvent(envelope, timestamp: timestamp)
        case "system":
            if envelope.subtype == "turn_duration" {
                return .taskComplete(turnID: envelope.uuid, timestamp: timestamp)
            }
            return .other(timestamp: timestamp)
        default:
            return .other(timestamp: timestamp)
        }
    }

    public func metadata(from fileURL: URL) throws -> ClaudeTranscriptMetadata? {
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        var metadata: ClaudeTranscriptMetadata?

        for line in contents.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineMetadata = parseMetadataLine(String(line)) else {
                continue
            }

            if let existing = metadata, existing.updatedAt >= lineMetadata.updatedAt {
                continue
            }
            metadata = lineMetadata
        }

        return metadata
    }

    private func parseMetadataLine(_ line: String) -> ClaudeTranscriptMetadata? {
        guard let data = line.data(using: .utf8),
              let envelope = try? decoder.decode(ClaudeEventEnvelope.self, from: data),
              envelope.isSidechain != true,
              let cwd = envelope.cwd,
              let sessionID = envelope.sessionId
        else {
            return nil
        }

        let timestamp = parseDate(envelope.timestamp) ?? Date.distantPast
        return ClaudeTranscriptMetadata(
            sessionID: sessionID,
            cwd: URL(fileURLWithPath: cwd).standardizedFileURL,
            updatedAt: timestamp
        )
    }

    private func parseUserEvent(_ envelope: ClaudeEventEnvelope, timestamp: Date) -> SessionEvent {
        guard let message = envelope.message else {
            return .other(timestamp: timestamp)
        }

        if isInterruptedRequest(message.content) {
            return .taskComplete(turnID: envelope.promptId ?? envelope.uuid, timestamp: timestamp)
        }

        if let toolResultID = firstToolResultID(in: message.content) {
            return .functionCallOutput(callID: toolResultID, timestamp: timestamp)
        }

        if containsUserText(in: message.content) {
            return .taskStarted(turnID: envelope.promptId ?? envelope.uuid, timestamp: timestamp)
        }

        return .other(timestamp: timestamp)
    }

    private func isInterruptedRequest(_ content: ClaudeMessageContent?) -> Bool {
        guard let content else {
            return false
        }

        let text: String
        switch content {
        case let .string(value):
            text = value
        case let .array(items):
            text = items.compactMap { $0.text }.joined(separator: "\n")
        }

        return text.contains("[Request interrupted by user")
    }

    private func parseAssistantEvent(_ envelope: ClaudeEventEnvelope, timestamp: Date) -> SessionEvent {
        guard let message = envelope.message else {
            return .other(timestamp: timestamp)
        }

        if let toolUse = firstToolUse(in: message.content) {
            return .functionCall(
                name: normalizedToolName(toolUse.name),
                callID: toolUse.id,
                arguments: toolUse.input?.compactJSONString,
                timestamp: timestamp
            )
        }

        let text = textContent(in: message.content)
        if !text.isEmpty {
            let phase = message.stopReason == "end_turn" ? "final_answer" : nil
            return .assistantMessage(text: text, phase: phase, timestamp: timestamp)
        }

        if message.stopReason == "end_turn" {
            return .taskComplete(turnID: envelope.uuid, timestamp: timestamp)
        }

        return .other(timestamp: timestamp)
    }

    private func firstToolResultID(in content: ClaudeMessageContent?) -> String? {
        guard let content else {
            return nil
        }

        switch content {
        case .string:
            return nil
        case let .array(items):
            return items.compactMap { item -> String? in
                guard item.type == "tool_result" else {
                    return nil
                }
                return item.toolUseID
            }.first
        }
    }

    private func firstToolUse(in content: ClaudeMessageContent?) -> ClaudeContentItem? {
        guard let content else {
            return nil
        }

        switch content {
        case .string:
            return nil
        case let .array(items):
            return items.first { $0.type == "tool_use" }
        }
    }

    private func normalizedToolName(_ name: String?) -> String {
        guard let name else {
            return ""
        }

        switch name {
        case "ExitPlanMode", "AskUserQuestion":
            return "request_user_input"
        default:
            return name
        }
    }

    private func containsUserText(in content: ClaudeMessageContent?) -> Bool {
        guard let content else {
            return false
        }

        switch content {
        case let .string(text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case let .array(items):
            return items.contains { item in
                guard item.type == "text" else {
                    return false
                }
                return item.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
        }
    }

    private func textContent(in content: ClaudeMessageContent?) -> String {
        guard let content else {
            return ""
        }

        switch content {
        case let .string(text):
            return text
        case let .array(items):
            return items.compactMap { item -> String? in
                guard item.type == "text" else {
                    return nil
                }
                return item.text
            }
            .joined(separator: "\n")
        }
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: value)
    }
}

public struct ClaudeTranscriptMetadata: Equatable, Sendable {
    public let sessionID: String
    public let cwd: URL
    public let updatedAt: Date

    public init(sessionID: String, cwd: URL, updatedAt: Date) {
        self.sessionID = sessionID
        self.cwd = cwd
        self.updatedAt = updatedAt
    }
}

private struct ClaudeEventEnvelope: Decodable {
    let type: String
    let subtype: String?
    let isSidechain: Bool?
    let uuid: String?
    let promptId: String?
    let sessionId: String?
    let timestamp: String?
    let cwd: String?
    let message: ClaudeMessage?

    enum CodingKeys: String, CodingKey {
        case type
        case subtype
        case isSidechain
        case uuid
        case promptId
        case sessionId
        case timestamp
        case cwd
        case message
    }
}

private struct ClaudeMessage: Decodable {
    let role: String?
    let content: ClaudeMessageContent?
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case stopReason = "stop_reason"
    }
}

private enum ClaudeMessageContent: Decodable {
    case string(String)
    case array([ClaudeContentItem])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .array((try? container.decode([ClaudeContentItem].self)) ?? [])
        }
    }
}

private struct ClaudeContentItem: Decodable {
    let type: String?
    let text: String?
    let id: String?
    let name: String?
    let input: JSONValue?
    let toolUseID: String?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case id
        case name
        case input
        case toolUseID = "tool_use_id"
    }
}

private extension JSONValue {
    var compactJSONString: String? {
        guard let object = jsonObject else {
            return nil
        }

        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    var jsonObject: Any? {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            return value
        case let .bool(value):
            return value
        case let .object(value):
            return value.compactMapValues { $0.jsonObject }
        case let .array(value):
            return value.compactMap { $0.jsonObject }
        case .null:
            return NSNull()
        }
    }
}
