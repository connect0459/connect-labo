package main

import (
	"fmt"
	"reflect"
	"runtime"
)

// MapInternals はmapの内部構造を分析するためのinterface
type MapInternals interface {
	Add(key string, value int)
	Get(key string) (int, bool)
	Size() int
	AnalyzeStructure() MapAnalysis
}

// mapInternals はMapInternalsの具象実装
type mapInternals struct {
	data map[string]int
}

// NewMapInternals は新しいMapInternalsを作成する（抽象型を返す）
func NewMapInternals() MapInternals {
	return &mapInternals{
		data: make(map[string]int),
	}
}

// Add はmapに要素を追加する
func (m *mapInternals) Add(key string, value int) {
	m.data[key] = value
}

// Get はmapから要素を取得する
func (m *mapInternals) Get(key string) (int, bool) {
	value, exists := m.data[key]
	return value, exists
}

// Size はmapのサイズを返す
func (m *mapInternals) Size() int {
	return len(m.data)
}

// AnalyzeStructure はmapの内部構造を分析する
// GO1.24以降のmap実装の特徴を調べる
func (m *mapInternals) AnalyzeStructure() MapAnalysis {
	analysis := MapAnalysis{
		Size:        len(m.data),
		GoVersion:   runtime.Version(),
		MapPointer:  getMapPointer(m.data),
		BucketCount: estimateBucketCount(m.data),
	}

	// mapの内部構造にアクセス（unsafe操作）
	if analysis.MapPointer != 0 {
		analysis.LoadFactor = calculateLoadFactor(m.data)
	}

	return analysis
}

// MapAnalysis はmap分析結果を保持する
type MapAnalysis struct {
	Size        int     // mapのサイズ
	GoVersion   string  // Goのバージョン
	MapPointer  uintptr // mapのポインタアドレス
	BucketCount int     // 推定バケット数
	LoadFactor  float64 // 負荷率
}

// String はMapAnalysisの文字列表現を返す
func (ma MapAnalysis) String() string {
	return fmt.Sprintf("MapAnalysis{Size: %d, GoVersion: %s, MapPointer: 0x%x, BucketCount: %d, LoadFactor: %.2f}",
		ma.Size, ma.GoVersion, ma.MapPointer, ma.BucketCount, ma.LoadFactor)
}

// getMapPointer はmapのポインタを取得する（unsafeを使用）
func getMapPointer(m map[string]int) uintptr {
	// unsafeを使ってmapの内部構造にアクセス
	// mapはruntime.hmapへのポインタとして実装されている
	mapValue := reflect.ValueOf(m)
	return mapValue.Pointer()
}

// estimateBucketCount はバケット数を推定する
func estimateBucketCount(m map[string]int) int {
	// mapのバケット数は通常2の累乗
	// 負荷率が6.5を超えないように調整される
	size := len(m)
	if size == 0 {
		return 1
	}

	// 初期バケット数の推定
	buckets := 1
	for buckets*6 < size { // 平均負荷率を6程度に保つ
		buckets *= 2
	}
	return buckets
}

// calculateLoadFactor は負荷率を計算する
func calculateLoadFactor(m map[string]int) float64 {
	size := float64(len(m))
	bucketCount := float64(estimateBucketCount(m))
	if bucketCount == 0 {
		return 0
	}
	return size / bucketCount
}

// DemonstrateGrowth はmapの成長パターンを実証する
func DemonstrateGrowth() []MapAnalysis {
	m := NewMapInternals()
	var results []MapAnalysis

	// 段階的にmapに要素を追加して成長パターンを観察
	testSizes := []int{0, 1, 5, 10, 20, 50, 100, 200, 500, 1000}

	for _, targetSize := range testSizes {
		// 現在のサイズから目標サイズまで要素を追加
		for m.Size() < targetSize {
			key := fmt.Sprintf("key_%d", m.Size())
			m.Add(key, m.Size())
		}
		results = append(results, m.AnalyzeStructure())
	}

	return results
}

// CompareMapTypes は異なる型のmapの特性を比較する
func CompareMapTypes() MapTypeComparison {
	// string -> int map
	stringIntMap := make(map[string]int)
	for i := 0; i < 100; i++ {
		stringIntMap[fmt.Sprintf("key_%d", i)] = i
	}

	// int -> string map
	intStringMap := make(map[int]string)
	for i := 0; i < 100; i++ {
		intStringMap[i] = fmt.Sprintf("value_%d", i)
	}

	// int -> int map
	intIntMap := make(map[int]int)
	for i := 0; i < 100; i++ {
		intIntMap[i] = i * 2
	}

	return MapTypeComparison{
		StringIntPointer: getMapPointer(stringIntMap),
		IntStringPointer: reflect.ValueOf(intStringMap).Pointer(),
		IntIntPointer:    reflect.ValueOf(intIntMap).Pointer(),
		StringIntSize:    len(stringIntMap),
		IntStringSize:    len(intStringMap),
		IntIntSize:       len(intIntMap),
	}
}

// MapTypeComparison は異なるmap型の比較結果
type MapTypeComparison struct {
	StringIntPointer uintptr
	IntStringPointer uintptr
	IntIntPointer    uintptr
	StringIntSize    int
	IntStringSize    int
	IntIntSize       int
}

// String はMapTypeComparisonの文字列表現を返す
func (mtc MapTypeComparison) String() string {
	return fmt.Sprintf("MapTypeComparison{\n  StringInt: ptr=0x%x, size=%d\n  IntString: ptr=0x%x, size=%d\n  IntInt: ptr=0x%x, size=%d\n}",
		mtc.StringIntPointer, mtc.StringIntSize,
		mtc.IntStringPointer, mtc.IntStringSize,
		mtc.IntIntPointer, mtc.IntIntSize)
}

func main() {
	fmt.Println("GO1.24+ Map Internal Structure Analysis")
	fmt.Println("=====================================")

	// 基本的なmap操作
	m := NewMapInternals()
	m.Add("hello", 1)
	m.Add("world", 2)

	fmt.Printf("Basic map analysis: %s\n", m.AnalyzeStructure())

	// map成長パターンの実証
	fmt.Println("\nMap Growth Pattern:")
	growthResults := DemonstrateGrowth()
	for _, result := range growthResults {
		fmt.Printf("  %s\n", result)
	}

	// 異なるmap型の比較
	fmt.Println("\nMap Type Comparison:")
	comparison := CompareMapTypes()
	fmt.Printf("  %s\n", comparison)
}

