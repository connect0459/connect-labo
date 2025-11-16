import { describe, test, expect, vi } from "vitest";

/**
 * Test Object Pattern - テストに必要なデータと設定を管理
 */
class DisposableStackTest {
  /**
   * 破棄順序を追跡するためのトラッカー
   */
  createDisposeTracker() {
    return {
      order: [] as string[],
      track(id: string) {
        this.order.push(id);
      },
      reset() {
        this.order = [];
      },
    };
  }

  /**
   * テスト用のDisposableリソースを作成
   */
  createTestResource(id: string, tracker: ReturnType<typeof this.createDisposeTracker>) {
    return {
      id,
      [Symbol.dispose]() {
        tracker.track(id);
      },
    };
  }
}

describe("DisposableStack", () => {
  const testContext = new DisposableStackTest();

  describe("基本機能", () => {
    test("DisposableStackを作成できる", () => {
      const stack = new DisposableStack();

      expect(stack).toBeDefined();
      expect(stack.use).toBeDefined();
      expect(stack.adopt).toBeDefined();
      expect(stack.dispose).toBeDefined();
    });

    test("Symbol.disposeメソッドが実装されている", () => {
      const stack = new DisposableStack();

      expect(stack[Symbol.dispose]).toBeDefined();
      expect(typeof stack[Symbol.dispose]).toBe("function");
    });

    test("usingキーワードで使用できる", () => {
      const disposeSpy = vi.fn();

      {
        using stack = new DisposableStack();
        stack.adopt(null, disposeSpy);
      }

      // スコープ終了時に自動的にdisposeされる
      expect(disposeSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe("use() - Disposableリソースの追加", () => {
    test("Disposableリソースを追加できる", () => {
      const tracker = testContext.createDisposeTracker();
      const resource = testContext.createTestResource("R1", tracker);

      using stack = new DisposableStack();
      stack.use(resource);

      expect(tracker.order).toEqual([]);

      stack.dispose();

      // disposeが呼ばれる
      expect(tracker.order).toEqual(["R1"]);
    });

    test("複数のリソースをLIFO順で破棄する", () => {
      const tracker = testContext.createDisposeTracker();

      using stack = new DisposableStack();
      stack.use(testContext.createTestResource("R1", tracker));
      stack.use(testContext.createTestResource("R2", tracker));
      stack.use(testContext.createTestResource("R3", tracker));

      stack.dispose();

      // LIFO順: R3 -> R2 -> R1
      expect(tracker.order).toEqual(["R3", "R2", "R1"]);
    });

    test("nullやundefinedを追加しても安全", () => {
      using stack = new DisposableStack();

      expect(() => {
        stack.use(null as unknown as Disposable);
        stack.use(undefined as unknown as Disposable);
      }).not.toThrow();

      expect(() => stack.dispose()).not.toThrow();
    });
  });

  describe("adopt() - 任意の値とクリーンアップ関数の登録", () => {
    test("プロトコルを持たない値をクリーンアップできる", () => {
      const cleanupSpy = vi.fn();

      using stack = new DisposableStack();
      stack.adopt("some-value", cleanupSpy);

      expect(cleanupSpy).not.toHaveBeenCalled();

      stack.dispose();

      expect(cleanupSpy).toHaveBeenCalledWith("some-value");
    });

    test("setTimeout/setIntervalのようなIDをクリーンアップできる", () => {
      const clearTimeoutSpy = vi.fn();

      using stack = new DisposableStack();
      const timerId = 12345;
      stack.adopt(timerId, (id) => {
        clearTimeoutSpy(id);
      });

      stack.dispose();

      expect(clearTimeoutSpy).toHaveBeenCalledWith(timerId);
    });

    test("複数のadoptリソースもLIFO順で破棄される", () => {
      const disposeOrder: string[] = [];

      using stack = new DisposableStack();
      stack.adopt("first", (v) => disposeOrder.push(v));
      stack.adopt("second", (v) => disposeOrder.push(v));
      stack.adopt("third", (v) => disposeOrder.push(v));

      stack.dispose();

      // LIFO順: third -> second -> first
      expect(disposeOrder).toEqual(["third", "second", "first"]);
    });
  });

  describe("use()とadopt()の混在", () => {
    test("use()とadopt()を組み合わせて使用できる", () => {
      const disposeOrder: string[] = [];
      const tracker = testContext.createDisposeTracker();
      tracker.track = (id) => disposeOrder.push(id);

      using stack = new DisposableStack();

      stack.use(testContext.createTestResource("use-1", tracker));
      stack.adopt("adopt-1", (v) => disposeOrder.push(v));
      stack.use(testContext.createTestResource("use-2", tracker));
      stack.adopt("adopt-2", (v) => disposeOrder.push(v));

      stack.dispose();

      // 追加順の逆順で破棄される
      expect(disposeOrder).toEqual(["adopt-2", "use-2", "adopt-1", "use-1"]);
    });
  });

  describe("エラー処理", () => {
    test("dispose中にエラーが発生しても、全てのリソースを破棄する", () => {
      const tracker = testContext.createDisposeTracker();

      using stack = new DisposableStack();

      stack.adopt("R1", () => tracker.track("R1"));
      stack.adopt("R2", () => {
        tracker.track("R2");
        throw new Error("Dispose failed!");
      });
      stack.adopt("R3", () => tracker.track("R3"));

      expect(() => stack.dispose()).toThrow("Dispose failed!");

      // エラーが発生してもR1は破棄される（R3 -> R2（エラー）-> R1）
      expect(tracker.order).toContain("R3");
      expect(tracker.order).toContain("R2");
      expect(tracker.order).toContain("R1");
    });

    test("dispose は冪等である", () => {
      const disposeSpy = vi.fn();

      const stack = new DisposableStack();
      stack.adopt(null, disposeSpy);

      stack.dispose();
      stack.dispose();
      stack.dispose();

      // 最初の1回のみ呼ばれる
      expect(disposeSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe("実用例: React useEffectでの使用", () => {
    test("複数のリソースを一元管理できる", () => {
      const cleanupLogs: string[] = [];

      // useEffect内でのパターンをシミュレート
      function simulateUseEffect() {
        const stack = new DisposableStack();

        // タイマーを追加
        const timerId = setTimeout(() => {}, 1000);
        stack.adopt(timerId, (id) => {
          clearTimeout(id);
          cleanupLogs.push("Timer cleared");
        });

        // イベントリスナーを追加（シミュレート）
        const listener = () => {};
        stack.adopt(listener, () => {
          cleanupLogs.push("Listener removed");
        });

        // サブスクリプションを追加（シミュレート）
        const subscription = { unsubscribe: () => cleanupLogs.push("Unsubscribed") };
        stack.adopt(subscription, (sub) => sub.unsubscribe());

        // クリーンアップ関数として stack.dispose を返す
        return () => stack.dispose();
      }

      const cleanup = simulateUseEffect();

      expect(cleanupLogs).toEqual([]);

      // コンポーネントのアンマウント時にクリーンアップ
      cleanup();

      // LIFO順で全てクリーンアップされる
      expect(cleanupLogs).toEqual([
        "Unsubscribed",
        "Listener removed",
        "Timer cleared",
      ]);
    });
  });
});
