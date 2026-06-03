import Foundation

public struct WaitingSignalDetector: Sendable {
    private let requestSignals = [
        "waiting for",
        "please provide",
        "please confirm",
        "please choose",
        "please select",
        "please approve",
        "please proceed",
        "please continue",
        "please allow",
        "do you want",
        "would you like",
        "let me know",
        "tell me what",
        "tell me which",
        "tell me how",
        "请提供",
        "请确认",
        "请选择",
        "请批准",
        "请继续",
        "请允许",
        "需要你提供",
        "需要你确认",
        "需要你选择",
        "要不要继续",
        "是否继续",
        "告诉我你的选择",
        "告诉我你选择",
        "告诉我哪"
    ]

    private let optionSignals = [
        "option",
        "options",
        "recommended",
        "方案",
        "选项",
        "(recommended)",
        "a/b",
        "1/2",
        "1. ",
        "2. "
    ]

    public init() {}

    public func requiresUserResponse(_ text: String) -> Bool {
        let normalized = normalize(text)
        guard !normalized.isEmpty else {
            return false
        }

        if containsAny(requestSignals, in: normalized) {
            return true
        }

        guard endsWithQuestionMark(normalized) else {
            return false
        }

        return isChoiceLikeQuestion(normalized)
    }

    public func isChoiceLikeQuestion(_ normalizedText: String) -> Bool {
        let lastQuestion = lastQuestionSentence(in: normalizedText)
        guard let lastQuestion else {
            return false
        }

        if containsAny(requestSignals, in: lastQuestion) {
            return true
        }

        if containsAny(optionSignals, in: normalizedText) {
            return true
        }

        return lastQuestion.count <= 90 && (
            lastQuestion.contains("吗")
                || lastQuestion.contains("which")
                || lastQuestion.contains("do you")
                || lastQuestion.contains("would you")
        )
    }

    private func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func endsWithQuestionMark(_ text: String) -> Bool {
        text.hasSuffix("?") || text.hasSuffix("？")
    }

    private func lastQuestionSentence(in text: String) -> String? {
        let separators = CharacterSet(charactersIn: "\n.!。;；")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { $0.hasSuffix("?") || $0.hasSuffix("？") }
    }

    private func containsAny(_ needles: [String], in haystack: String) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}
