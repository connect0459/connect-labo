# modelcontextprotocol/go-sdk の現在地とこれから

## go-sdkの設計方針

### 5つの設計目標

complete
idiomatic
robust
future-proof
extensible

## 例

- interfaceを小さく区切ることにより抽象化
- シンプルなAPI体系と標準I/Oの活用
- mcp-goとの設計判断の違い
  - interfaceを複雑にせず、シンプルに実装
  - 低レベルインターフェース（lower-level interface）
- カスタムTransportの組み込みも実装しやすい
- ミドルウェア
  - GinやEchoと同じ設計思想
  - 関数型のミドルウェアパターン
    - 関数を受け取って関数を返す
    - `next()`でチェーンさせるなどの使用方法
