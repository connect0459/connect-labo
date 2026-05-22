# プラグインで拡張されるContextをtype-safeにする難しさと設計判断（kazupon）

<https://2026.tskaigi.org/talks/21>

- アプローチ
  - 1.Module Augumentation
    - Astro,Nitro
  - 2.Fluent Interface
    - Elysia
  - 3.Explicit Context Type
    - Hono, tRPC, Gunshi
- 採用理由
  - 宣言ベースのインターフェースでコマンドやプラグインを定義する
  - コマンドモジュールとプラグインが別々の場所に存在する
