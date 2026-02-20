# ドメインオブジェクト実装例

## Rich Domain Objects vs Anemic Domain Model

### 基本方針

- **Rich Domain Objects**: データ構造とドメインロジックを一緒に実装
- **Anemic Domain Modelを避ける**: getter/setterだけのオブジェクトは避ける
- **振る舞い中心**: オブジェクトの「振る舞い」として実装

## Getter/Setter パターンの排除

### 悪い例（Anemic Domain Model）

```go
// Bad: getter/setterパターン（Javaスタイル）
type Person struct {
    name string
    age  int
}

func (p *Person) GetName() string {
    return p.name
}

func (p *Person) SetName(name string) {
    p.name = name
}

func (p *Person) GetAge() int {
    return p.age
}

func (p *Person) SetAge(age int) {
    p.age = age
}
```

### 良い例（Rich Domain Objects）

```go
// Good: 振る舞いとして実装
type Person struct {
    name string
    age  int
}

// getter/setterではなく、オブジェクトの振る舞いとして実装
func (p Person) name() string {
    return p.name
}

func (p Person) age() int {
    return p.age
}

// ビジネスロジックを含む振る舞い
func (p Person) isAdult() bool {
    return p.age >= 18
}

func (p Person) greet() string {
    return fmt.Sprintf("こんにちは、%sです", p.name)
}
```

## 値オブジェクト（Value Object）

### Email 値オブジェクト

```go
package domain

import (
    "errors"
    "regexp"
)

// Email はメールアドレスを表す値オブジェクト
// 不変性とバリデーションを保証する
type Email struct {
    value string
}

var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)

// NewEmail はメールアドレスを生成する
// バリデーションに失敗した場合はエラーを返す
func NewEmail(value string) (Email, error) {
    if value == "" {
        return Email{}, errors.New("email cannot be empty")
    }

    if !emailRegex.MatchString(value) {
        return Email{}, errors.New("invalid email format")
    }

    return Email{value: value}, nil
}

// String はメールアドレスの文字列表現を返す
func (e Email) String() string {
    return e.value
}

// Equals は2つのメールアドレスが等しいかを判定する
func (e Email) Equals(other Email) bool {
    return e.value == other.value
}
```

### Money 値オブジェクト

```go
package domain

import (
    "errors"
    "math/big"
)

// Money は金額を表す値オブジェクト
// BigDecimalで精度を保証する
type Money struct {
    amount   *big.Float
    currency string
}

// NewMoney は金額を生成する
func NewMoney(amount float64, currency string) (Money, error) {
    if amount < 0 {
        return Money{}, errors.New("amount cannot be negative")
    }

    if currency == "" {
        return Money{}, errors.New("currency cannot be empty")
    }

    return Money{
        amount:   big.NewFloat(amount),
        currency: currency,
    }, nil
}

// Add は金額を加算する
func (m Money) Add(other Money) (Money, error) {
    if m.currency != other.currency {
        return Money{}, errors.New("currency mismatch")
    }

    result := new(big.Float).Add(m.amount, other.amount)
    amount, _ := result.Float64()

    return NewMoney(amount, m.currency)
}

// Multiply は金額を乗算する
func (m Money) Multiply(multiplier float64) Money {
    result := new(big.Float).Mul(m.amount, big.NewFloat(multiplier))
    amount, _ := result.Float64()

    money, _ := NewMoney(amount, m.currency)
    return money
}

// IsGreaterThan は金額を比較する
func (m Money) IsGreaterThan(other Money) bool {
    return m.amount.Cmp(other.amount) > 0
}
```

## エンティティ（Entity）

### User エンティティ

```go
package domain

import (
    "errors"
    "time"
)

// User はシステムの利用者を表すドメインオブジェクト
// ユーザーの生成時には必ず有効な認証情報が必要であり、
// これはセキュリティポリシーで定められた不変のビジネスルール
type User struct {
    id        string
    email     Email
    password  Password
    createdAt time.Time
}

// NewUser はユーザーを生成する
func NewUser(id string, email Email, password Password) User {
    return User{
        id:        id,
        email:     email,
        password:  password,
        createdAt: time.Now(),
    }
}

// ID はユーザーIDを返す
func (u User) ID() string {
    return u.id
}

// Email はメールアドレスを返す
func (u User) Email() Email {
    return u.email
}

// ChangeEmail はメールアドレスを変更する
// ビジネスルール: メールアドレスの変更には再認証が必要（省略）
func (u User) ChangeEmail(newEmail Email) User {
    return User{
        id:        u.id,
        email:     newEmail,
        password:  u.password,
        createdAt: u.createdAt,
    }
}

// Authenticate は認証を行う
func (u User) Authenticate(password string) bool {
    return u.password.Verify(password)
}
```

