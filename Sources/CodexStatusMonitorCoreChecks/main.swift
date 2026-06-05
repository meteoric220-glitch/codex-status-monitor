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

        expect(detector.requiresUserResponse("Please confirm this design."), "English confirm request")
        expect(detector.requiresUserResponse("Which option should I use?"), "English choice question")
        expect(detector.requiresUserResponse("Let me know what you choose."), "English let-me-know keyword")
        expect(detector.requiresUserResponse("请确认这个方案是否符合你的想法？"), "Chinese confirm request")
        expect(detector.requiresUserResponse("你要不要继续？"), "Chinese continue question")
        expect(detector.requiresUserResponse("请选择 A 还是 B？"), "Chinese choose request")

        expect(!detector.requiresUserResponse("这个问题为什么会发生？"), "Chinese explanatory question should be done")
        expect(!detector.requiresUserResponse("这意味着什么？"), "Chinese meaning question should be done")
        expect(!detector.requiresUserResponse("Why did this happen?"), "English explanatory question should be done")
        expect(!detector.requiresUserResponse("已确认：三项检查通过。"), "Completed confirmation summary should be done")
        expect(!detector.requiresUserResponse("已验证两个文件语法通过。"), "Completed verification summary should be done")
        expect(
            !detector.requiresUserResponse("右键菜单新增 Provider > Codex / Claude，选择会持久化。"),
            "Persistent selection summary should be done"
        )
        expect(
            !detector.requiresUserResponse("Claude JSONL 映射到现有状态逻辑，复用 Working / Waiting / Done 分类。"),
            "Status taxonomy summary should be done"
        )

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
                .taskStarted(turnID: "old", timestamp: baseDate),
                .functionCall(name: "request_user_input", callID: "call-old", arguments: "{}", timestamp: baseDate.addingTimeInterval(1)),
                .taskStarted(turnID: "new", timestamp: baseDate.addingTimeInterval(10)),
                .taskComplete(turnID: "new", timestamp: baseDate.addingTimeInterval(11)),
                .assistantMessage(text: "已完成，可以运行打包后的 app。", phase: "final_answer", timestamp: baseDate.addingTimeInterval(12))
            ]) == .done,
            "Historical unresolved request_user_input should not affect the latest completed turn"
        )

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .taskComplete(turnID: "turn", timestamp: baseDate.addingTimeInterval(1)),
                .assistantMessage(
                    text: """
                    <proposed_plan>
                    # Demo
                    </proposed_plan>
                    """,
                    phase: "final_answer",
                    timestamp: baseDate.addingTimeInterval(2)
                )
            ]) == .waiting,
            "Final proposed plan should be waiting"
        )

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .taskComplete(turnID: "turn", timestamp: baseDate.addingTimeInterval(1)),
                .assistantMessage(
                    text: "`<proposed_plan>...</proposed_plan>` 出现在最新最终回复时，现在会判为 Waiting。",
                    phase: "final_answer",
                    timestamp: baseDate.addingTimeInterval(2)
                )
            ]) == .done,
            "Inline proposed plan explanation should be done"
        )

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "old", timestamp: baseDate),
                .taskComplete(turnID: "old", timestamp: baseDate.addingTimeInterval(1)),
                .assistantMessage(
                    text: """
                    <proposed_plan>
                    # Old Demo
                    </proposed_plan>
                    """,
                    phase: "final_answer",
                    timestamp: baseDate.addingTimeInterval(2)
                ),
                .taskStarted(turnID: "new", timestamp: baseDate.addingTimeInterval(10)),
                .taskComplete(turnID: "new", timestamp: baseDate.addingTimeInterval(11)),
                .assistantMessage(
                    text: "已完成，可以运行。",
                    phase: "final_answer",
                    timestamp: baseDate.addingTimeInterval(12)
                )
            ]) == .done,
            "Historical proposed plan should not affect the latest completed turn"
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

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .taskComplete(turnID: "turn", timestamp: baseDate.addingTimeInterval(1)),
                .assistantMessage(text: "我会继续检查，请等待。", phase: "commentary", timestamp: baseDate.addingTimeInterval(2)),
                .assistantMessage(text: "已完成，可以运行。", phase: "final_answer", timestamp: baseDate.addingTimeInterval(3))
            ]) == .done,
            "Commentary messages should not trigger final waiting detection"
        )

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .taskComplete(turnID: "turn", timestamp: baseDate.addingTimeInterval(1)),
                .assistantMessage(text: "请确认是否继续？", phase: "final_answer", timestamp: baseDate.addingTimeInterval(2))
            ]) == .waiting,
            "Final confirmation question should be waiting"
        )

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .taskComplete(turnID: "turn", timestamp: baseDate.addingTimeInterval(1)),
                .assistantMessage(text: "已确认：三项检查通过。", phase: "final_answer", timestamp: baseDate.addingTimeInterval(2))
            ]) == .done,
            "Completed confirmation summary should be done"
        )

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .taskComplete(turnID: "turn", timestamp: baseDate.addingTimeInterval(1)),
                .assistantMessage(
                    text: "右键菜单新增 Provider > Codex / Claude，选择会持久化。默认仍是 Codex。",
                    phase: "final_answer",
                    timestamp: baseDate.addingTimeInterval(2)
                )
            ]) == .done,
            "Persistent selection final summary should be done"
        )

        expect(
            classifier.classify(events: [
                .taskStarted(turnID: "turn", timestamp: baseDate),
                .taskComplete(turnID: "turn", timestamp: baseDate.addingTimeInterval(1)),
                .assistantMessage(
                    text: "Claude JSONL 映射到现有状态逻辑，复用 Working / Waiting / Done 分类。",
                    phase: "final_answer",
                    timestamp: baseDate.addingTimeInterval(2)
                )
            ]) == .done,
            "Status taxonomy final summary should be done"
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

    mutating func runClaudeParserChecks() {
        let parser = ClaudeSessionEventParser()
        let classifier = StateClassifier()

        let cliUserLine = #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"build it"}]},"uuid":"user-1","promptId":"prompt-1","timestamp":"2026-06-02T14:23:40.000Z","entrypoint":"cli","cwd":"/tmp/claude-project","sessionId":"session-cli"}"#
        let toolUseLine = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"call_1","name":"Bash","input":{"command":"npm test"}}],"stop_reason":"tool_use"},"uuid":"assistant-1","timestamp":"2026-06-02T14:23:41.000Z","entrypoint":"cli","cwd":"/tmp/claude-project","sessionId":"session-cli"}"#
        let toolResultLine = #"{"type":"user","message":{"role":"user","content":[{"tool_use_id":"call_1","type":"tool_result","content":"ok","is_error":false}]},"uuid":"result-1","timestamp":"2026-06-02T14:23:42.000Z","entrypoint":"cli","cwd":"/tmp/claude-project","sessionId":"session-cli"}"#
        let doneLine = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"已完成，可以运行。"}],"stop_reason":"end_turn"},"uuid":"assistant-2","timestamp":"2026-06-02T14:23:43.000Z","entrypoint":"cli","cwd":"/tmp/claude-project","sessionId":"session-cli"}"#
        let waitingLine = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"请确认是否继续？"}],"stop_reason":"end_turn"},"uuid":"assistant-3","timestamp":"2026-06-02T14:23:44.000Z","entrypoint":"claude-vscode","cwd":"/tmp/claude-project","sessionId":"session-vscode"}"#
        let exitPlanModeLine = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"call_plan","name":"ExitPlanMode","input":{"plan":"demo"}}],"stop_reason":"tool_use"},"uuid":"assistant-4","timestamp":"2026-06-02T14:23:45.000Z","entrypoint":"claude-vscode","cwd":"/tmp/claude-project","sessionId":"session-vscode"}"#
        let askUserQuestionLine = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"call_question","name":"AskUserQuestion","input":{"question":"Pick one"}}],"stop_reason":"tool_use"},"uuid":"assistant-5","timestamp":"2026-06-02T14:23:46.000Z","entrypoint":"claude-vscode","cwd":"/tmp/claude-project","sessionId":"session-vscode"}"#

        let workingEvents = [cliUserLine, toolUseLine].compactMap(parser.parseLine)
        expect(classifier.classify(events: workingEvents) == .working, "Claude unresolved tool_use should be working")

        let doneEvents = [cliUserLine, toolUseLine, toolResultLine, doneLine].compactMap(parser.parseLine)
        expect(classifier.classify(events: doneEvents) == .done, "Claude resolved tool_use with normal final answer should be done")

        let waitingEvents = [cliUserLine, waitingLine].compactMap(parser.parseLine)
        expect(classifier.classify(events: waitingEvents) == .waiting, "Claude final confirmation question should be waiting")

        let exitPlanModeEvents = [cliUserLine, exitPlanModeLine].compactMap(parser.parseLine)
        expect(classifier.classify(events: exitPlanModeEvents) == .waiting, "Claude ExitPlanMode should be waiting")

        let askUserQuestionEvents = [cliUserLine, askUserQuestionLine].compactMap(parser.parseLine)
        expect(classifier.classify(events: askUserQuestionEvents) == .waiting, "Claude AskUserQuestion should be waiting")

        expect(
            parser.parseLine(cliUserLine) == .taskStarted(
                turnID: "prompt-1",
                timestamp: Self.isoDate("2026-06-02T14:23:40.000Z")
            ),
            "Claude CLI user text should start a turn"
        )

        expect(
            parser.parseLine(exitPlanModeLine) == .functionCall(
                name: "request_user_input",
                callID: "call_plan",
                arguments: #"{"plan":"demo"}"#,
                timestamp: Self.isoDate("2026-06-02T14:23:45.000Z")
            ),
            "Claude ExitPlanMode should map to request_user_input"
        )
    }

    mutating func runClaudeResolverChecks() {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexStatusMonitorCoreChecks-\(UUID().uuidString)", isDirectory: true)
        let projectsDirectory = root.appendingPathComponent("projects", isDirectory: true)
        let projectDirectory = root.appendingPathComponent("target project", isDirectory: true)
        let otherProjectDirectory = root.appendingPathComponent("other project", isDirectory: true)

        do {
            try fileManager.createDirectory(at: projectsDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: otherProjectDirectory, withIntermediateDirectories: true)
            defer {
                try? fileManager.removeItem(at: root)
            }

            let encodedDirectory = projectsDirectory.appendingPathComponent("-tmp-target-project", isDirectory: true)
            let otherEncodedDirectory = projectsDirectory.appendingPathComponent("-tmp-other-project", isDirectory: true)
            let subagentDirectory = encodedDirectory.appendingPathComponent("subagents", isDirectory: true)
            try fileManager.createDirectory(at: encodedDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: otherEncodedDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: subagentDirectory, withIntermediateDirectories: true)

            let oldSession = encodedDirectory.appendingPathComponent("old.jsonl")
            let newSession = encodedDirectory.appendingPathComponent("new.jsonl")
            let otherSession = otherEncodedDirectory.appendingPathComponent("other.jsonl")
            let sidechainSession = subagentDirectory.appendingPathComponent("sidechain.jsonl")

            try writeTranscript(
                to: oldSession,
                sessionID: "old",
                cwd: projectDirectory.path,
                timestamp: "2026-06-02T14:23:40.000Z",
                entrypoint: "cli"
            )
            try writeTranscript(
                to: newSession,
                sessionID: "new",
                cwd: projectDirectory.path,
                timestamp: "2026-06-02T14:23:50.000Z",
                entrypoint: "claude-vscode"
            )
            try writeTranscript(
                to: otherSession,
                sessionID: "other",
                cwd: otherProjectDirectory.path,
                timestamp: "2026-06-02T14:24:00.000Z",
                entrypoint: "cli"
            )
            try writeTranscript(
                to: sidechainSession,
                sessionID: "sidechain",
                cwd: projectDirectory.path,
                timestamp: "2026-06-02T14:25:00.000Z",
                entrypoint: "cli"
            )

            let resolver = ClaudeSessionResolver(projectsDirectory: projectsDirectory)
            let session = try resolver.resolveSession(for: projectDirectory)
            expect(session?.id == "new", "Claude resolver should choose newest matching main session")
            expect(
                session?.transcriptPath.standardizedFileURL.path == newSession.standardizedFileURL.path,
                "Claude resolver should return newest transcript path"
            )
        } catch {
            expect(false, "Claude resolver checks should not throw: \(error)")
        }
    }

    mutating func runClaudeResolverCandidateLimitChecks() {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexStatusMonitorCandidateLimitChecks-\(UUID().uuidString)", isDirectory: true)
        let projectsDirectory = root.appendingPathComponent("projects", isDirectory: true)
        let projectDirectory = root.appendingPathComponent("target project", isDirectory: true)
        let encodedDirectory = projectsDirectory.appendingPathComponent("-tmp-target-project", isDirectory: true)

        do {
            try fileManager.createDirectory(at: encodedDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
            defer {
                try? fileManager.removeItem(at: root)
            }

            let newestSession = encodedDirectory.appendingPathComponent("newest.jsonl")
            let middleSession = encodedDirectory.appendingPathComponent("middle.jsonl")
            let oldestSession = encodedDirectory.appendingPathComponent("oldest.jsonl")

            try writeTranscript(
                to: newestSession,
                sessionID: "newest",
                cwd: "/tmp/other",
                timestamp: "2026-06-02T14:23:50.000Z",
                entrypoint: "cli"
            )
            try writeTranscript(
                to: middleSession,
                sessionID: "middle",
                cwd: projectDirectory.path,
                timestamp: "2026-06-02T14:23:40.000Z",
                entrypoint: "cli"
            )
            try writeTranscript(
                to: oldestSession,
                sessionID: "oldest",
                cwd: projectDirectory.path,
                timestamp: "2026-06-02T14:23:30.000Z",
                entrypoint: "cli"
            )

            try fileManager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 3_000)], ofItemAtPath: newestSession.path)
            try fileManager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2_000)], ofItemAtPath: middleSession.path)
            try fileManager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000)], ofItemAtPath: oldestSession.path)

            let resolver = ClaudeSessionResolver(projectsDirectory: projectsDirectory, maxTranscriptCandidates: 2)
            let session = try resolver.resolveSession(for: projectDirectory)
            expect(session?.id == "middle", "Claude resolver should only parse recent transcript candidates")
        } catch {
            expect(false, "Claude resolver candidate limit checks should not throw: \(error)")
        }
    }

    mutating func runClaudeStatusServiceFallbackChecks() {
        let projectDirectory = URL(fileURLWithPath: "/tmp/claude-desktop-project")
        let service = ClaudeStatusService(
            resolver: StubClaudeResolver(session: nil),
            parser: ClaudeSessionEventParser(),
            classifier: StateClassifier()
        )

        let noDataSnapshot = service.snapshot(for: projectDirectory)
        expect(noDataSnapshot.status == .error, "Claude status service should use error status when no JSONL data exists")
        expect(noDataSnapshot.detail == "No Data Yet", "Claude status service should show No Data Yet without JSONL data")
    }

    private func writeTranscript(
        to url: URL,
        sessionID: String,
        cwd: String,
        timestamp: String,
        entrypoint: String
    ) throws {
        let escapedCWD = cwd.replacingOccurrences(of: #"\"#, with: #"\\"#)
        let line = #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"hello"}]},"uuid":"\#(sessionID)-user","promptId":"\#(sessionID)-prompt","timestamp":"\#(timestamp)","entrypoint":"\#(entrypoint)","cwd":"\#(escapedCWD)","sessionId":"\#(sessionID)"}"#
        try line.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func isoDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)!
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
runner.runClaudeParserChecks()
runner.runClaudeResolverChecks()
runner.runClaudeResolverCandidateLimitChecks()
runner.runClaudeStatusServiceFallbackChecks()
runner.finish()

private final class StubClaudeResolver: ClaudeSessionResolving {
    let session: ClaudeSession?

    init(session: ClaudeSession?) {
        self.session = session
    }

    func resolveSession(for projectDirectory: URL) throws -> ClaudeSession? {
        session
    }
}
