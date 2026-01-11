import Foundation

/// アンケートの質問を表す値オブジェクト
enum SurveyQuestion: Sendable, Equatable {
    /// 単一選択式
    case singleChoice(text: String, choices: [String])
    /// 複数選択式
    case multipleChoice(text: String, choices: [String], maxSelections: Int?)
    /// 自由記述式
    case freeText(text: String, maxLength: Int?)
    /// 評価スケール（1-5など）
    case scale(text: String, min: Int, max: Int, labels: (min: String, max: String)?)

    /// 質問文を取得
    var text: String {
        switch self {
        case .singleChoice(let text, _),
             .multipleChoice(let text, _, _),
             .freeText(let text, _),
             .scale(let text, _, _, _):
            return text
        }
    }

    /// 回答が有効かどうかを検証
    func isValidAnswer(_ answer: SurveyAnswer) -> Bool {
        switch (self, answer) {
        case (.singleChoice(_, let choices), .singleChoice(let selected)):
            return choices.contains(selected)

        case (.multipleChoice(_, let choices, let maxSelections), .multipleChoice(let selected)):
            let allValid = selected.allSatisfy { choices.contains($0) }
            let withinLimit = maxSelections.map { selected.count <= $0 } ?? true
            return allValid && withinLimit && !selected.isEmpty

        case (.freeText(_, let maxLength), .freeText(let text)):
            let withinLimit = maxLength.map { text.count <= $0 } ?? true
            return withinLimit && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        case (.scale(_, let min, let max, _), .scale(let value)):
            return value >= min && value <= max

        default:
            return false
        }
    }
}

/// アンケートの回答を表す値オブジェクト
enum SurveyAnswer: Sendable, Equatable {
    case singleChoice(String)
    case multipleChoice([String])
    case freeText(String)
    case scale(Int)
}