### Order エンティティ

```go
package domain

import (
    "errors"
    "time"
)

// OrderStatus は注文ステータスを表す
type OrderStatus string

const (
    OrderStatusPending   OrderStatus = "pending"
    OrderStatusConfirmed OrderStatus = "confirmed"
    OrderStatusShipped   OrderStatus = "shipped"
    OrderStatusDelivered OrderStatus = "delivered"
    OrderStatusCancelled OrderStatus = "cancelled"
)

// Order は注文を表すエンティティ
type Order struct {
    id        string
    userID    string
    items     []OrderItem
    status    OrderStatus
    createdAt time.Time
}

// OrderItem は注文アイテムを表す値オブジェクト
type OrderItem struct {
    productID string
    quantity  int
    price     Money
}

// NewOrder は新しい注文を生成する
func NewOrder(id, userID string, items []OrderItem) (Order, error) {
    if len(items) == 0 {
        return Order{}, errors.New("order must have at least one item")
    }

    return Order{
        id:        id,
        userID:    userID,
        items:     items,
        status:    OrderStatusPending,
        createdAt: time.Now(),
    }, nil
}

// TotalAmount は注文の合計金額を計算する
// ビジネスルール: 10000円以上の場合は送料無料
func (o Order) TotalAmount() Money {
    var total Money
    for _, item := range o.items {
        itemTotal := item.price.Multiply(float64(item.quantity))
        total, _ = total.Add(itemTotal)
    }

    // 送料計算
    if !o.isFreeShipping() {
        shippingFee, _ := NewMoney(500, "JPY")
        total, _ = total.Add(shippingFee)
    }

    return total
}

// isFreeShipping は送料無料かどうかを判定する
func (o Order) isFreeShipping() bool {
    subtotal := o.subtotal()
    threshold, _ := NewMoney(10000, "JPY")
    return subtotal.IsGreaterThan(threshold)
}

// subtotal は商品小計を計算する
func (o Order) subtotal() Money {
    var total Money
    for _, item := range o.items {
        itemTotal := item.price.Multiply(float64(item.quantity))
        total, _ = total.Add(itemTotal)
    }
    return total
}

// Confirm は注文を確定する
func (o Order) Confirm() (Order, error) {
    if o.status != OrderStatusPending {
        return o, errors.New("only pending orders can be confirmed")
    }

    return Order{
        id:        o.id,
        userID:    o.userID,
        items:     o.items,
        status:    OrderStatusConfirmed,
        createdAt: o.createdAt,
    }, nil
}

// Cancel は注文をキャンセルする
func (o Order) Cancel() (Order, error) {
    if o.status == OrderStatusShipped || o.status == OrderStatusDelivered {
        return o, errors.New("cannot cancel shipped or delivered orders")
    }

    return Order{
        id:        o.id,
        userID:    o.userID,
        items:     o.items,
        status:    OrderStatusCancelled,
        createdAt: o.createdAt,
    }, nil
}
```

## ポイント

1. **不変性**: 値オブジェクトは不変（Immutable）にする
2. **バリデーション**: コンストラクタで必ずバリデーションを行う
3. **ビジネスロジック**: ドメインオブジェクトにビジネスロジックを実装
4. **命名**: getter/setterではなく、振る舞いとして命名（`getName()` → `name()`）
5. **等価性**: 値オブジェクトは値による等価性を実装

---

## Order モデルの批判的検討 — 脱構築とスキーマ理論の適用例

本セクションでは、上記の Order エンティティに `agent-docs/philosophy/designing-domain-objects.md` のワークフローを適用し、モデルに埋め込まれた暗黙の前提を可視化する。

### Phase 1: 脱構築

#### 二項対立の抽出

```text
対立構造              特権項        排除されているもの
─────────────────────────────────────────────────────
OrderStatus           Confirmed     部分出荷、保留、係争中、返品
(5値enum)             (正常系)      (いずれも既存statusで表現不可)

isFreeShipping()      true/false    段階的送料、地域差、会員割引
(boolean判定)

Order ↔ OrderItem     Order         アイテム個別の履行状態
(所有関係)            (集約ルート)  (出荷・キャンセルがOrder単位に束縛)
```

#### 中心と周縁の転倒

現在のモデルではOrderが集約ルートであり、OrderItemはOrderの従属物（値オブジェクト）として扱われている。

