# ssa packageを用いたSpannerにおける現在時刻誤用の静的検出

- Spanner
  - GCPが提供する分散DB
  - allow_commit_timestampオプション
  - commit timestampの順序からトランザクションの順序を復元可能
- SSA（静的単一代入）
  - プログラムの中間表現の一つで、各変数への代入が一つになる可能性
- 特定の値が特定の変数/引数に伝わっているかをチェック可能
