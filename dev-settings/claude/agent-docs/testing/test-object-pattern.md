# Test Object Pattern

## 概要

Test Object Patternは、テストに必要なデータと設定を構造体で管理するパターンです。
テストコードの可読性と保守性を向上させ、Living Documentationとして機能させます。

## 基本構造（Go）

```go
package domain_test

import (
    "testing"
    "myapp/internal/domain"
    "myapp/internal/infrastructure/memory"
)

// Test Object Pattern - テストに必要なデータと設定を構造体で管理
type UserServiceTest struct {
    userService domain.UserService
    userRepo    domain.UserRepository // 実際のインメモリ実装を使用
}

func TestUserService(t *testing.T) {
    setup := func(t *testing.T) *UserServiceTest {
        t.Helper()
        userRepo := memory.NewUserRepository() // 実際のインメモリ実装
        return &UserServiceTest{
            userService: domain.NewUserService(userRepo),
            userRepo:    userRepo,
        }
    }

    test := setup(t)

    t.Run("ユーザー作成機能", func(t *testing.T) {
        t.Run("有効な名前でユーザーを作成できる", func(t *testing.T) {
            // 準備
            name := "太郎"

            // 実行
            user, err := test.userService.CreateUser(name)

            // 検証
            if err != nil {
                t.Errorf("エラーが発生しました: %v", err)
            }
            if user.Name() != name {
                t.Errorf("名前が期待値と異なります: got %q, want %q", user.Name(), name)
            }
        })

        t.Run("空の名前の場合はエラーが返る", func(t *testing.T) {
            // 実行
            _, err := test.userService.CreateUser("")

            // 検証
            if err == nil {
                t.Error("エラーが期待されましたが、発生しませんでした")
            }
        })
    })

    t.Run("ユーザー検索機能", func(t *testing.T) {
        t.Run("存在するIDでユーザーを検索できる", func(t *testing.T) {
            // 準備: テストデータの投入
            user, _ := test.userService.CreateUser("次郎")

            // 実行
            found, err := test.userService.FindByID(user.ID())

            // 検証
            if err != nil {
                t.Errorf("エラーが発生しました: %v", err)
            }
            if found.Name() != "次郎" {
                t.Errorf("名前が一致しません")
            }
        })
    })
}
```

## 階層的構造

### Go: `t.Run()` を使った階層化

```go
t.Run("機能名", func(t *testing.T) {
    t.Run("正常系", func(t *testing.T) {
        t.Run("条件Aの場合", func(t *testing.T) {
            // テストコード
        })
    })

    t.Run("異常系", func(t *testing.T) {
        t.Run("条件Bの場合", func(t *testing.T) {
            // テストコード
        })
    })
})
```

### TypeScript: `describe()` と `test()` を使った階層化

```typescript
describe('UserService', () => {
  const setup = () => {
    const userRepo = new InMemoryUserRepository()
    const userService = new UserService(userRepo)
    return { userService, userRepo }
  }

  describe('ユーザー作成機能', () => {
    test('有効な名前でユーザーを作成できる', () => {
      const { userService } = setup()

      const user = userService.createUser('太郎')

      expect(user.name).toBe('太郎')
    })

    test('空の名前の場合はエラーが返る', () => {
      const { userService } = setup()

      expect(() => {
        userService.createUser('')
      }).toThrow()
    })
  })
})
```

### Rust: `mod` と `#[test]` を使った階層化

```rust
#[cfg(test)]
mod user_service_tests {
    use super::*;

    fn setup() -> UserService {
        let user_repo = InMemoryUserRepository::new();
        UserService::new(user_repo)
    }

    mod ユーザー作成機能 {
        use super::*;

        #[test]
        fn 有効な名前でユーザーを作成できる() {
            let service = setup();

            let user = service.create_user("太郎").unwrap();

            assert_eq!(user.name(), "太郎");
        }

        #[test]
        fn 空の名前の場合はエラーが返る() {
            let service = setup();

            let result = service.create_user("");

            assert!(result.is_err());
        }
    }
}
```

### PHP (PHPUnit): フラット構造 + データプロバイダ

PHPUnitの場合は、フレームワークの慣習に従い、フラットな`test*`メソッド構造を採用します。

```php
<?php

class UserServiceTest extends TestCase
{
    private UserService $userService;
    private UserRepository $userRepo;

    protected function setUp(): void
    {
        $this->userRepo = new InMemoryUserRepository();
        $this->userService = new UserService($this->userRepo);
    }

    public function test有効な名前でユーザーを作成できる(): void
    {
        $user = $this->userService->createUser('太郎');

        $this->assertSame('太郎', $user->name());
    }

    /**
     * @dataProvider 無効な名前のデータプロバイダ
     */
    public function test無効な名前の場合はエラーが返る(string $invalidName): void
    {
        $this->expectException(InvalidArgumentException::class);

        $this->userService->createUser($invalidName);
    }

    public function 無効な名前のデータプロバイダ(): array
    {
        return [
            '空文字' => [''],
            'スペースのみ' => ['   '],
            'null' => [null],
        ];
    }
}
```

## Living Documentation

### テスト名は日本語で仕様を表現

- **Good**: `"注文金額が10000円以上の場合、送料が無料になる"`
- **Bad**: `"testCalculateShippingFee"`

### テスト構造が仕様書になる

```text
UserService
  ├─ ユーザー作成機能
  │   ├─ 有効な名前でユーザーを作成できる
  │   └─ 空の名前の場合はエラーが返る
  └─ ユーザー検索機能
      ├─ 存在するIDでユーザーを検索できる
      └─ 存在しないIDの場合はエラーが返る
```

この構造がそのままドキュメントとして機能します。

## AAA パターン

各テストは以下の3段階で構成します：

1. **Arrange（準備）**: テストデータの準備
2. **Act（実行）**: テスト対象の実行
3. **Assert（検証）**: 結果の検証

```go
t.Run("有効な名前でユーザーを作成できる", func(t *testing.T) {
    // Arrange（準備）
    name := "太郎"

    // Act（実行）
    user, err := test.userService.CreateUser(name)

    // Assert（検証）
    if err != nil {
        t.Errorf("エラーが発生しました: %v", err)
    }
    if user.Name() != name {
        t.Errorf("名前が期待値と異なります: got %q, want %q", user.Name(), name)
    }
})
```

## フレームワーク別の適用

### 原則

Test Object Pattern + 階層的構造を推奨します。

### 例外

フレームワーク・テストツールの標準スタイルがある場合はそれに従います：

- **PHPUnit**: フラット構造 + データプロバイダ
- **RSpec**: `describe` / `context` / `it` の階層化
- **Jest/Vitest**: `describe` / `test` の階層化
