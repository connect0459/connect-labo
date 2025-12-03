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

## TypeScript での実装例

### 値オブジェクト

```typescript
// Email 値オブジェクト
class Email {
  private constructor(private readonly value: string) {}

  static create(value: string): Email {
    if (!value) {
      throw new Error('Email cannot be empty')
    }

    const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
    if (!emailRegex.test(value)) {
      throw new Error('Invalid email format')
    }

    return new Email(value)
  }

  toString(): string {
    return this.value
  }

  equals(other: Email): boolean {
    return this.value === other.value
  }
}
```

### エンティティ

```typescript
// User エンティティ
class User {
  private constructor(
    private readonly id: string,
    private readonly email: Email,
    private readonly password: Password,
    private readonly createdAt: Date
  ) {}

  static create(id: string, email: Email, password: Password): User {
    return new User(id, email, password, new Date())
  }

  getId(): string {
    return this.id
  }

  getEmail(): Email {
    return this.email
  }

  changeEmail(newEmail: Email): User {
    return new User(this.id, newEmail, this.password, this.createdAt)
  }

  authenticate(password: string): boolean {
    return this.password.verify(password)
  }
}
```

## ポイント

1. **不変性**: 値オブジェクトは不変（Immutable）にする
2. **バリデーション**: コンストラクタで必ずバリデーションを行う
3. **ビジネスロジック**: ドメインオブジェクトにビジネスロジックを実装
4. **命名**: getter/setterではなく、振る舞いとして命名（`getName()` → `name()`）
5. **等価性**: 値オブジェクトは値による等価性を実装
