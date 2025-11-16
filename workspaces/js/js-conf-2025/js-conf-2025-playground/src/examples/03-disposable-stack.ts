/**
 * DisposableStack の使用例
 *
 * DisposableStackは、複数のリソースを命令的に管理するためのコンテナです。
 * usingキーワードと組み合わせることで、React useEffectなどの複雑なクリーンアップを簡潔に記述できます。
 */

/**
 * 例1: 複数のリソースをまとめて管理
 *
 * DisposableStackを使って、複数の異なる種類のリソースを一元管理します
 */
export function multipleResourcesExample(): void {
  using stack = new DisposableStack();

  // タイマーを登録
  const timerId = setTimeout(() => {
    console.log("Timer fired!");
  }, 5000);
  stack.adopt(timerId, (id) => {
    clearTimeout(id);
    console.log("Timer cleared");
  });

  // Disposableプロトコルを実装したリソースを登録
  const resource = {
    name: "MyResource",
    [Symbol.dispose]() {
      console.log(`${this.name} disposed`);
    },
  };
  stack.use(resource);

  // イベントリスナーを登録（仮想的な例）
  const listener = () => console.log("Event");
  stack.adopt(listener, () => {
    console.log("Listener removed");
  });

  // スコープ終了時、LIFO順（listener -> resource -> timer）で全てクリーンアップされる
}

/**
 * 例2: 動的なリソース管理
 *
 * 条件に応じてリソースを動的に追加するパターン
 */
export function dynamicResourceManagement(enableLogging: boolean, enableMetrics: boolean): void {
  using stack = new DisposableStack();

  if (enableLogging) {
    const logger = {
      log(message: string) {
        console.log(`[LOG] ${message}`);
      },
      [Symbol.dispose]() {
        console.log("[LOG] Logger disposed");
      },
    };
    stack.use(logger);
  }

  if (enableMetrics) {
    const metricsCollector = {
      collect() {
        console.log("[METRICS] Collecting...");
      },
      [Symbol.dispose]() {
        console.log("[METRICS] Metrics collector disposed");
      },
    };
    stack.use(metricsCollector);
  }

  // 有効化されたリソースのみが、スコープ終了時に破棄される
}

/**
 * 例3: React useEffect での使用パターン
 *
 * DisposableStackを使うことで、useEffectのクリーンアップを簡潔に記述できます
 */
export function createUseEffectCleanupPattern() {
  /**
   * 従来のuseEffectパターン（アンチパターン）
   */
  function traditionalUseEffect(_id: string) {
    // 複数のリソースを個別に管理
    const timerId = setTimeout(() => {}, 1000);
    const subscription = { unsubscribe: () => {} };
    const controller = new AbortController();

    // クリーンアップ関数で、全てを手動で管理
    return () => {
      clearTimeout(timerId);
      subscription.unsubscribe();
      controller.abort();
    };
  }

  /**
   * DisposableStackを使ったuseEffectパターン（推奨）
   */
  function modernUseEffect(_id: string) {
    const stack = new DisposableStack();

    // タイマー
    const timerId = setTimeout(() => {}, 1000);
    stack.adopt(timerId, clearTimeout);

    // サブスクリプション
    const subscription = { unsubscribe: () => {} };
    stack.adopt(subscription, (sub) => sub.unsubscribe());

    // AbortController
    const controller = new AbortController();
    stack.adopt(controller, (ctrl) => ctrl.abort());

    // クリーンアップ関数は1行
    return () => stack.dispose();
  }

  return { traditionalUseEffect, modernUseEffect };
}

/**
 * 例4: エラーハンドリング
 *
 * dispose中にエラーが発生しても、全てのリソースを確実に破棄します
 */
export function errorHandlingExample(): void {
  try {
    using stack = new DisposableStack();

    stack.adopt("Resource1", () => console.log("Resource1 disposed"));
    stack.adopt("Resource2", () => {
      console.log("Resource2 disposed");
      throw new Error("Dispose failed!");
    });
    stack.adopt("Resource3", () => console.log("Resource3 disposed"));

    // 何か処理...
  } catch (error) {
    console.error("Error during disposal:", error);
  }
  // Resource3, Resource2（エラー）, Resource1 の順で破棄される
  // エラーが発生しても、Resource1は確実に破棄される
}

/**
 * 例5: AsyncDisposableStack（非同期版）
 *
 * 非同期のクリーンアップが必要な場合は、AsyncDisposableStackを使用します
 */
export async function asyncDisposableStackExample(): Promise<void> {
  await using stack = new AsyncDisposableStack();

  // 非同期のクリーンアップが必要なリソース
  const db = {
    name: "Database",
    async [Symbol.asyncDispose]() {
      console.log(`${this.name}: Closing connection...`);
      await new Promise((resolve) => setTimeout(resolve, 100));
      console.log(`${this.name}: Connection closed`);
    },
  };
  stack.use(db);

  // 非同期のクリーンアップ関数を持つリソース
  const fileHandle = {};
  stack.adopt(fileHandle, async () => {
    console.log("Closing file handle...");
    await new Promise((resolve) => setTimeout(resolve, 50));
    console.log("File handle closed");
  });

  // スコープ終了時、全ての非同期クリーンアップが await される
}
