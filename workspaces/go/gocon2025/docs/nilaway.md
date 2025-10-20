# panicと向き合うGo開発 - nilawayで探る見逃されるnil参照とその対策

## URLs

- [panicと向き合うGo開発 - nilawayで探る見逃されるnil参照とその対策 | Go Conference 2025](https://gocon.jp/2025/talks/959021/)

## メモ

- 完全なnil参照のチェッカーは存在しない
  - 既存のチェッカーは偽陽性を含む
- `uber-go/nilaway`
  - 条件分岐やスコープを超えたロジックを追跡して報告してくれる
