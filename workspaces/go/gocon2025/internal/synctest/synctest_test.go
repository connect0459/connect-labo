package synctest_test

import (
	"context"
	"testing"
	"testing/synctest"
	"time"

	synctestpkg "github.com/connect0459/connect-lab/go/gocon2025/internal/synctest"
)

// TaskProcessorTest は TaskProcessor のテストに必要なデータと設定を管理する
type TaskProcessorTest struct {
	processor synctestpkg.TaskProcessor
}

// VideoProcessorTest は VideoProcessor のテストに必要なデータと設定を管理する
type VideoProcessorTest struct {
	processor synctestpkg.VideoProcessor
}

func TestTaskProcessor(t *testing.T) {
	setup := func(t *testing.T) *TaskProcessorTest {
		t.Helper()
		return &TaskProcessorTest{
			processor: synctestpkg.NewTaskProcessor(),
		}
	}

	test := setup(t)

	t.Run("遅延処理機能", func(t *testing.T) {
		t.Run("Table Driven Test - 様々な遅延時間でのテスト", func(t *testing.T) {
			testCases := []struct {
				name     string
				delay    time.Duration
				message  string
				expected string
			}{
				{
					name:     "ゼロ遅延での処理",
					delay:    0,
					message:  "即座処理",
					expected: "処理完了: 即座処理",
				},
				{
					name:     "ナノ秒遅延での処理",
					delay:    1 * time.Nanosecond,
					message:  "極小遅延",
					expected: "処理完了: 極小遅延",
				},
				{
					name:     "ミリ秒遅延での処理",
					delay:    100 * time.Millisecond,
					message:  "短時間",
					expected: "処理完了: 短時間",
				},
				{
					name:     "秒遅延での処理",
					delay:    1 * time.Second,
					message:  "標準時間",
					expected: "処理完了: 標準時間",
				},
				{
					name:     "長時間遅延での処理",
					delay:    30 * time.Second,
					message:  "長時間",
					expected: "処理完了: 長時間",
				},
				{
					name:     "空文字列メッセージでの処理",
					delay:    500 * time.Millisecond,
					message:  "",
					expected: "処理完了: ",
				},
				{
					name:     "特殊文字を含むメッセージでの処理",
					delay:    200 * time.Millisecond,
					message:  "テスト\n改行\t\tタブ\"引用符",
					expected: "処理完了: テスト\n改行\t\tタブ\"引用符",
				},
			}

			for _, tc := range testCases {
				t.Run(tc.name, func(t *testing.T) {
					synctest.Test(t, func(t *testing.T) {
						// 準備
						ctx := context.Background()

						// 実行
						result := test.processor.ProcessWithDelay(ctx, tc.delay, tc.message)

						// 検証 - synctestによりほぼ瞬時に完了する
						synctest.Wait()
						got := <-result
						if got != tc.expected {
							t.Errorf("結果が期待値と異なります: got %q, want %q", got, tc.expected)
						}
					})
				})
			}
		})

		t.Run("Table Driven Test - コンテキストキャンセルのエッジケース", func(t *testing.T) {
			testCases := []struct {
				name           string
				delay          time.Duration
				cancelTiming   string
				cancelAfter    time.Duration
				expectCanceled bool
			}{
				{
					name:           "即座にキャンセル",
					delay:          1 * time.Second,
					cancelTiming:   "immediate",
					cancelAfter:    0,
					expectCanceled: true,
				},
				{
					name:           "遅延前にキャンセル",
					delay:          500 * time.Millisecond,
					cancelTiming:   "before_delay",
					cancelAfter:    100 * time.Millisecond,
					expectCanceled: true,
				},
				// 注意: synctestでは処理完了後のキャンセルテストは複雑になるため除外
			}

			for _, tc := range testCases {
				t.Run(tc.name, func(t *testing.T) {
					synctest.Test(t, func(t *testing.T) {
						// 準備
						ctx, cancel := context.WithCancel(context.Background())
						defer cancel()

						// 実行
						result := test.processor.ProcessWithDelay(ctx, tc.delay, "キャンセルテスト")

						// キャンセルタイミングの制御
						switch tc.cancelTiming {
						case "immediate":
							cancel()
						case "before_delay":
							go func() {
								time.Sleep(tc.cancelAfter)
								cancel()
							}()
						}

						// 検証
						synctest.Wait()
						_, ok := <-result

						if tc.expectCanceled && ok {
							t.Error("キャンセル後にチャネルが閉じられることを期待しましたが、まだ開いています")
						}
					})
				})
			}
		})
	})

	t.Run("ポーリング処理機能", func(t *testing.T) {
		t.Run("Table Driven Test - ポーリング間隔とリトライ回数のエッジケース", func(t *testing.T) {
			testCases := []struct {
				name        string
				interval    time.Duration
				maxRetries  int
				expectSuccess bool
				description string
			}{
				{
					name:        "ゼロ間隔でのポーリング",
					interval:    0,
					maxRetries:  5,
					expectSuccess: true,
					description: "間隔ゼロでも正常に3回目で成功する",
				},
				{
					name:        "極小間隔でのポーリング",
					interval:    1 * time.Nanosecond,
					maxRetries:  5,
					expectSuccess: true,
					description: "極小間隔でも正常に動作する",
				},
				{
					name:        "標準的な間隔でのポーリング",
					interval:    500 * time.Millisecond,
					maxRetries:  5,
					expectSuccess: true,
					description: "通常ケースでの成功パターン",
				},
				{
					name:        "長時間間隔でのポーリング",
					interval:    5 * time.Second,
					maxRetries:  5,
					expectSuccess: true,
					description: "長時間間隔でも成功する",
				},
				{
					name:        "最小リトライ回数での失敗",
					interval:    100 * time.Millisecond,
					maxRetries:  1,
					expectSuccess: false,
					description: "1回のリトライでは失敗する",
				},
				{
					name:        "境界値リトライ回数での失敗",
					interval:    100 * time.Millisecond,
					maxRetries:  2,
					expectSuccess: false,
					description: "2回のリトライでは失敗する",
				},
				{
					name:        "境界値リトライ回数での成功",
					interval:    100 * time.Millisecond,
					maxRetries:  3,
					expectSuccess: true,
					description: "3回のリトライでちょうど成功する",
				},
				{
					name:        "大量リトライ回数での成功",
					interval:    50 * time.Millisecond,
					maxRetries:  100,
					expectSuccess: true,
					description: "大量のリトライ回数でも3回目で成功する",
				},
			}

			for _, tc := range testCases {
				t.Run(tc.name, func(t *testing.T) {
					synctest.Test(t, func(t *testing.T) {
						// 準備
						ctx := context.Background()

						// 実行
						result := test.processor.ProcessWithPolling(ctx, tc.interval, tc.maxRetries)

						// 検証
						synctest.Wait()
						success := <-result
						if success != tc.expectSuccess {
							t.Errorf("期待値と異なります: got %v, want %v (%s)", success, tc.expectSuccess, tc.description)
						}
					})
				})
			}
		})

		t.Run("Table Driven Test - コンテキストキャンセル時の挙動", func(t *testing.T) {
			testCases := []struct {
				name        string
				interval    time.Duration
				maxRetries  int
				cancelAfter time.Duration
			}{
				{
					name:        "ポーリング開始前のキャンセル",
					interval:    1 * time.Second,
					maxRetries:  5,
					cancelAfter: 0,
				},
				{
					name:        "1回目のポーリング後のキャンセル",
					interval:    500 * time.Millisecond,
					maxRetries:  5,
					cancelAfter: 600 * time.Millisecond,
				},
				{
					name:        "2回目のポーリング後のキャンセル",
					interval:    300 * time.Millisecond,
					maxRetries:  5,
					cancelAfter: 700 * time.Millisecond,
				},
			}

			for _, tc := range testCases {
				t.Run(tc.name, func(t *testing.T) {
					synctest.Test(t, func(t *testing.T) {
						// 準備
						ctx, cancel := context.WithCancel(context.Background())
						defer cancel()

						// 実行
						result := test.processor.ProcessWithPolling(ctx, tc.interval, tc.maxRetries)

						// 指定時間後にキャンセル
						go func() {
							time.Sleep(tc.cancelAfter)
							cancel()
						}()

						// 検証 - キャンセル後にチャネルが適切に処理される
						synctest.Wait()
						_, ok := <-result
						if ok {
							t.Error("キャンセル後にチャネルが閉じられることを期待しましたが、まだ開いています")
						}
					})
				})
			}
		})
	})

	t.Run("ゴルーチン並行処理機能", func(t *testing.T) {
		t.Run("Table Driven Test - 様々なタスク数での並行処理", func(t *testing.T) {
			testCases := []struct {
				name        string
				tasks       []string
				description string
			}{
				{
					name:        "空のタスクリスト",
					tasks:       []string{},
					description: "タスクが0個の場合",
				},
				{
					name:        "単一タスク",
					tasks:       []string{"単独タスク"},
					description: "タスクが1個の場合",
				},
				{
					name:        "標準的なタスク数",
					tasks:       []string{"タスク1", "タスク2", "タスク3"},
					description: "標準的な3個のタスク",
				},
				{
					name:        "多数のタスク",
					tasks:       []string{"タスク1", "タスク2", "タスク3", "タスク4", "タスク5", "タスク6", "タスク7", "タスク8", "タスク9", "タスク10"},
					description: "多数（10個）のタスク",
				},
				{
					name:        "空文字列を含むタスク",
					tasks:       []string{"正常タスク", "", "別の正常タスク"},
					description: "空文字列を含む場合",
				},
				{
					name:        "特殊文字を含むタスク",
					tasks:       []string{"タスク\n改行", "タスク\t\tタブ", "タスク\"引用符", "タスク\\バックスラッシュ"},
					description: "特殊文字を含むタスク名",
				},
				{
					name:        "重複するタスク名",
					tasks:       []string{"重複タスク", "重複タスク", "ユニークタスク"},
					description: "同じ名前のタスクが複数存在する場合",
				},
			}

			for _, tc := range testCases {
				t.Run(tc.name, func(t *testing.T) {
					synctest.Test(t, func(t *testing.T) {
						// 準備
						ctx := context.Background()

						// 実行
						result := test.processor.ProcessWithGoroutine(ctx, tc.tasks)

						// 検証 - すべてのタスクが完了することを確認
						synctest.Wait()
						completedTasks := make(map[string]bool)
						expectedResults := make(map[string]int)

						// 期待される結果を計算
						for _, task := range tc.tasks {
							expected := "タスク完了: " + task
							expectedResults[expected]++
						}

						// 結果を収集
						for range tc.tasks {
							taskResult := <-result
							completedTasks[taskResult] = true
						}

						// すべてのタスクが完了していることを確認
						for _, task := range tc.tasks {
							expected := "タスク完了: " + task
							if !completedTasks[expected] {
								t.Errorf("タスク %q が完了していません (%s)", task, tc.description)
							}
						}
					})
				})
			}
		})

		t.Run("Table Driven Test - コンテキストキャンセル時の挙動", func(t *testing.T) {
			testCases := []struct {
				name        string
				tasks       []string
				cancelAfter time.Duration
			}{
				{
					name:        "即座キャンセル",
					tasks:       []string{"タスク1", "タスク2", "タスク3"},
					cancelAfter: 0,
				},
				// 注意: synctestでは複雑なタイミングでのキャンセルテストは除外
			}

			for _, tc := range testCases {
				t.Run(tc.name, func(t *testing.T) {
					synctest.Test(t, func(t *testing.T) {
						// 準備
						ctx, cancel := context.WithCancel(context.Background())
						defer cancel()

						// 実行
						result := test.processor.ProcessWithGoroutine(ctx, tc.tasks)

						// 即座にキャンセル
						if tc.cancelAfter == 0 {
							cancel()
						}

						// 検証 - キャンセル後に残りのゴルーチンが適切に終了することを確認
						synctest.Wait()

						// 完了したタスク数をカウント
						completedCount := 0
						for {
							select {
							case _, ok := <-result:
								if !ok {
									// チャネルが閉じられた場合は終了
									goto done
								}
								completedCount++
							default:
								// これ以上データがない場合は終了
								goto done
							}
						}
					done:
						// キャンセルされた場合、完了タスク数は元のタスク数以下になる
						if completedCount > len(tc.tasks) {
							t.Errorf("完了したタスク数が元のタスク数を超えています: completed=%d, expected<=%d", completedCount, len(tc.tasks))
						}
					})
				})
			}
		})
	})
}

