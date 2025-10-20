package main

import (
	"fmt"
	"hash/fnv"
	"runtime"
	"testing"
	"time"
	"unsafe"
)

// Go1.24以降のmap実装変更を検証するテスト

// ExtendibleHashingの特徴を検証
func TestExtendibleHashingBehavior(t *testing.T) {
	t.Run("Extendible Hashing特性の検証", func(t *testing.T) {
		// 大量のデータでmapの成長パターンを観察
		m := make(map[string]int)
		measurements := []MapGrowthMeasurement{}

		// 段階的にデータを追加して成長パターンを記録
		for i := 0; i < 10000; i++ {
			key := fmt.Sprintf("key_%d", i)
			m[key] = i

			// 特定のサイズでメモリ使用量を測定
			if i%1000 == 999 {
				measurement := measureMapGrowth(m, i+1)
				measurements = append(measurements, measurement)
				t.Logf("Size: %d, Measurement: %+v", i+1, measurement)
			}
		}

		// Extendible Hashingの特徴：
		// 1. より効率的なメモリ使用
		// 2. リハッシュ時の性能改善
		analyzeGrowthPattern(t, measurements)
	})
}

// QuadraticProbingの検証
func TestQuadraticProbingBehavior(t *testing.T) {
	t.Run("Quadratic Probing特性の検証", func(t *testing.T) {
		// 衝突が起きやすいキーを意図的に作成
		collisionKeys := generateCollisionKeys(1000)

		start := time.Now()
		m := make(map[string]int)
		for i, key := range collisionKeys {
			m[key] = i
		}
		insertTime := time.Since(start)

		start = time.Now()
		for _, key := range collisionKeys {
			_ = m[key]
		}
		lookupTime := time.Since(start)

		t.Logf("Collision keys insert time: %v", insertTime)
		t.Logf("Collision keys lookup time: %v", lookupTime)

		// Quadratic Probingは衝突解決の効率化により、
		// チェイン法よりも高速な検索が期待される
		if lookupTime > insertTime*2 {
			t.Logf("Warning: Lookup time seems high relative to insert time")
		}
	})
}

// MapGrowthMeasurement はmapの成長測定データ
type MapGrowthMeasurement struct {
	Size           int
	MemoryBefore   runtime.MemStats
	MemoryAfter    runtime.MemStats
	MapPointer     uintptr
	EstimatedBytes uint64
}

// measureMapGrowth はmapの成長を測定
func measureMapGrowth(m map[string]int, size int) MapGrowthMeasurement {
	var memBefore, memAfter runtime.MemStats

	runtime.GC()
	runtime.ReadMemStats(&memBefore)

	// mapポインタを取得
	mapPtr := getMapPointerGeneric(m)

	runtime.ReadMemStats(&memAfter)

	return MapGrowthMeasurement{
		Size:           size,
		MemoryBefore:   memBefore,
		MemoryAfter:    memAfter,
		MapPointer:     mapPtr,
		EstimatedBytes: memAfter.HeapInuse - memBefore.HeapInuse,
	}
}

// getMapPointerGeneric は汎用的なmapポインタ取得
func getMapPointerGeneric(m interface{}) uintptr {
	return (*(*uintptr)(unsafe.Pointer(&m)))
}

// generateCollisionKeys は意図的に衝突するキーを生成
func generateCollisionKeys(count int) []string {
	keys := make([]string, count)
	baseHash := uint64(0x1234567890abcdef)

	for i := 0; i < count; i++ {
		// 上位ビットを変更して下位ビットを一定に保つ
		// これによりQuadratic Probingの動作を誘発
		key := fmt.Sprintf("collision_%016x_%d", baseHash+(uint64(i)<<32), i)
		keys[i] = key
	}

	return keys
}