転倒の思考実験 — OrderItemを中心に据えたらどうなるか:

- 各アイテムが独自の履行ライフサイクルを持つ → 部分出荷が自然に表現できる
- アイテム単位のキャンセルが可能になる → 「注文全体のキャンセル」は「全アイテムのキャンセル」として導出される
- Orderは「アイテム群の束ね」という役割に変わる → 集約の意味が変化する

#### 痕跡と排除の追跡

```text
エンティティ    痕跡（でないもの）           モデルでの存在
──────────────────────────────────────────────────────
Order          Cart（注文の前段階）          不在
Order          Return（配送後の逆フロー）    不在
OrderItem      Product（商品の現在状態）     productIDのみ（痕跡）
Cancel         Refund（取消の経済的帰結）    不在
Delivered      受領確認（配送の完了証明）    不在（暗黙の終端）
```

Orderは「カートから注文への変換」と「配送後の返品フロー」の痕跡を帯びているが、どちらもモデルに明示されていない。特にDeliveredが終端状態として扱われている点は、返品・交換という現実のビジネスフローを排除している。

### Phase 2: スキーマ理論

#### 支配的スキーマの同定

現在のモデルが採用しているメタファーは **「注文 = B2C購買行為」** である。

- 前提: 一人の買い手、一つの売り手、同期的な履行プロセス
- 根拠: 単一のuserID、線形なステータス遷移（pending → confirmed → shipped → delivered）、送料閾値のハードコード
- このスキーマを「当たり前」にしている立場: ECサイトの商品企画担当、個人消費者の購買体験

代替スキーマの候補:

| スキーマ | メタファー | 中心概念 | 自然に表現できるもの |
| :--- | :--- | :--- | :--- |
| 購買行為 | 「買い物」 | 注文 | 個人購買、カート、決済 |
| 履行プロセス | 「届けること」 | 出荷 | 部分出荷、配送追跡、返品 |
| 当事者間契約 | 「約束」 | 契約 | B2B取引、承認フロー、係争 |

#### 同化バイアスの検出

- `OrderStatus`の線形遷移は「購買行為」スキーマへの同化の産物。部分出荷や返品が必要になったとき、statusに値を追加し続ける圧力が生じる（同化バイアス）
- `isFreeShipping()`の10000円ハードコードは、送料ポリシーが単純な閾値であるという前提の同化。段階的送料や地域差が必要になったとき、条件分岐が膨張する
- OrderItemが値オブジェクトである点は、「アイテムは注文の一部」という購買スキーマへの同化。アイテム個別の追跡が必要になると、この設計は破綻する

#### 調節によるモデル再構成

「履行プロセス」スキーマへの調節を適用した場合のモデル案:

```go
// 調節後: OrderItemが独自のライフサイクルを持つ
type FulfillmentStatus string

const (
    FulfillmentPending   FulfillmentStatus = "pending"
    FulfillmentAllocated FulfillmentStatus = "allocated"
    FulfillmentShipped   FulfillmentStatus = "shipped"
    FulfillmentDelivered FulfillmentStatus = "delivered"
    FulfillmentReturned  FulfillmentStatus = "returned"
)

type OrderItem struct {
    id          string
    productID   string
    quantity    int
    price       Money
    fulfillment FulfillmentStatus
}

// OrderItemが振る舞いを持つ — Rich Domain Objectの原則は維持
func (i OrderItem) Ship() (OrderItem, error) {
    if i.fulfillment != FulfillmentAllocated {
        return i, errors.New("only allocated items can be shipped")
    }
    return OrderItem{
        id: i.id, productID: i.productID,
        quantity: i.quantity, price: i.price,
        fulfillment: FulfillmentShipped,
    }, nil
}

// Orderの全体ステータスはアイテムの履行状態から導出される
func (o Order) Status() string {
    allDelivered := true
    anyShipped := false
    for _, item := range o.items {
        if item.fulfillment == FulfillmentShipped {
            anyShipped = true
        }
        if item.fulfillment != FulfillmentDelivered {
            allDelivered = false
        }
    }
    switch {
    case allDelivered:
        return "delivered"
    case anyShipped:
        return "partially_shipped"
    default:
        return "processing"
    }
}
```

この調節により:

- 部分出荷が構造として自然に表現される（enum追加ではなく、アイテム単位のライフサイクル）
- Orderのステータスは導出値になり、「状態の組み合わせ爆発」を回避できる
- 返品フローもアイテム単位で表現可能（`FulfillmentReturned`）
- 集約ルートはOrderのままだが、OrderItemはエンティティに昇格（独自IDを持つ）
