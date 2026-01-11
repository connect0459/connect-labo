import ComposableArchitecture
import SwiftUI

/// アプリのルートView
struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            // ホーム
            HomeView(store: store)
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(AppFeature.State.Tab.home)

            // アンケート
            SurveyListView(
                store: store.scope(state: \.surveyList, action: \.surveyList)
            )
            .tabItem {
                Label("アンケート", systemImage: "doc.text.fill")
            }
            .tag(AppFeature.State.Tab.surveys)

            // ポイント
            PointDashboardView(
                store: store.scope(state: \.pointDashboard, action: \.pointDashboard)
            )
            .tabItem {
                Label("ポイント", systemImage: "bitcoinsign.circle.fill")
            }
            .tag(AppFeature.State.Tab.points)

            // ミッション（プレースホルダー）
            MissionsPlaceholderView()
                .tabItem {
                    Label("ミッション", systemImage: "star.fill")
                }
                .tag(AppFeature.State.Tab.missions)
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ポイント残高サマリー
                    PointSummaryCard(balance: store.pointDashboard.balance)

                    // 今日のミッション（プレースホルダー）
                    TodaysMissionCard()

                    // おすすめアンケート
                    RecommendedSurveysCard(surveys: Array(store.surveyList.surveys.prefix(3)))
                }
                .padding()
            }
            .navigationTitle("ホーム")
        }
    }
}

// MARK: - Point Summary Card

struct PointSummaryCard: View {
    let balance: PointBalance?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ポイント残高")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                if let balance {
                    Text("\(balance.total.value)")
                        .font(.system(size: 36, weight: .bold))
                    Text("pt")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("≈ \(balance.total.toYenString())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("---")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Today's Mission Card

struct TodaysMissionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日のミッション")
                    .font(.headline)
                Spacer()
                Text("1/3 完了")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(["デイリーログイン", "アンケート1件回答", "アンケート3件回答"], id: \.self) { mission in
                HStack {
                    Image(systemName: mission == "デイリーログイン" ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(mission == "デイリーログイン" ? .green : .secondary)

                    Text(mission)
                        .font(.subheadline)

                    Spacer()

                    Text(mission == "デイリーログイン" ? "+10pt" : mission.contains("1件") ? "+20pt" : "+50pt")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Recommended Surveys Card

struct RecommendedSurveysCard: View {
    let surveys: [Survey]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("おすすめアンケート")
                    .font(.headline)
                Spacer()
                Text("効率順")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if surveys.isEmpty {
                Text("読み込み中...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(surveys) { survey in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(survey.title)
                                .font(.subheadline)
                                .lineLimit(1)

                            Text("約\(survey.estimatedMinutes)分")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("+\(survey.reward.value)pt")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Missions Placeholder

struct MissionsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("ストリーク") {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("5日連続ログイン中")
                        Spacer()
                        Text("最長: 12日")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("デイリーミッション") {
                    ForEach(["デイリーログイン", "アンケート回答", "動画視聴"], id: \.self) { mission in
                        HStack {
                            Text(mission)
                            Spacer()
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("アチーブメント") {
                    ForEach(["アンケートビギナー", "1週間継続", "ポイントコレクター"], id: \.self) { achievement in
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(achievement)
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("ミッション")
        }
    }
}

// MARK: - Preview

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.surveyClient = .previewValue
            $0.pointClient = .previewValue
        }
    )
}
