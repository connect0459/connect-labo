# deep dive into testing/synctest

## URLs

- [deep dive into testing/synctest - Speaker Deck](https://speakerdeck.com/daikieng/synctest)

## メモ

- 非同期テストの課題
  - 例1：1s待つテスト
  - 何回か実行すると失敗が発生する…
  - 対策：Sleepの時間を長くする、など
    - 安定さは増すがテストの実行時間は遅くなる
    - ClockをDIして時間を進めることもできるが複雑性とトレードオフ
  - 例2：定期的にpollingする
  - 例3：ゴルーチンの完了を待機する
    - 動画のNフレーム目の画像が生成されるか
    - 課題：ゴルーチンの完了タイミングがわからない
  - まとめ
    - 実際のシステムクロックとの同期の機構に依存しているため、制御が難しい
    - トレードオフの考慮
      - シンプルさ
      - 実行時間
      - 安定性（not Flaky）
- Go1.24からsynctestが登場
  - 例1だと35sかかっていたテストがほぼ0sに
- testing/synctestとは
  - Go1.24ではexperimental
  - Go1.25のAPIは`Test()`と`Wait()`を使用推奨
- Test
  - `bubble`とは
    - synctest内の隔離性を担保する概念
  - 仮想クロックによって開始時間と終了時間を制御
- Wait
- durably blocked（決定性）
  - bubble（隔離性）外のイベントやゴルーチンによって解除されない状態
