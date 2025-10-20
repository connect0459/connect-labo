package main

import (
	"fmt"
	"runtime"
)

// Sharing Up: 子から親へポインタを返す（エスケープ解析により自動的にヒープへ）
func sharingUp() *int {
	x := 42
	fmt.Printf("[Go] sharingUp: x=%d (address: %p)\n", x, &x)
	return &x // xは自動的にヒープに確保される
}

// 値を返す場合（スタックで完結）
func valueReturn() int {
	y := 100
	fmt.Printf("[Go] valueReturn: y=%d (address: %p)\n", y, &y)
	return y // 値のコピー
}

// Sharing Down: 親から子へポインタを渡す（スタックで安全）
func sharingDown(p *int) {
	fmt.Printf("[Go] sharingDown: received value=%d (address: %p)\n", *p, p)
	*p = 200
}

// 大きな構造体の例
type LargeStruct struct {
	data [10000]int // 約80KB
}

// 値で返す（コピーコストが大きい）
func createLargeValue() LargeStruct {
	var ls LargeStruct
	ls.data[0] = 1
	fmt.Printf("[Go] createLargeValue: address=%p\n", &ls)
	return ls // 80KBのコピーが発生
}

// ポインタで返す（ヒープに確保、コピーは8バイトのポインタのみ）
func createLargePointer() *LargeStruct {
	ls := &LargeStruct{}
	ls.data[0] = 1
	fmt.Printf("[Go] createLargePointer: address=%p\n", ls)
	return ls // ポインタのコピーのみ（8バイト）
}

// メモリ統計を表示
func printMemStats(label string) {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	fmt.Printf("[Go] %s - Alloc=%v KB, TotalAlloc=%v KB, HeapAlloc=%v KB\n",
		label,
		m.Alloc/1024,
		m.TotalAlloc/1024,
		m.HeapAlloc/1024)
}

func main() {
	fmt.Println("=== Go言語のエスケープ解析とメモリ管理デモ ===")

	// 1. Sharing Up（戻り値がポインタ）
	fmt.Println("--- 1. Sharing Up: 子→親へポインタを返す ---")
	p := sharingUp()
	fmt.Printf("[Go] main: received pointer address=%p, value=%d\n", p, *p)
	fmt.Println("[Go] ✓ 安全: エスケープ解析により自動的にヒープに確保される")

	// 2. 値渡し
	fmt.Println("--- 2. 値渡し: スタックで完結 ---")
	val := valueReturn()
	fmt.Printf("[Go] main: received value=%d (copied)\n", val)
	fmt.Println("[Go] ✓ スタック上で高速に動作")

	// 3. Sharing Down（引数がポインタ）
	fmt.Println("--- 3. Sharing Down: 親→子へポインタを渡す ---")
	x := 42
	fmt.Printf("[Go] main: before sharingDown, x=%d (address: %p)\n", x, &x)
	sharingDown(&x)
	fmt.Printf("[Go] main: after sharingDown, x=%d\n", x)
	fmt.Println("[Go] ✓ 安全: 呼び出し元のスタックフレームは有効")

	// 4. 大きな構造体のパフォーマンス比較
	fmt.Println("--- 4. 大きな構造体: 値渡し vs ポインタ渡し ---")
	printMemStats("Before allocation")

	fmt.Println("\n[Go] 値で返す場合（コピーコストが大きい）:")
	ls1 := createLargeValue()
	fmt.Printf("[Go] main: received LargeStruct (value), data[0]=%d, address=%p\n", ls1.data[0], &ls1)
	printMemStats("After value return")

	fmt.Println("\n[Go] ポインタで返す場合（ヒープ確保、コピーは小さい）:")
	ls2 := createLargePointer()
	fmt.Printf("[Go] main: received *LargeStruct (pointer), data[0]=%d, address=%p\n", ls2.data[0], ls2)
	printMemStats("After pointer return")

	fmt.Println("\n[Go] 💡 大きなデータではポインタの方が効率的（ただしGCの対象）")

	// 5. エスケープ解析のヒント
	fmt.Println("\n--- 5. エスケープ解析の確認方法 ---")
	fmt.Println("[Go] コンパイル時に以下のコマンドで確認できます:")
	fmt.Println("[Go]   go build -gcflags=\"-m\" main.go")
	fmt.Println("[Go] 出力例:")
	fmt.Println("[Go]   ./main.go:8:2: moved to heap: x")
	fmt.Println("[Go] ✓ これにより、どの変数がヒープに確保されるかが分かる")

	fmt.Println("=== デモ終了 ===")
}