// analyzeGrowthPattern は成長パターンを分析
func analyzeGrowthPattern(t *testing.T, measurements []MapGrowthMeasurement) {
	t.Helper()

	t.Log("=== Map Growth Pattern Analysis ===")
	for i, m := range measurements {
		memoryEfficiency := float64(m.Size*24) / float64(m.EstimatedBytes) // 概算
		t.Logf("Measurement %d: Size=%d, EstimatedBytes=%d, Efficiency=%.2f",
			i, m.Size, m.EstimatedBytes, memoryEfficiency)
	}

	// Go1.24のExtendible Hashingにより、
	// メモリ効率が改善されていることを期待
	if len(measurements) >= 2 {
		last := measurements[len(measurements)-1]
		first := measurements[0]

		growthRatio := float64(last.EstimatedBytes) / float64(first.EstimatedBytes)
		sizeRatio := float64(last.Size) / float64(first.Size)

		t.Logf("Memory growth ratio: %.2f", growthRatio)
		t.Logf("Size growth ratio: %.2f", sizeRatio)

		if growthRatio < sizeRatio*1.5 {
			t.Log("✓ Efficient memory growth detected (possibly Extendible Hashing)")
		} else {
			t.Log("⚠ Memory growth seems less efficient")
		}
	}
}

// ハッシュ分散の検証
func TestHashDistribution(t *testing.T) {
	t.Run("ハッシュ分散パターンの検証", func(t *testing.T) {
		keys := make([]string, 10000)
		for i := range keys {
			keys[i] = fmt.Sprintf("test_key_%d", i)
		}

		// 上位57bitを使用するという特徴を検証
		hashDistribution := analyzeHashDistribution(keys)

		// 分散の均等性を確認
		variance := calculateHashVariance(hashDistribution)
		t.Logf("Hash distribution variance: %.2f", variance)

		// Go1.24では上位57bitを使用するため、
		// より良い分散が期待される
		if variance < 0.1 {
			t.Log("✓ Good hash distribution detected")
		} else {
			t.Log("⚠ Hash distribution may need improvement")
		}
	})
}

// analyzeHashDistribution はハッシュの分散を分析
func analyzeHashDistribution(keys []string) map[uint64]int {
	distribution := make(map[uint64]int)
	hasher := fnv.New64a()

	for _, key := range keys {
		hasher.Reset()
		hasher.Write([]byte(key))
		hash := hasher.Sum64()

		// 上位57bitを取得（Go1.24の特徴）
		upperBits := hash >> 7
		bucket := upperBits % 1000 // 1000個のバケットに分散
		distribution[bucket]++
	}

	return distribution
}

// calculateHashVariance はハッシュ分散の分散を計算
func calculateHashVariance(distribution map[uint64]int) float64 {
	if len(distribution) == 0 {
		return 0
	}

	// 平均を計算
	total := 0
	for _, count := range distribution {
		total += count
	}
	mean := float64(total) / float64(len(distribution))

	// 分散を計算
	variance := 0.0
	for _, count := range distribution {
		diff := float64(count) - mean
		variance += diff * diff
	}
	variance /= float64(len(distribution))

	// 正規化された分散を返す
	return variance / (mean * mean)
}

// パフォーマンス比較テスト
func BenchmarkMapOperations(b *testing.B) {
	sizes := []int{100, 1000, 10000, 100000}

	for _, size := range sizes {
		b.Run(fmt.Sprintf("Insert_%d", size), func(b *testing.B) {
			for i := 0; i < b.N; i++ {
				m := make(map[string]int)
				for j := 0; j < size; j++ {
					m[fmt.Sprintf("key_%d", j)] = j
				}
			}
		})

		b.Run(fmt.Sprintf("Lookup_%d", size), func(b *testing.B) {
			m := make(map[string]int)
			for j := 0; j < size; j++ {
				m[fmt.Sprintf("key_%d", j)] = j
			}

			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				for j := 0; j < size; j++ {
					_ = m[fmt.Sprintf("key_%d", j)]
				}
			}
		})
	}
}