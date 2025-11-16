/**
 * await using 宣言のサンプル
 *
 * await usingは、リソースの取得や破棄が非同期処理を伴う場合に使用します。
 * Symbol.asyncDisposeメソッドを実装したオブジェクトに対して使用できます。
 */

/**
 * 模擬データベース接続クラス
 *
 * 非同期のリソース取得と破棄を行う例
 */
export class DatabaseConnection {
  private connectionId: string;
  private isConnected = false;

  private constructor(connectionId: string) {
    this.connectionId = connectionId;
  }

  /**
   * データベースへの接続を確立（非同期）
   */
  static async connect(dbName: string): Promise<DatabaseConnection> {
    console.log(`[DB] Connecting to ${dbName}...`);
    // 接続処理をシミュレート
    await new Promise((resolve) => setTimeout(resolve, 10));

    const connection = new DatabaseConnection(`conn-${Date.now()}`);
    connection.isConnected = true;

    return connection;
  }

  /**
   * クエリ実行（非同期）
   */
  async query(sql: string): Promise<unknown[]> {
    if (!this.isConnected) {
      throw new Error("Connection is closed");
    }

    console.log(`[DB:${this.connectionId}] Executing: ${sql}`);
    await new Promise((resolve) => setTimeout(resolve, 5));

    return [{ id: 1, name: "Sample Data" }];
  }

  /**
   * Symbol.asyncDispose メソッド - await using宣言によって自動的に呼び出される
   *
   * 非同期のクリーンアップ処理を実装します
   */
  async [Symbol.asyncDispose](): Promise<void> {
    if (!this.isConnected) {
      return;
    }

    console.log(`[DB:${this.connectionId}] Disconnecting...`);
    await new Promise((resolve) => setTimeout(resolve, 10));

    this.isConnected = false;
  }
}

/**
 * トランザクション管理クラス
 *
 * Symbol.asyncDispose内で、正常終了時はCOMMIT、
 * 異常終了時はROLLBACKを自動実行する例
 */
export class Transaction {
  private isCommitted = false;
  private isRolledBack = false;

  constructor(private db: DatabaseConnection) {}

  async execute(sql: string): Promise<void> {
    await this.db.query(sql);
  }

  async commit(): Promise<void> {
    this.isCommitted = true;
  }

  async rollback(): Promise<void> {
    this.isRolledBack = true;
  }

  /**
   * スコープ終了時の自動処理
   * - 正常終了（コミットされていない）: ROLLBACK
   * - 例外発生: ROLLBACK
   * - 明示的にコミット済み: 何もしない
   */
  async [Symbol.asyncDispose](): Promise<void> {
    if (!this.isCommitted && !this.isRolledBack) {
      await this.rollback();
    }
  }
}
