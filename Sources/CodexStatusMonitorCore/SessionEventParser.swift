import Foundation

public protocol SessionEventParsing {
    func parseEvents(from fileURL: URL) throws -> [SessionEvent]
}

public final class SessionEventParser: SessionEventParsing {
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
              let envelope = try? decoder.decode(EventEnvelope.self, from: data)
        else {
            return nil
        }

        let timestamp = parseDate(envelope.timestamp) ?? Date.distantPast

        if envelope.type == "event_msg" {
            if let eventType = envelope.payload?["type"]?.stringValue {
                if eventType == "task_started" {
                    return .taskStarted(turnID: envelope.payload?["turn_id"]?.stringValue, timestamp: timestamp)
                }
                if eventType == "task_complete" {
                    return .taskComplete(turnID: envelope.payload?["turn_id"]?.stringValue, timestamp: timestamp)
                }
                if eventType == "agent_message",
                   let message = envelope.payload?["message"]?.stringValue {
                    return .assistantMessage(
                        text: message,
                        phase: envelope.payload?["phase"]?.stringValue,
                        timestamp: timestamp
                    )
                }
            }
        }

        if envelope.type == "response_item", let itemType = envelope.payload?["type"]?.stringValue {
            if itemType == "function_call" {
                return .functionCall(
                    name: envelope.payload?["name"]?.stringValue ?? "",
                    callID: envelope.payload?["call_id"]?.stringValue,
                    arguments: envelope.payload?["arguments"]?.stringValue,
                    timestamp: timestamp
                )
            }

            if itemType == "function_call_output" {
                return .functionCallOutput(
                    callID: envelope.payload?["call_id"]?.stringValue,
                    timestamp: timestamp
                )
            }

            if itemType == "message", envelope.payload?["role"]?.stringValue == "assistant" {
                let text = extractMessageText(from: envelope.payload?["content"])
                if !text.isEmpty {
                    return .assistantMessage(
                        text: text,
                        phase: envelope.payload?["phase"]?.stringValue,
                        timestamp: timestamp
                    )
                }
            }
        }

        return .other(timestamp: timestamp)
    }

    private func extractMessageText(from json: JSONValue?) -> String {
        guard case let .array(items)? = json else {
            return ""
        }

        return items.compactMap { item -> String? in
            guard case let .object(object) = item else {
                return nil
            }
            return object["text"]?.stringValue
        }
        .joined(separator: "\n")
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

private struct EventEnvelope: Decodable {
    let timestamp: String?
    let type: String
    let payload: [String: JSONValue]?
}

public enum JSONValue: Decodable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    public var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
    }
}
