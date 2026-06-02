import CodexStatusMonitorCore
import Foundation

struct CheckRunner {
    private var failures = 0

    mutating func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard !condition() else {
            return
        }

        fputs("FAILED: \(message)\n", stderr)
        failures += 1
    }

    mutating func runWaitingSignalChecks() {
        let detector = WaitingSignalDetector()

        expect(detector.requiresUserResponse("Please confirm this design."), "English confirm keyword")
        expect(detector.requiresUserResponse("Which option should I use?"), "English choice question")
        expect(detector.requiresUserResponse("Let me know what you choose."), "English let-me-know keyword")
        expect(detector.requiresUserResponse("请确认这个方案是否符合你的想法？"), "Chinese confirm keyword")
        expect(detector.requiresUserResponse("你要不要继续？"), "Chinese continue question")
        expect(detector.requiresUserResponse("请选择 A 还是 B？"), "Chinese choose keyword")

        expect(!detector.requiresUserResponse("这个问题为什么会发生？"), "Chinese explanatory question should be done")
        expect(!detector.requiresUserResponse("这意味着什么？"), "Chinese meaning question should be done")
        expect(!detector.requiresUserResponse("Why did this happen?"), "English explanatory question should be done")

        let optionText = """
        Option A keeps the compact capsule.
        Option B expands more often.
        Which one should be used?
        """
        expect(detector.requiresUserResponse(optionText), "Question with options should be waiting")
    }

    mutating func runStateClassifierChecks() {
        let classifier = StateClassifier()
        let baseDate = Date(timeIntervalSince1970: 1000)

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .functionCall(name: "request_user_input", callID: "call-1", arguments: "{}", timestamp: baseDate.addingTimeInterval(1))
            ]) == .waiting,
            "Unresolved request_user_input should be waiting"
        )

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .functionCall(name: "request_user_input", callID: "call-1", arguments: "{}", timestamp: baseDate.addingTimeInterval(1)),
                .functionCallOutput(callID: "call-1", timestamp: baseDate.addingTimeInterval(2)),
                .taskComplete(turnID: "turn", timestamp: baseDate.addingTimeInterval(3))
            ]) == .done,
            "Resolved request_user_input should be done"
        )

        expect(
            classifier.classify(events: [
                .functionCall(
                    name: "exec_command",
                    callID: "call-2",
                    arguments: #"{"sandbox_permissions":"require_escalated"}"#,
                    timestamp: baseDate
                )
            ]) == .waiting,
            "Unresolved approval request should be waiting"
        )

        expect(
            classifier.classify(events: [
                .taskComplete(turnID: "old", timestamp: baseDate),
                .taskStarted(turnID: "new", timestamp: baseDate.addingTimeInterval(1))
            ]) == .working,
            "New task after completion should be working"
        )

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .taskComplete(turnID: "turn", timestamp: baseDate.addingTimeInterval(1)),
                .assistantMessage(text: "请选择 A 还是 B？", phase: "final_answer", timestamp: baseDate.addingTimeInterval(2))
            ]) == .waiting,
            "Choice-like final question should be waiting"
        )

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .taskComplete(turnID: "turn", timestamp: baseDate.addingTimeInterval(1)),
                .assistantMessage(text: "这个问题为什么会发生？", phase: "final_answer", timestamp: baseDate.addingTimeInterval(2))
            ]) == .done,
            "Explanatory final question should be done"
        )
    }

    mutating func runParserChecks() {
        let parser = SessionEventParser()
        let line = #"{"timestamp":"2026-06-02T14:23:41.223Z","type":"response_item","payload":{"type":"function_call","name":"request_user_input","arguments":"{\"questions\":[]}","call_id":"call-1"}}"#

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expectedDate = formatter.date(from: "2026-06-02T14:23:41.223Z")!

        expect(
            parser.parseLine(line) == .functionCall(
                name: "request_user_input",
                callID: "call-1",
                arguments: #"{"questions":[]}"#,
                timestamp: expectedDate
            ),
            "Parser should read request_user_input function call"
        )

        expect(parser.parseLine("{not-json") == nil, "Parser should ignore malformed lines")
    }

    func finish() -> Never {
        if failures == 0 {
            print("All CodexStatusMonitorCore checks passed.")
            exit(0)
        }

        exit(1)
    }
}

var runner = CheckRunner()
runner.runWaitingSignalChecks()
runner.runStateClassifierChecks()
runner.runParserChecks()
runner.finish()
