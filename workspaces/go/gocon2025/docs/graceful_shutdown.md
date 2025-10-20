# Goで実現するgraceful shutdown: 実運用での課題と解決策

## URLs

## メモ

- 非同期タスクがデプロイに巻き込まれて異常終了する事例
- 解決策
  - メール送信専用ワーカーを別で起動する
  - Graceful Workerで安全に送信
