package main

import (
	"fmt"
	"runtime"
	"testing"
)

// Test Object Pattern - テストに必要なデータと設定を構造体で管理
type MapInternalsTest struct {
	mapInternals MapInternals
}

func TestMapInternals(t *testing.T) {
	setup := func(t *testing.T) *MapInternalsTest {
		t.Helper()
		return &MapInternalsTest{
			mapInternals: NewMapInternals(),
		}
	}

	test := setup(t)

	t.Run("map基本操作", func(t *testing.T) {
		t.Run("新しいmapは空である", func(t *testing.T) {
			if size := test.mapInternals.Size(); size != 0 {
				t.Errorf("新しいmapのサイズが期待値と異なります: got %d, want 0", size)
			}
		})

		t.Run("要素を追加できる", func(t *testing.T) {
			test.mapInternals.Add("test_key", 42)

			if size := test.mapInternals.Size(); size != 1 {
				t.Errorf("要素追加後のサイズが期待値と異なります: got %d, want 1", size)
			}

			value, exists := test.mapInternals.Get("test_key")
			if !exists {
				t.Error("追加した要素が存在しません")
			}
			if value != 42 {
				t.Errorf("取得した値が期待値と異なります: got %d, want 42", value)
			}
		})

		t.Run("存在しない要素の取得は失敗する", func(t *testing.T) {
			_, exists := test.mapInternals.Get("nonexistent_key")
			if exists {
				t.Error("存在しない要素が存在するとして返されました")
			}
		})

		t.Run("同じキーで値を上書きできる", func(t *testing.T) {
			test.mapInternals.Add("overwrite_key", 100)
			test.mapInternals.Add("overwrite_key", 200)

			value, exists := test.mapInternals.Get("overwrite_key")
			if !exists {
				t.Error("上書きした要素が存在しません")
			}
			if value != 200 {
				t.Errorf("上書きした値が期待値と異なります: got %d, want 200", value)
			}
			if size := test.mapInternals.Size(); size != 2 {
				t.Errorf("上書き後のサイズが期待値と異なります: got %d, want 2", size)
			}
		})
	})

	t.Run("map内部構造分析", func(t *testing.T) {
		t.Run("空のmapを分析できる", func(t *testing.T) {
			// 新しいMapInternalsインスタンスを作成（他のテストの影響を受けないように）
			emptyMapInternals := NewMapInternals()
			analysis := emptyMapInternals.AnalyzeStructure()

			if analysis.Size != 0 {
				t.Errorf("空のmapのサイズが期待値と異なります: got %d, want 0", analysis.Size)
			}
			if analysis.GoVersion == "" {
				t.Error("Goバージョン情報が取得できませんでした")
			}
			if analysis.BucketCount < 1 {
				t.Errorf("バケット数が不正です: got %d, want >= 1", analysis.BucketCount)
			}
		})

		t.Run("要素を持つmapを分析できる", func(t *testing.T) {
			// 新しいMapInternalsインスタンスを作成（他のテストの影響を受けないように）
			testMapInternals := NewMapInternals()
			// テスト用にいくつかの要素を追加
			for i := 0; i < 10; i++ {
				testMapInternals.Add(fmt.Sprintf("key_%d", i), i)
			}

			analysis := testMapInternals.AnalyzeStructure()

			if analysis.Size != 10 {
				t.Errorf("mapのサイズが期待値と異なります: got %d, want 10", analysis.Size)
			}
			if analysis.MapPointer == 0 {
				t.Error("mapポインタが取得できませんでした")
			}
			if analysis.LoadFactor <= 0 {
				t.Errorf("負荷率が不正です: got %f, want > 0", analysis.LoadFactor)
			}
		})

		t.Run("MapAnalysisの文字列表現が適切である", func(t *testing.T) {
			// 新しいMapInternalsインスタンスを作成（他のテストの影響を受けないように）
			stringTestMapInternals := NewMapInternals()
			stringTestMapInternals.Add("string_test", 1)
			analysis := stringTestMapInternals.AnalyzeStructure()

			str := analysis.String()
			if str == "" {
				t.Error("MapAnalysisの文字列表現が空です")
			}
			// 基本的な構成要素が含まれていることを確認
			expectedElements := []string{"MapAnalysis", "Size:", "GoVersion:", "MapPointer:", "BucketCount:", "LoadFactor:"}
			for _, element := range expectedElements {
				if !containsString(str, element) {
					t.Errorf("文字列表現に必要な要素が含まれていません: %s", element)
				}
			}
		})
	})
}