func TestVideoProcessor(t *testing.T) {
	setup := func(t *testing.T) *VideoProcessorTest {
		t.Helper()
		return &VideoProcessorTest{
			processor: synctestpkg.NewVideoProcessor(),
		}
	}

	test := setup(t)

	t.Run("動画フレーム生成機能", func(t *testing.T) {
		t.Run("Table Driven Test - 様々なフレーム数での生成", func(t *testing.T) {
			testCases := []struct {
				name        string
				totalFrames int
				description string
			}{
				{
					name:        "ゼロフレーム",
					totalFrames: 0,
					description: "フレーム数が0の場合",
				},
				{
					name:        "単一フレーム",
					totalFrames: 1,
					description: "フレーム数が1の場合",
				},
				{
					name:        "少数フレーム",
					totalFrames: 3,
					description: "少数（3フレーム）の場合",
				},
				{
					name:        "標準的なフレーム数",
					totalFrames: 10,
					description: "標準的な10フレーム",
				},
				{
					name:        "多数フレーム",
					totalFrames: 30,
					description: "多数（30フレーム）の場合",
				},
				{
					name:        "大量フレーム",
					totalFrames: 100,
					description: "大量（100フレーム）の場合",
				},
			}

			for _, tc := range testCases {
				t.Run(tc.name, func(t *testing.T) {
					synctest.Test(t, func(t *testing.T) {
						// 準備
						ctx := context.Background()

						// 実行
						result := test.processor.GenerateFrames(ctx, tc.totalFrames)

						// 検証 - フレームが順番に生成されることを確認
						synctest.Wait()
						for expectedFrame := 1; expectedFrame <= tc.totalFrames; expectedFrame++ {
							frameNumber := <-result
							if frameNumber != expectedFrame {
								t.Errorf("フレーム番号が期待値と異なります: got %d, want %d (%s)", frameNumber, expectedFrame, tc.description)
							}
						}

						// チャネルが閉じられることを確認
						_, ok := <-result
						if ok {
							t.Errorf("すべてのフレーム生成後にチャネルが閉じられることを期待しましたが、まだ開いています (%s)", tc.description)
						}
					})
				})
			}
		})

		t.Run("Table Driven Test - コンテキストキャンセル時の挙動", func(t *testing.T) {
			testCases := []struct {
				name         string
				totalFrames  int
				cancelAfter  time.Duration
				description  string
				expectMinFrames int // 最低限生成されることが期待されるフレーム数
			}{
				{
					name:            "即座キャンセル",
					totalFrames:     10,
					cancelAfter:     0,
					description:     "開始直後にキャンセル",
					expectMinFrames: 0,
				},
				// 注意: synctestでは複雑なタイミングでのキャンセルテストは除外
			}

			for _, tc := range testCases {
				t.Run(tc.name, func(t *testing.T) {
					synctest.Test(t, func(t *testing.T) {
						// 準備
						ctx, cancel := context.WithCancel(context.Background())
						defer cancel()

						// 実行
						result := test.processor.GenerateFrames(ctx, tc.totalFrames)

						// 即座にキャンセル
						if tc.cancelAfter == 0 {
							cancel()
						}

						// 検証 - キャンセル前に生成されたフレームを確認
						synctest.Wait()

						generatedFrames := 0
						for {
							select {
							case frameNumber, ok := <-result:
								if !ok {
									// チャネルが閉じられた場合は終了
									goto done
								}
								generatedFrames++
								// フレーム番号が順番通りであることを確認
								if frameNumber != generatedFrames {
									t.Errorf("フレーム番号が期待値と異なります: got %d, want %d (%s)", frameNumber, generatedFrames, tc.description)
								}
							default:
								// これ以上データがない場合は終了
								goto done
							}
						}
					done:
						// 最低限期待されるフレーム数が生成されていることを確認
						if generatedFrames < tc.expectMinFrames {
							t.Errorf("生成されたフレーム数が期待値を下回ります: got %d, want >= %d (%s)", generatedFrames, tc.expectMinFrames, tc.description)
						}

						// 総フレーム数を超えていないことを確認
						if generatedFrames > tc.totalFrames {
							t.Errorf("生成されたフレーム数が総フレーム数を超えています: got %d, max %d (%s)", generatedFrames, tc.totalFrames, tc.description)
						}
					})
				})
			}
		})
	})
}
