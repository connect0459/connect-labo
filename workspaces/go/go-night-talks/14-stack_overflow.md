# 公募LT登壇枠② Go言語はstack overflowの夢を見るか？

- スタックが伸び縮みしたらStack Overflowは起こらない？→起こります
  - goroutineごとの最大サイズが決められている
  - runtime/proc.go
- 最大容量は変更できる
  - runtime/debug.SetMaxStack()で決められる