func TestDemonstrateGrowth(t *testing.T) {
	t.Run("map成長パターンの実証", func(t *testing.T) {
		t.Run("成長パターン分析結果が適切である", func(t *testing.T) {
			results := DemonstrateGrowth()

			if len(results) == 0 {
				t.Error("成長パターン分析結果が空です")
			}

			// 結果が昇順でサイズが増加していることを確認
			for i := 1; i < len(results); i++ {
				if results[i].Size < results[i-1].Size {
					t.Errorf("サイズが減少しています: index %d (size %d) < index %d (size %d)",
						i, results[i].Size, i-1, results[i-1].Size)
				}
			}

			// 最初の結果は空のmapであることを確認
			if results[0].Size != 0 {
				t.Errorf("最初の結果が空のmapではありません: got size %d, want 0", results[0].Size)
			}

			// 全ての結果でGoVersionが設定されていることを確認
			for i, result := range results {
				if result.GoVersion == "" {
					t.Errorf("結果 %d でGoVersionが設定されていません", i)
				}
			}
		})

		t.Run("負荷率が妥当な範囲にある", func(t *testing.T) {
			results := DemonstrateGrowth()

			for i, result := range results {
				// 空のmapを除いて負荷率をチェック
				if result.Size > 0 {
					if result.LoadFactor <= 0 || result.LoadFactor > 20 {
						t.Errorf("結果 %d の負荷率が妥当な範囲外です: got %f, want 0 < LoadFactor <= 20",
							i, result.LoadFactor)
					}
				}
			}
		})
	})
}

func TestCompareMapTypes(t *testing.T) {
	t.Run("異なるmap型の比較", func(t *testing.T) {
		t.Run("map型比較結果が適切である", func(t *testing.T) {
			comparison := CompareMapTypes()

			// 全てのmapが同じサイズ（100要素）であることを確認
			expectedSize := 100
			if comparison.StringIntSize != expectedSize {
				t.Errorf("StringIntmapのサイズが期待値と異なります: got %d, want %d",
					comparison.StringIntSize, expectedSize)
			}
			if comparison.IntStringSize != expectedSize {
				t.Errorf("IntStringmapのサイズが期待値と異なります: got %d, want %d",
					comparison.IntStringSize, expectedSize)
			}
			if comparison.IntIntSize != expectedSize {
				t.Errorf("IntIntmapのサイズが期待値と異なります: got %d, want %d",
					comparison.IntIntSize, expectedSize)
			}

			// 全てのmapポインタが設定されていることを確認
			if comparison.StringIntPointer == 0 {
				t.Error("StringIntmapのポインタが設定されていません")
			}
			if comparison.IntStringPointer == 0 {
				t.Error("IntStringmapのポインタが設定されていません")
			}
			if comparison.IntIntPointer == 0 {
				t.Error("IntIntmapのポインタが設定されていません")
			}

			// 異なるmap型は異なるポインタアドレスを持つことを確認
			pointers := []uintptr{
				comparison.StringIntPointer,
				comparison.IntStringPointer,
				comparison.IntIntPointer,
			}
			for i := 0; i < len(pointers); i++ {
				for j := i + 1; j < len(pointers); j++ {
					if pointers[i] == pointers[j] {
						t.Errorf("map型 %d と %d が同じポインタアドレスを持っています: 0x%x",
							i, j, pointers[i])
					}
				}
			}
		})

		t.Run("MapTypeComparisonの文字列表現が適切である", func(t *testing.T) {
			comparison := CompareMapTypes()
			str := comparison.String()

			if str == "" {
				t.Error("MapTypeComparisonの文字列表現が空です")
			}

			// 基本的な構成要素が含まれていることを確認
			expectedElements := []string{"MapTypeComparison", "StringInt:", "IntString:", "IntInt:", "ptr=", "size="}
			for _, element := range expectedElements {
				if !containsString(str, element) {
					t.Errorf("文字列表現に必要な要素が含まれていません: %s", element)
				}
			}
		})
	})
}

