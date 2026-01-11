import ComposableArchitecture
import SwiftUI

/// アンケート詳細View
struct SurveyDetailView: View {
    @Bindable var store: StoreOf<SurveyDetailFeature>

    var body: some View {
        NavigationStack {
            Group {
                if let earnedPoints = store.earnedPoints {
                    completionView(earnedPoints: earnedPoints)
                } else {
                    questionView
                }
            }
            .navigationTitle(store.survey.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        store.send(.closeButtonTapped)
                    }
                }
            }
        }
    }

    // MARK: - Question View

    private var questionView: some View {
        VStack(spacing: 0) {
            // プログレスバー
            ProgressView(value: store.progress)
                .padding()

            // 質問表示エリア
            if let question = store.currentQuestion {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 質問番号
                        Text("Q\(store.currentQuestionIndex + 1) / \(store.survey.questions.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // 質問文
                        Text(question.text)
                            .font(.title3)
                            .fontWeight(.semibold)

                        // 回答入力
                        questionInput(for: question)
                    }
                    .padding()
                }
            }

            Spacer()

            // ナビゲーションボタン
            navigationButtons
        }
    }

    @ViewBuilder
    private func questionInput(for question: SurveyQuestion) -> some View {
        switch question {
        case .singleChoice(_, let choices):
            VStack(spacing: 12) {
                ForEach(choices, id: \.self) { choice in
                    ChoiceButton(
                        title: choice,
                        isSelected: isSelected(choice: choice)
                    ) {
                        store.send(.answerSelected(.singleChoice(choice)))
                    }
                }
            }

        case .multipleChoice(_, let choices, _):
            VStack(spacing: 12) {
                ForEach(choices, id: \.self) { choice in
                    ChoiceButton(
                        title: choice,
                        isSelected: isSelectedMultiple(choice: choice),
                        style: .checkbox
                    ) {
                        toggleMultipleChoice(choice)
                    }
                }
            }

        case .freeText(_, let maxLength):
            VStack(alignment: .leading) {
                TextEditor(text: freeTextBinding)
                    .frame(minHeight: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )

                if let maxLength {
                    Text("\(currentFreeText.count) / \(maxLength)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case .scale(_, let min, let max, let labels):
            VStack(spacing: 16) {
                // スケールスライダー
                Slider(
                    value: scaleBinding,
                    in: Double(min)...Double(max),
                    step: 1
                )

                // ラベル
                HStack {
                    Text(labels?.min ?? "\(min)")
                        .font(.caption)
                    Spacer()
                    Text("\(currentScaleValue)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text(labels?.max ?? "\(max)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // 戻るボタン
            if store.currentQuestionIndex > 0 {
                Button {
                    store.send(.previousButtonTapped)
                } label: {
                    Label("戻る", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            // 次へ/送信ボタン
            if store.isLastQuestion {
                Button {
                    store.send(.submitButtonTapped)
                } label: {
                    if store.isSubmitting {
                        ProgressView()
                    } else {
                        Text("送信して\(store.survey.reward.value)pt獲得")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canSubmit || store.isSubmitting)
            } else {
                Button {
                    store.send(.nextButtonTapped)
                } label: {
                    Label("次へ", systemImage: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasCurrentAnswer)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Completion View

    private func completionView(earnedPoints: PointAmount) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("回答完了！")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                Text("\(earnedPoints.value)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.orange)
                + Text(" pt")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("(\(earnedPoints.toYenString()))")
                    .foregroundStyle(.secondary)
            }

            Text("ポイントが付与されました")
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.send(.surveyCompleted)
            } label: {
                Text("閉じる")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Helpers

    private var hasCurrentAnswer: Bool {
        store.currentQuestionIndex < store.answers.count
    }

    private func isSelected(choice: String) -> Bool {
        guard store.currentQuestionIndex < store.answers.count,
              case .singleChoice(let selected) = store.answers[store.currentQuestionIndex] else {
            return false
        }
        return selected == choice
    }

    private func isSelectedMultiple(choice: String) -> Bool {
        guard store.currentQuestionIndex < store.answers.count,
              case .multipleChoice(let selected) = store.answers[store.currentQuestionIndex] else {
            return false
        }
        return selected.contains(choice)
    }

    private func toggleMultipleChoice(_ choice: String) {
        var current: [String] = []
        if store.currentQuestionIndex < store.answers.count,
           case .multipleChoice(let selected) = store.answers[store.currentQuestionIndex] {
            current = selected
        }

        if current.contains(choice) {
            current.removeAll { $0 == choice }
        } else {
            current.append(choice)
        }

        store.send(.answerSelected(.multipleChoice(current)))
    }

    private var currentFreeText: String {
        guard store.currentQuestionIndex < store.answers.count,
              case .freeText(let text) = store.answers[store.currentQuestionIndex] else {
            return ""
        }
        return text
    }

    private var freeTextBinding: Binding<String> {
        Binding(
            get: { currentFreeText },
            set: { store.send(.answerSelected(.freeText($0))) }
        )
    }

    private var currentScaleValue: Int {
        guard store.currentQuestionIndex < store.answers.count,
              case .scale(let value) = store.answers[store.currentQuestionIndex] else {
            if case .scale(_, let min, let max, _) = store.currentQuestion {
                return (min + max) / 2
            }
            return 1
        }
        return value
    }

    private var scaleBinding: Binding<Double> {
        Binding(
            get: { Double(currentScaleValue) },
            set: { store.send(.answerSelected(.scale(Int($0)))) }
        )
    }
}

// MARK: - Choice Button

struct ChoiceButton: View {
    enum Style { case radio, checkbox }

    let title: String
    let isSelected: Bool
    var style: Style = .radio
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(isSelected ? .accentColor : .secondary)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch style {
        case .radio:
            return isSelected ? "circle.inset.filled" : "circle"
        case .checkbox:
            return isSelected ? "checkmark.square.fill" : "square"
        }
    }
}

// MARK: - Preview

#Preview {
    SurveyDetailView(
        store: Store(
            initialState: SurveyDetailFeature.State(survey: Survey.samples[0])
        ) {
            SurveyDetailFeature()
        } withDependencies: {
            $0.surveyClient = .previewValue
        }
    )
}
