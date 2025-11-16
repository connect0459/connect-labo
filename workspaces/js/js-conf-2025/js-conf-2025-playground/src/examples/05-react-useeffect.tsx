import { useEffect, useState } from "react";

/**
 * React useEffect での DisposableStack の使用例
 *
 * DisposableStackを使うことで、useEffectのクリーンアップ処理を
 * 宣言的かつ安全に記述できます。
 */

/**
 * 例1: 従来の useEffect（アンチパターン）
 *
 * 複数のリソースを手動で管理する必要があり、
 * クリーンアップの書き忘れが発生しやすい
 */
export function TraditionalUseEffectComponent({ userId }: { userId: string }) {
  const [data, setData] = useState<unknown>(null);

  useEffect(() => {
    let isCurrent = true;
    const controller = new AbortController();

    // タイマーを設定
    const timerId = setTimeout(() => {
      console.log("Timer fired");
    }, 5000);

    // データフェッチ
    fetch(`/api/users/${userId}`, { signal: controller.signal })
      .then((res) => res.json())
      .then((json) => {
        if (isCurrent) {
          setData(json);
        }
      })
      .catch((err) => {
        if (err.name !== "AbortError") {
          console.error(err);
        }
      });

    // イベントリスナーを追加
    const handleResize = () => console.log("Resized");
    window.addEventListener("resize", handleResize);

    // クリーンアップ関数で、全てを手動で管理（書き忘れリスク）
    return () => {
      isCurrent = false;
      controller.abort();
      clearTimeout(timerId);
      window.removeEventListener("resize", handleResize);
    };
  }, [userId]);

  return <div>User Data: {JSON.stringify(data)}</div>;
}

/**
 * 例2: DisposableStack を使った useEffect（推奨）
 *
 * 全てのリソースを DisposableStack で一元管理し、
 * クリーンアップは1行で完結
 */
export function ModernUseEffectComponent({ userId }: { userId: string }) {
  const [data, setData] = useState<unknown>(null);

  useEffect(() => {
    // DisposableStackを作成
    const stack = new DisposableStack();

    // AbortController を管理
    const controller = new AbortController();
    stack.adopt(controller, (ctrl) => {
      console.log("Aborting fetch...");
      ctrl.abort();
    });

    // タイマーを管理
    const timerId = setTimeout(() => {
      console.log("Timer fired");
    }, 5000);
    stack.adopt(timerId, (id) => {
      console.log("Clearing timer...");
      clearTimeout(id);
    });

    // イベントリスナーを管理
    const handleResize = () => console.log("Resized");
    window.addEventListener("resize", handleResize);
    stack.adopt(handleResize, (listener) => {
      console.log("Removing event listener...");
      window.removeEventListener("resize", listener);
    });

    // isCurrent フラグも管理可能
    let isCurrent = true;
    stack.adopt(null, () => {
      console.log("Setting isCurrent to false...");
      isCurrent = false;
    });

    // データフェッチ
    fetch(`/api/users/${userId}`, { signal: controller.signal })
      .then((res) => res.json())
      .then((json) => {
        if (isCurrent) {
          setData(json);
        }
      })
      .catch((err) => {
        if (err.name !== "AbortError") {
          console.error(err);
        }
      });

    // クリーンアップは1行！
    // LIFO順（後入れ先出し）で全てのリソースが破棄される
    return () => stack.dispose();
  }, [userId]);

  return <div>User Data: {JSON.stringify(data)}</div>;
}

/**
 * 例3: WebSocket接続の管理
 *
 * WebSocket接続のような長期的なリソースも、
 * DisposableStackで簡潔に管理できます
 */