// Helper function - テスト内部構造の妥当性検証
func TestMapInternalsStructure(t *testing.T) {
	t.Run("MapInternals構造体", func(t *testing.T) {
		t.Run("NewMapInternalsは正しく初期化される", func(t *testing.T) {
			m := NewMapInternals()

			if m == nil {
				t.Error("NewMapInternalsがnilを返しました")
			}
			if m.Size() != 0 {
				t.Errorf("新しいMapInternalsが空ではありません: got size %d, want 0", m.Size())
			}
		})
	})

	t.Run("バケット数推定機能", func(t *testing.T) {
		testCases := []struct {
			name           string
			mapSize        int
			expectedMinBuckets int
		}{
			{"空のmap", 0, 1},
			{"小さなmap", 1, 1},
			{"中程度のmap", 10, 2},
			{"大きなmap", 50, 8},
			{"非常に大きなmap", 200, 32},
		}

		for _, tc := range testCases {
			t.Run(tc.name, func(t *testing.T) {
				// テスト用mapを作成
				testMap := make(map[string]int)
				for i := 0; i < tc.mapSize; i++ {
					testMap[fmt.Sprintf("key_%d", i)] = i
				}

				bucketCount := estimateBucketCount(testMap)
				if bucketCount < tc.expectedMinBuckets {
					t.Errorf("推定バケット数が最小期待値を下回ります: got %d, want >= %d",
						bucketCount, tc.expectedMinBuckets)
				}

				// バケット数は2の累乗であることを確認
				if !isPowerOfTwo(bucketCount) {
					t.Errorf("バケット数が2の累乗ではありません: %d", bucketCount)
				}
			})
		}
	})

	t.Run("負荷率計算機能", func(t *testing.T) {
		t.Run("空のmapの負荷率は0である", func(t *testing.T) {
			emptyMap := make(map[string]int)
			loadFactor := calculateLoadFactor(emptyMap)
			if loadFactor != 0 {
				t.Errorf("空のmapの負荷率が0ではありません: got %f, want 0", loadFactor)
			}
		})

		t.Run("要素を持つmapの負荷率が正しく計算される", func(t *testing.T) {
			testMap := make(map[string]int)
			testMap["key1"] = 1
			testMap["key2"] = 2

			loadFactor := calculateLoadFactor(testMap)
			if loadFactor <= 0 {
				t.Errorf("負荷率が正の値ではありません: got %f, want > 0", loadFactor)
			}
		})
	})
}

// Runtime Version確認テスト
func TestRuntimeInfo(t *testing.T) {
	t.Run("ランタイム情報", func(t *testing.T) {
		t.Run("Goバージョンが取得できる", func(t *testing.T) {
			version := runtime.Version()
			if version == "" {
				t.Error("Goバージョンが取得できませんでした")
			}
			// Go1.24以降であることを確認したい場合のヒント
			t.Logf("実行中のGoバージョン: %s", version)
		})
	})
}

// Helper functions for tests
func containsString(s, substr string) bool {
	return len(s) >= len(substr) && s[:len(substr)] == substr ||
		   (len(s) > len(substr) && containsStringRecursive(s[1:], substr))
}

func containsStringRecursive(s, substr string) bool {
	if len(s) < len(substr) {
		return false
	}
	if s[:len(substr)] == substr {
		return true
	}
	return containsStringRecursive(s[1:], substr)
}

func isPowerOfTwo(n int) bool {
	return n > 0 && (n&(n-1)) == 0
}

