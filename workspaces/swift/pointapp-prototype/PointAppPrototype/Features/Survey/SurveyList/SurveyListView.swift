import ComposableArchitecture
import SwiftUI

/// アンケート一覧View
struct SurveyListView: View {
    @Bindable var store: StoreOf<SurveyListFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.surveys.isEmpty {
                    ProgressView("読み込み中...")
                } else if let error = store.errorMessage {
                    ContentUnavailableView {
                        Label("エラー", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("再読み込み") {
                            store.send(.refreshButtonTapped)
                        }
                    }
                } else if store.surveys.isEmpty {
                    ContentUnavailableView {
                        Label("アンケートがありません", systemImage: "doc.text")
                    } description: {
                        Text("現在回答可能なアンケートはありません")
                    }
                } else {
                    surveyList
                }
            }
            .navigationTitle("アンケート")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if store.isLoading {
                        ProgressView()
                    } else {
                        Button {
                            store.send(.refreshButtonTapped)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .sheet(item: $store.scope(state: \.detail, action: \.detail)) { store in
            SurveyDetailView(store: store)
        }
        .task {
            store.send(.onAppear)
        }
    }

    private var surveyList: some View {
        List {
            // カテゴリフィルター
            Section {
                categoryPicker
            }

            // アンケート一覧
            Section {
                ForEach(store.surveys) { survey in
                    SurveyRow(survey: survey)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.surveyTapped(survey))
                        }
                }
            } header: {
                HStack {
                    Text("利用可能なアンケート")
                    Spacer()
                    Text("\(store.surveys.count)件")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            store.send(.refreshButtonTapped)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "すべて",
                    isSelected: store.selectedCategory == nil
                ) {
                    store.send(.categorySelected(nil))
                }

                ForEach(SurveyCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        isSelected: store.selectedCategory == category
                    ) {
                        store.send(.categorySelected(category))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Survey Row

struct SurveyRow: View {
    let survey: Survey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // タイトル
            HStack {
                Text(survey.title)
                    .font(.headline)
                    .lineLimit(2)

                if survey.isHighEfficiency {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }

            // 説明
            Text(survey.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // メタ情報
            HStack {
                // 報酬
                Label {
                    Text("\(survey.reward.value)pt")
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "bitcoinsign.circle.fill")
                }
                .foregroundStyle(.orange)

                Text("(\(survey.reward.toYenString()))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                // 所要時間
                Label("約\(survey.estimatedMinutes)分", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 効率
                Text(String(format: "%.1fpt/分", survey.rewardEfficiency()))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(survey.isHighEfficiency ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .foregroundStyle(survey.isHighEfficiency ? .green : .secondary)
                    .clipShape(Capsule())
            }

            // 残り時間
            if let remainingLabel = survey.remainingTimeLabel() {
                Text(remainingLabel)
                    .font(.caption2)
                    .foregroundStyle(remainingLabel.contains("まもなく") ? .red : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SurveyListView(
        store: Store(
            initialState: SurveyListFeature.State(surveys: Survey.samples)
        ) {
            SurveyListFeature()
        } withDependencies: {
            $0.surveyClient = .previewValue
        }
    )
}
