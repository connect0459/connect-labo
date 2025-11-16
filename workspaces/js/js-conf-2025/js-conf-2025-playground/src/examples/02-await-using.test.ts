import { describe, test, expect, vi } from "vitest";
import { DatabaseConnection, Transaction } from "./02-await-using";

/**
 * Test Object Pattern - テストに必要なデータと設定を管理
 */
class AwaitUsingTest {
  /**
   * 非同期操作の遅延をシミュレート
   */
  async delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

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
}

describe("await using宣言", () => {
  const testContext = new AwaitUsingTest();

  describe("DatabaseConnection", () => {
    test("データベース接続を確立できる", async () => {
      const db = await DatabaseConnection.connect("testdb");

      expect(db).toBeDefined();
      expect(db.query).toBeDefined();
    });

    test("Symbol.asyncDisposeメソッドが実装されている", async () => {
      const db = await DatabaseConnection.connect("testdb");

      expect(db[Symbol.asyncDispose]).toBeDefined();
      expect(typeof db[Symbol.asyncDispose]).toBe("function");
    });

    test("クエリを実行できる", async () => {
      const db = await DatabaseConnection.connect("testdb");

      const result = await db.query("SELECT * FROM users");

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    test("破棄後はクエリを実行できない", async () => {
      const db = await DatabaseConnection.connect("testdb");

      await db[Symbol.asyncDispose]();

      await expect(db.query("SELECT 1")).rejects.toThrow(
        "Connection is closed"
      );
    });

    test("dispose は冪等である", async () => {
      const db = await DatabaseConnection.connect("testdb");

      await db[Symbol.asyncDispose]();
      await db[Symbol.asyncDispose]();
      await db[Symbol.asyncDispose]();

      // エラーが発生しない
    });
  });

  describe("await usingキーワードによる自動破棄", () => {
    test("スコープ終了時にリソースが自動的に破棄される", async () => {
      const disposeSpy = vi.fn();

      class AsyncTestResource {
        async [Symbol.asyncDispose]() {
          disposeSpy();
        }
      }

      {
        await using _resource = new AsyncTestResource();
        expect(disposeSpy).not.toHaveBeenCalled();
      }

      // スコープ終了後、asyncDisposeが呼ばれる
      expect(disposeSpy).toHaveBeenCalledTimes(1);
    });

    test("複数のawait usingリソースはLIFO順で破棄される", async () => {
      const disposeOrder: number[] = [];

      class OrderedAsyncResource {
        constructor(private id: number) {}

        async [Symbol.asyncDispose]() {
          await testContext.delay(10);
          disposeOrder.push(this.id);
        }
      }

      {
        await using _resource1 = new OrderedAsyncResource(1);
        await using _resource2 = new OrderedAsyncResource(2);
        await using _resource3 = new OrderedAsyncResource(3);
      }

      // LIFO順: 3 -> 2 -> 1
      expect(disposeOrder).toEqual([3, 2, 1]);
    });

    test("例外がスローされてもリソースは確実に破棄される", async () => {
      const disposeSpy = vi.fn();

      class AsyncTestResource {
        async [Symbol.asyncDispose]() {
          disposeSpy();
        }
      }

      await expect(async () => {
        await using _resource = new AsyncTestResource();
        throw new Error("Test error");
      }).rejects.toThrow("Test error");

      // 例外が発生してもdisposeは呼ばれる
      expect(disposeSpy).toHaveBeenCalledTimes(1);
    });

    test("returnで早期脱出してもリソースは破棄される", async () => {
      const disposeSpy = vi.fn();

      class AsyncTestResource {
        async [Symbol.asyncDispose]() {
          disposeSpy();
        }
      }

      async function testFunction(shouldReturn: boolean): Promise<string> {
        {
          await using _resource = new AsyncTestResource();

          if (shouldReturn) {
            return "early";
          }
        }

        return "normal";
      }

      const result = await testFunction(true);

      expect(result).toBe("early");
      expect(disposeSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe("Transaction（トランザクション管理）", () => {
    test("トランザクションを開始できる", async () => {
      const db = await DatabaseConnection.connect("testdb");
      const tx = new Transaction(db);

      expect(tx).toBeDefined();
      expect(tx.execute).toBeDefined();
      expect(tx.commit).toBeDefined();
      expect(tx.rollback).toBeDefined();
    });

    test("トランザクション内でクエリを実行できる", async () => {
      const db = await DatabaseConnection.connect("testdb");
      const tx = new Transaction(db);

      await expect(
        tx.execute("INSERT INTO users (name) VALUES ('Alice')")
      ).resolves.not.toThrow();

      await db[Symbol.asyncDispose]();
    });

    test("コミットされていないトランザクションは自動的にロールバックされる", async () => {
      const db = await DatabaseConnection.connect("testdb");
      const rollbackSpy = vi.spyOn(Transaction.prototype, "rollback");

      {
        await using tx = new Transaction(db);
        await tx.execute("INSERT INTO users (name) VALUES ('Alice')");
        // コミットせずにスコープを抜ける
      }

      // 自動ロールバックが呼ばれる
      expect(rollbackSpy).toHaveBeenCalled();

      rollbackSpy.mockRestore();
      await db[Symbol.asyncDispose]();
    });

    test("コミットされたトランザクションは自動ロールバックされない", async () => {
      const db = await DatabaseConnection.connect("testdb");
      const rollbackSpy = vi.spyOn(Transaction.prototype, "rollback");

      {
        await using tx = new Transaction(db);
        await tx.execute("INSERT INTO users (name) VALUES ('Bob')");
        await tx.commit();
      }

      // コミット済みなので、ロールバックは呼ばれない
      expect(rollbackSpy).not.toHaveBeenCalled();

      rollbackSpy.mockRestore();
      await db[Symbol.asyncDispose]();
    });

    test("例外発生時は自動的にロールバックされる", async () => {
      const db = await DatabaseConnection.connect("testdb");
      const rollbackSpy = vi.spyOn(Transaction.prototype, "rollback");

      await expect(async () => {
        await using tx = new Transaction(db);
        await tx.execute("INSERT INTO users (name) VALUES ('Charlie')");
        throw new Error("Transaction failed!");
      }).rejects.toThrow("Transaction failed!");

      // 例外発生時も自動ロールバックされる
      expect(rollbackSpy).toHaveBeenCalled();

      rollbackSpy.mockRestore();
      await db[Symbol.asyncDispose]();
    });
  });

  describe("try...finallyとの比較", () => {
    test("従来の方法ではNullチェックが必須", async () => {
      let db: DatabaseConnection | null = null;

      try {
        db = await DatabaseConnection.connect("testdb");
        await db.query("SELECT * FROM users");
      } finally {
        // Nullチェックが必要
        if (db) {
          await db[Symbol.asyncDispose]();
        }
      }

      // disposeされている
      await expect(db?.query("SELECT 1")).rejects.toThrow();
    });

    test("await usingを使う場合、Nullチェックが不要", async () => {
      {
        await using db = await DatabaseConnection.connect("testdb");
        await db.query("SELECT * FROM users");
        // Nullチェック不要、自動破棄
      }

      // このスコープではdbにアクセスできない（スコープ外）
    });
  });
});
