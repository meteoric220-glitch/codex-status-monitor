import Foundation

public final class StateClassifier {
    private let waitingDetector: WaitingSignalDetector

    public init(waitingDetector: WaitingSignalDetector = WaitingSignalDetector()) {
        self.waitingDetector = waitingDetector
    }

    public func classify(events: [SessionEvent]) -> MonitorStatus {
        let events = latestTurnEvents(from: events)

        guard !events.isEmpty else {
            return .done
        }

        if hasUnresolvedRequestUserInput(events) || hasUnresolvedApprovalRequest(events) {
            return .waiting
        }

        if isWorking(events) {
            return .working
        }

        if let lastAssistantText = lastCompletedAssistantMessage(events),
           waitingDetector.requiresUserResponse(lastAssistantText) {
            return .waiting
        }

        return .done
    }

    private func latestTurnEvents(from events: [SessionEvent]) -> [SessionEvent] {
        guard let latestTaskStartedIndex = events.lastIndex(where: { event in
            if case .taskStarted = event {
                return true
            }
            return false
        }) else {
            return events
        }

        return Array(events[latestTaskStartedIndex...])
    }

    private func hasUnresolvedRequestUserInput(_ events: [SessionEvent]) -> Bool {
        unresolvedFunctionCallIDs(named: "request_user_input", in: events).isEmpty == false
    }

    private func hasUnresolvedApprovalRequest(_ events: [SessionEvent]) -> Bool {
        unresolvedFunctionCalls(in: events).contains { event in
            guard case let .functionCall(_, _, arguments, _) = event,
                  let arguments
            else {
                return false
            }
            return arguments.contains(#""sandbox_permissions":"require_escalated""#)
                || arguments.contains(#""sandbox_permissions": "require_escalated""#)
        }
    }

    private func unresolvedFunctionCallIDs(named name: String, in events: [SessionEvent]) -> Set<String> {
        let outputs = Set(events.compactMap { event -> String? in
            guard case let .functionCallOutput(callID, _) = event else {
                return nil
            }
            return callID
        })

        return Set(events.compactMap { event -> String? in
            guard case let .functionCall(callName, callID, _, _) = event,
                  callName == name,
                  let callID,
                  !outputs.contains(callID)
            else {
                return nil
            }
            return callID
        })
    }

    private func unresolvedFunctionCalls(in events: [SessionEvent]) -> [SessionEvent] {
        let outputs = Set(events.compactMap { event -> String? in
            guard case let .functionCallOutput(callID, _) = event else {
                return nil
            }
            return callID
        })

        return events.filter { event in
            guard case let .functionCall(_, callID, _, _) = event,
                  let callID
            else {
                return false
            }
            return !outputs.contains(callID)
        }
    }

    private func isWorking(_ events: [SessionEvent]) -> Bool {
        var lastTaskStarted: Date?
        var lastTaskCompleted: Date?

        for event in events {
            switch event {
            case let .taskStarted(_, timestamp):
                lastTaskStarted = timestamp
            case let .taskComplete(_, timestamp):
                lastTaskCompleted = timestamp
            case let .assistantMessage(_, phase, timestamp) where phase == "final_answer":
                lastTaskCompleted = timestamp
            default:
                break
            }
        }

        guard let lastTaskStarted else {
            return false
        }

        guard let lastTaskCompleted else {
            return true
        }

        return lastTaskStarted > lastTaskCompleted
    }

    private func lastCompletedAssistantMessage(_ events: [SessionEvent]) -> String? {
        events.reversed().compactMap { event -> String? in
            guard case let .assistantMessage(text, phase, _) = event else {
                return nil
            }
            if phase == nil || phase == "final_answer" {
                return text
            }
            return nil
        }.first
    }
}