export function WebSocketComponent({ roomId }: { roomId: string }) {
  const [messages, setMessages] = useState<string[]>([]);
  const [status, setStatus] = useState<string>("Disconnected");

  useEffect(() => {
    const stack = new DisposableStack();

    // WebSocket接続を作成
    const ws = new WebSocket(`wss://example.com/rooms/${roomId}`);

    ws.onopen = () => {
      setStatus("Connected");
    };

    ws.onmessage = (event) => {
      setMessages((prev) => [...prev, event.data]);
    };

    ws.onerror = (error) => {
      console.error("WebSocket error:", error);
      setStatus("Error");
    };

    ws.onclose = () => {
      setStatus("Disconnected");
    };

    // WebSocketのクリーンアップを登録
    stack.adopt(ws, (socket) => {
      console.log("Closing WebSocket...");
      if (socket.readyState === WebSocket.OPEN) {
        socket.close();
      }
    });

    // ハートビートタイマーを設定
    const heartbeatId = setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: "ping" }));
      }
    }, 30000);

    stack.adopt(heartbeatId, (id) => {
      console.log("Clearing heartbeat timer...");
      clearInterval(id);
    });

    // クリーンアップは1行
    return () => stack.dispose();
  }, [roomId]);

  return (
    <div>
      <div>Status: {status}</div>
      <div>
        <h3>Messages:</h3>
        <ul>
          {messages.map((msg, i) => (
            <li key={i}>{msg}</li>
          ))}
        </ul>
      </div>
    </div>
  );
}

/**
 * 例4: 条件付きリソース管理
 *
 * 条件に応じてリソースを動的に追加するパターン
 */
export function ConditionalResourcesComponent({
  enableLogging,
  enableMetrics,
}: {
  enableLogging: boolean;
  enableMetrics: boolean;
}) {
  const [logs, setLogs] = useState<string[]>([]);

  useEffect(() => {
    const stack = new DisposableStack();

    // ロギングが有効な場合のみ、ログコレクターを追加
    if (enableLogging) {
      const logInterval = setInterval(() => {
        const log = `[${new Date().toISOString()}] Log entry`;
        setLogs((prev) => [...prev, log]);
      }, 2000);

      stack.adopt(logInterval, (id) => {
        console.log("Stopping log collector...");
        clearInterval(id);
      });
    }

    // メトリクスが有効な場合のみ、メトリクスコレクターを追加
    if (enableMetrics) {
      const metricsInterval = setInterval(() => {
        console.log("Collecting metrics...");
      }, 5000);

      stack.adopt(metricsInterval, (id) => {
        console.log("Stopping metrics collector...");
        clearInterval(id);
      });
    }

    // 有効化されたリソースのみがクリーンアップされる
    return () => stack.dispose();
  }, [enableLogging, enableMetrics]);

  return (
    <div>
      <div>Logging: {enableLogging ? "ON" : "OFF"}</div>
      <div>Metrics: {enableMetrics ? "ON" : "OFF"}</div>
      <div>
        <h3>Logs:</h3>
        <ul>
          {logs.map((log, i) => (
            <li key={i}>{log}</li>
          ))}
        </ul>
      </div>
    </div>
  );
}

/**
 * 例5: カスタムフックでのDisposableStack活用
 *
 * 再利用可能なカスタムフックでDisposableStackを使うパターン
 */
function useDataSubscription(dataId: string) {
  const [data, setData] = useState<unknown>(null);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const stack = new DisposableStack();

    // サブスクリプションオブジェクト
    const subscription = {
      active: true,
      onData: (newData: unknown) => {
        if (subscription.active) {
          setData(newData);
        }
      },
      onError: (err: Error) => {
        if (subscription.active) {
          setError(err);
        }
      },
    };

    // サブスクリプションのクリーンアップを登録
    stack.adopt(subscription, (sub) => {
      console.log("Deactivating subscription...");
      sub.active = false;
    });

    // 模擬的なデータフェッチ
    const fetchInterval = setInterval(() => {
      subscription.onData({ id: dataId, timestamp: Date.now() });
    }, 3000);

    stack.adopt(fetchInterval, (id) => {
      console.log("Stopping fetch interval...");
      clearInterval(id);
    });

    return () => stack.dispose();
  }, [dataId]);

  return { data, error };
}

export function CustomHookExample({ dataId }: { dataId: string }) {
  const { data, error } = useDataSubscription(dataId);

  return (
    <div>
      <h2>Custom Hook with DisposableStack</h2>
      {error ? <div>Error: {error.message}</div> : null}
      {data ? <div>Data: {JSON.stringify(data)}</div> : null}
    </div>
  );
}
