import { describe, test, expect, vi } from "vitest";
import { ManagedResource } from "./01-basic-using";

/**
 * Test Object Pattern - テストに必要なデータと設定を管理
 */
class BasicUsingTest {
  /**
   * リソースの破棄を追跡するモックコンソール
   */
  createMockConsole() {
    return {
      log: vi.fn(),
      logs: [] as string[],
      addLog(message: string) {
        this.logs.push(message);
        this.log(message);
      },
    };
  }
}

describe("基本的なusing宣言", () => {
  // Test Object Pattern - 将来的な拡張用
  const _testContext = new BasicUsingTest();

  describe("ManagedResource", () => {
    test("リソースが作成される", () => {
      const resource = new ManagedResource("Test");

      expect(resource).toBeDefined();
      expect(resource.doWork).toBeDefined();
    });

    test("doWork()でリソースの処理ができる", () => {
      const resource = new ManagedResource("Test");

      expect(() => resource.doWork()).not.toThrow();
    });

    test("Symbol.disposeメソッドが実装されている", () => {
      const resource = new ManagedResource("Test");

      expect(resource[Symbol.dispose]).toBeDefined();
      expect(typeof resource[Symbol.dispose]).toBe("function");
    });

    test("dispose後はdoWork()がエラーをスローする", () => {
      const resource = new ManagedResource("Test");

      resource[Symbol.dispose]();

      expect(() => resource.doWork()).toThrow("Cannot use disposed resource");
    });

    test("disposeは冪等である（複数回呼んでも安全）", () => {
      const resource = new ManagedResource("Test");

      expect(() => {
        resource[Symbol.dispose]();
        resource[Symbol.dispose]();
        resource[Symbol.dispose]();
      }).not.toThrow();
    });
  });

  describe("usingキーワードによる自動破棄", () => {
    test("スコープ終了時にリソースが自動的に破棄される", () => {
      const disposeSpy = vi.fn();

      class TestResource {
        [Symbol.dispose]() {
          disposeSpy();
        }
      }

      {
        using _resource = new TestResource();
        expect(disposeSpy).not.toHaveBeenCalled();
      }

      // スコープ終了後、disposeが呼ばれる
      expect(disposeSpy).toHaveBeenCalledTimes(1);
    });

    test("複数のusingリソースはLIFO順で破棄される", () => {
      const disposeOrder: number[] = [];

      class OrderedResource {
        constructor(private id: number) {}

        [Symbol.dispose]() {
          disposeOrder.push(this.id);
        }
      }

      {
        using _resource1 = new OrderedResource(1);
        using _resource2 = new OrderedResource(2);
        using _resource3 = new OrderedResource(3);
      }

      // LIFO順: 3 -> 2 -> 1
      expect(disposeOrder).toEqual([3, 2, 1]);
    });

    test("例外がスローされてもリソースは確実に破棄される", () => {
      const disposeSpy = vi.fn();

      class TestResource {
        [Symbol.dispose]() {
          disposeSpy();
        }
      }

      expect(() => {
        using _resource = new TestResource();
        throw new Error("Test error");
      }).toThrow("Test error");

      // 例外が発生してもdisposeは呼ばれる
      expect(disposeSpy).toHaveBeenCalledTimes(1);
    });

    test("returnで早期脱出してもリソースは破棄される", () => {
      const disposeSpy = vi.fn();

      class TestResource {
        [Symbol.dispose]() {
          disposeSpy();
        }
      }

      function testFunction(shouldReturn: boolean): string {
        {
          using _resource = new TestResource();

          if (shouldReturn) {
            return "early";
          }
        }

        return "normal";
      }

      const result = testFunction(true);

      expect(result).toBe("early");
      expect(disposeSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe("try...finallyとの比較", () => {
    test("usingを使わない場合、Nullチェックが必須", () => {
      let resource: ManagedResource | null = null;

      try {
        resource = new ManagedResource("TryFinally");
        resource.doWork();
      } finally {
        // Nullチェックが必要
        if (resource) {
          resource[Symbol.dispose]();
        }
      }

      // disposeされている
      expect(() => resource?.doWork()).toThrow();
    });

    test("usingを使う場合、Nullチェックが不要", () => {
      {
        using resource = new ManagedResource("Using");
        resource.doWork();
        // Nullチェック不要、自動破棄
      }

      // このスコープではresourceにアクセスできない（スコープ外）
    });
  });
});
