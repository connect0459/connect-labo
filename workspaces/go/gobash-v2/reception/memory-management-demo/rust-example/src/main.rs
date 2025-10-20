
// コンパイルエラーになる例（借用チェッカーが防ぐ）
// fn invalid_return() -> &i32 {
//     let x = 42;
//     &x  // エラー: `x` does not live long enough
// }

// 正しい方法1: 値を返す
fn value_return() -> i32 {
    let x = 42;
    println!("[Rust] value_return: x={} (stack address: {:p})", x, &x);
    x // 値のコピー
}

// 正しい方法2: Boxを使ってヒープに確保
fn heap_return() -> Box<i32> {
    let x = Box::new(42);
    println!("[Rust] heap_return: x={} (heap address: {:p})", x, &*x);
    x // ヒープ上のデータの所有権を移動
}

// 参照を渡す（借用）- Sharing Downに相当
fn sharing_down(p: &mut i32) {
    println!("[Rust] sharing_down: received value={} (address: {:p})", p, p);
    *p = 100;
}

// ライフタイムパラメータを使った安全な参照の返却
fn get_first<'a>(data: &'a [i32]) -> &'a i32 {
    println!("[Rust] get_first: returning reference to first element");
    &data[0]
}

// 構造体の例
struct LargeStruct {
    data: [i32; 10000], // 約40KB
}

impl LargeStruct {
    fn new() -> Self {
        let ls = LargeStruct { data: [0; 10000] };
        println!("[Rust] LargeStruct::new: address={:p}", &ls);
        ls
    }

    fn new_boxed() -> Box<Self> {
        let ls = Box::new(LargeStruct { data: [0; 10000] });
        println!("[Rust] LargeStruct::new_boxed: heap address={:p}", &*ls);
        ls
    }
}

fn main() {
    println!("=== Rust言語の借用チェッカーとメモリ管理デモ ===\n");

    // 1. コンパイルエラーの説明
    println!("--- 1. 借用チェッカーによる安全性保証 ---");
    println!("[Rust] 以下のコードはコンパイルエラーになります:");
    println!("[Rust]   fn invalid_return() -> &i32 {{");
    println!("[Rust]       let x = 42;");
    println!("[Rust]       &x  // エラー: `x` does not live long enough");
    println!("[Rust]   }}");
    println!("[Rust] ✓ コンパイル時にダングリングポインタを防ぐ\n");

    // 2. 値を返す（スタック）
    println!("--- 2. 値を返す: スタックで完結 ---");
    let val = value_return();
    println!("[Rust] main: received value={}", val);
    println!("[Rust] ✓ 値のコピーなので安全\n");

    // 3. Boxを使ってヒープに確保
    println!("--- 3. Box: ヒープに確保して所有権を移動 ---");
    let boxed = heap_return();
    println!("[Rust] main: received Box value={} (address: {:p})", boxed, &*boxed);
    println!("[Rust] ✓ 所有権の移動により安全性を保証");
    println!("[Rust] ✓ スコープを抜けると自動的にメモリ解放（RAII）\n");

    // 4. 借用（Sharing Down）
    println!("--- 4. 借用: Sharing Downに相当 ---");
    let mut x = 42;
    println!("[Rust] main: before sharing_down, x={} (address: {:p})", x, &x);
    sharing_down(&mut x);
    println!("[Rust] main: after sharing_down, x={}", x);
    println!("[Rust] ✓ 可変借用により、呼び出し先で値を変更可能\n");

    // 5. ライフタイムパラメータ
    println!("--- 5. ライフタイムパラメータ: 安全な参照の返却 ---");
    let data = vec![1, 2, 3, 4, 5];
    let first = get_first(&data);
    println!("[Rust] main: first element={}", first);
    println!("[Rust] ✓ ライフタイムパラメータで参照の有効期間を保証\n");

    // 6. 大きな構造体: スタック vs ヒープ
    println!("--- 6. 大きな構造体: スタック vs ヒープ ---");
    println!("[Rust] スタックに確保（値のムーブ）:");
    let _ls1 = LargeStruct::new();
    println!("[Rust] ✓ ムーブセマンティクスによりコピーを回避");

    println!("\n[Rust] ヒープに確保（Box）:");
    let _ls2 = LargeStruct::new_boxed();
    println!("[Rust] ✓ 大きなデータはヒープに確保して参照のみ渡す\n");

    // 7. 所有権とムーブセマンティクス
    println!("--- 7. 所有権とムーブセマンティクス ---");
    let s1 = String::from("hello");
    println!("[Rust] s1: {}", s1);
    let s2 = s1; // s1からs2に所有権が移動
    // println!("{}", s1); // コンパイルエラー: s1はもう使えない
    println!("[Rust] s2: {} (所有権が移動)", s2);
    println!("[Rust] ✓ 所有権システムにより二重解放を防ぐ\n");

    // 8. RustとGoの比較
    println!("--- 8. RustとGoの違い ---");
    println!("[Rust] 💡 Rust: コンパイル時にメモリ安全性を保証（借用チェッカー）");
    println!("[Rust] 💡 Go: ランタイムのエスケープ解析とGC");
    println!("[Rust] 💡 Rust: GC不要、予測可能なパフォーマンス");
    println!("[Rust] 💡 Go: GCあり、使いやすさ重視");
    println!("[Rust] 💡 どちらも安全だが、アプローチが異なる\n");

    println!("=== デモ終了 ===");
}
