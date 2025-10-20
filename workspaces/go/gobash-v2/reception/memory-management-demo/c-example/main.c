#include <stdio.h>
#include <stdlib.h>

// 未定義動作: ローカル変数のアドレスを返す（危険！）
int* dangerousFunction() {
    int x = 42;
    printf("[C] dangerousFunction: x=%d (address: %p)\n", x, (void*)&x);
    return &x;  // 警告: ローカル変数のアドレスを返している
}

// 安全な方法1: 値をコピーして返す
int safeValueReturn() {
    int x = 42;
    return x;  // 値のコピー
}

// 安全な方法2: ヒープメモリを使用
int* safeHeapReturn() {
    int* x = (int*)malloc(sizeof(int));
    *x = 42;
    printf("[C] safeHeapReturn: x=%d (heap address: %p)\n", *x, (void*)x);
    return x;  // ヒープのアドレスを返すので安全
}

// Sharing Down: 親から子へポインタを渡す（安全）
void sharingDown(int* p) {
    printf("[C] sharingDown: received value=%d (address: %p)\n", *p, (void*)p);
    *p = 100;  // 呼び出し元の変数を変更
}

int main() {
    printf("=== C言語のメモリ管理デモ ===\n\n");

    // 1. 未定義動作のデモ
    printf("--- 1. 未定義動作: ローカル変数のアドレスを返す ---\n");
    int* p = dangerousFunction();
    printf("[C] main: received pointer address: %p\n", (void*)p);
    // printf("[C] main: dereferencing pointer... *p=%d\n", *p);  // これを実行するとSegmentation Fault
    printf("[C] ⚠️  このポインタをデリファレンスすると未定義動作（クラッシュする可能性大）\n");
    printf("[C] ⚠️  スタックフレームが破棄されたため、ポインタは無効\n\n");

    // 2. 安全な値渡し
    printf("--- 2. 安全な方法: 値のコピー ---\n");
    int val = safeValueReturn();
    printf("[C] main: received value=%d (copied)\n", val);
    printf("[C] ✓ 安全: 値がコピーされているので問題なし\n\n");

    // 3. 安全なヒープ割り当て
    printf("--- 3. 安全な方法: ヒープメモリ ---\n");
    int* heapPtr = safeHeapReturn();
    printf("[C] main: received heap pointer=%p, value=%d\n", (void*)heapPtr, *heapPtr);
    printf("[C] ✓ 安全: ヒープメモリなので関数終了後も有効\n");
    free(heapPtr);  // 手動で解放が必要
    printf("[C] ✓ メモリを手動で解放しました\n\n");

    // 4. Sharing Down（安全）
    printf("--- 4. Sharing Down: 親→子へポインタを渡す ---\n");
    int x = 42;
    printf("[C] main: before sharingDown, x=%d (address: %p)\n", x, (void*)&x);
    sharingDown(&x);
    printf("[C] main: after sharingDown, x=%d\n", x);
    printf("[C] ✓ 安全: 呼び出し元のスタックフレームは有効\n\n");

    printf("=== デモ終了 ===\n");
    return 0;
}
