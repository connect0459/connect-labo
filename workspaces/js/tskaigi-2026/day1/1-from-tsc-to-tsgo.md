# tscからtsgoへ ── DenoのTypeScript基盤はどう変わったか（maguro）

<https://2026.tskaigi.org/talks/2>

- JSR -> npmの進化版
- tscにパッチを当てたり、アダプタ層を設けてDeno Rustに通信可能にしたりする。
- tsc -> tsgoはDenoのオーバーヘッドもありフルの改善にはなっていない模様

- Phase 1: tsxにパッチを当ててV8 isolate内で実行
- Phase 2: fork tsgoは取り下げられた
- Phase 3: typescriptをそのまま使えるようにしたい
