import { useState } from "react";

/**
 * React イベントハンドラでの await using の使用例
 *
 * イベントハンドラ内で await using を使用することで、
 * リソースのクリーンアップを自動化できます。
 */

/**
 * 模擬APIクライアントクラス
 */
class ApiClient {
  private constructor(private endpoint: string) {}

  static async connect(endpoint: string): Promise<ApiClient> {
    console.log(`[API] Connecting to ${endpoint}...`);
    await new Promise((resolve) => setTimeout(resolve, 100));
    console.log(`[API] Connected`);
    return new ApiClient(endpoint);
  }

  async post(data: unknown): Promise<{ success: boolean }> {
    console.log(`[API] Posting data to ${this.endpoint}:`, data);
    await new Promise((resolve) => setTimeout(resolve, 200));
    return { success: true };
  }

  async [Symbol.asyncDispose](): Promise<void> {
    console.log(`[API] Disconnecting from ${this.endpoint}...`);
    await new Promise((resolve) => setTimeout(resolve, 50));
    console.log(`[API] Disconnected`);
  }
}

/**
 * 例1: フォーム送信ハンドラでの await using
 *
 * フォーム送信時にAPI接続を確立し、送信後に自動的にクローズします
 */
export function FormWithAwaitUsing() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  /**
   * await using を使ったフォーム送信ハンドラ
   *
   * API接続は、ハンドラのスコープ内でのみ有効で、
   * 成功・失敗に関わらず自動的にクローズされます
   */
  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(false);

    try {
      // await using でAPI接続を管理
      await using api = await ApiClient.connect("/api/users");

      // データを送信
      const result = await api.post({ name, email });

      if (result.success) {
        setSuccess(true);
        setName("");
        setEmail("");
      }

      // スコープ終了時に自動的に api[Symbol.asyncDispose]() が呼ばれる
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
      // エラー発生時も、API接続は確実にクローズされる
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <h2>Form with await using</h2>
      <form onSubmit={handleSubmit}>
        <div>
          <label>
            Name:
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
          </label>
        </div>
        <div>
          <label>
            Email:
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </label>
        </div>
        <button type="submit" disabled={loading}>
          {loading ? "Submitting..." : "Submit"}
        </button>
      </form>

      {error && <div style={{ color: "red" }}>Error: {error}</div>}
      {success && <div style={{ color: "green" }}>Success!</div>}
    </div>
  );
}

/**
 * 例2: 従来の方法との比較
 */
export function FormWithTryFinally() {
  const [name, setName] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  /**
   * 従来の try...finally を使ったハンドラ（アンチパターン）
   *
   * - Nullチェックが必須
   * - 冗長なコード
   * - クリーンアップの書き忘れリスク
   */
  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(null);

    let api: ApiClient | null = null;

    try {
      api = await ApiClient.connect("/api/users");
      await api.post({ name });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      // Nullチェックが必須
      if (api) {
        await api[Symbol.asyncDispose]();
      }
      setLoading(false);
    }
  }

  return (
    <div>
      <h2>Form with try...finally (Anti-pattern)</h2>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <button type="submit" disabled={loading}>
          {loading ? "Submitting..." : "Submit"}
        </button>
      </form>
      {error && <div style={{ color: "red" }}>Error: {error}</div>}
    </div>
  );
}

/**
 * 例3: ボタンクリックハンドラでの await using
 *
 * ボタンクリック時の処理で、複数のリソースを管理します
 */
export function ButtonWithMultipleResources() {
  const [status, setStatus] = useState<string>("Ready");

  async function handleClick() {
    setStatus("Processing...");

    try {
      // AsyncDisposableStack で複数のリソースを管理
      await using stack = new AsyncDisposableStack();

      // API接続を追加
      const api = await ApiClient.connect("/api/process");
      stack.use(api);

      // 別のリソースを追加（例: ログコレクター）
      const logger = {
        log(msg: string) {
          console.log(`[Logger] ${msg}`);
        },
        async [Symbol.asyncDispose]() {
          console.log("[Logger] Flushing logs...");
          await new Promise((resolve) => setTimeout(resolve, 50));
        },
      };
      stack.use(logger);

      // 処理を実行
      logger.log("Starting process...");
      await api.post({ action: "process" });
      logger.log("Process completed");

      setStatus("Success!");

      // スコープ終了時、logger と api が LIFO順で破棄される
    } catch (err) {
      setStatus(`Error: ${err instanceof Error ? err.message : "Unknown"}`);
    }
  }

  return (
    <div>
      <h2>Button with Multiple Resources</h2>
      <button onClick={handleClick}>Process</button>
      <div>Status: {status}</div>
    </div>
  );
}
