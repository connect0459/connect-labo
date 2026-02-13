# リポジトリパターン実装例

## 基本方針

- **抽象型を先に定義**: ドメイン層でinterfaceを定義
- **実装はインフラ層**: 具体的な実装はinfrastructure層に配置
- **戻り値は抽象型**: コンストラクタは抽象型（interface）を返す
- **依存性逆転**: インフラ層がドメイン層に依存

## レイヤー間の依存関係

```text
domain/repositories/user_repository.go (抽象型定義)
         ↑
         | 依存
         |
infrastructure/persistence/user_repository.go (実装)
```

## Go での実装例

### 1. ドメイン層: 抽象型定義

```go
// internal/domain/repositories/user_repository.go
package repositories

import "myapp/internal/domain/entities"

// UserRepository はユーザーの永続化を抽象化する
type UserRepository interface {
    FindByID(id string) (*entities.User, error)
    FindByEmail(email string) (*entities.User, error)
    Save(user *entities.User) error
    Delete(id string) error
}
```

### 2. インフラ層: GORM実装

```go
// internal/infrastructure/persistence/user_repository.go
package persistence

import (
    "myapp/internal/domain/entities"
    "myapp/internal/domain/repositories"
    "gorm.io/gorm"
)

// gormUserRepository はGORMを使用したUserRepositoryの実装
// 構造体は非公開（小文字始まり）
type gormUserRepository struct {
    db *gorm.DB
}

// NewGormUserRepository はGORM実装のUserRepositoryを生成する
// 戻り値は抽象型（repositories.UserRepository）
func NewGormUserRepository(db *gorm.DB) repositories.UserRepository {
    return &gormUserRepository{db: db}
}

func (r *gormUserRepository) FindByID(id string) (*entities.User, error) {
    var user entities.User
    if err := r.db.First(&user, "id = ?", id).Error; err != nil {
        return nil, err
    }
    return &user, nil
}

func (r *gormUserRepository) FindByEmail(email string) (*entities.User, error) {
    var user entities.User
    if err := r.db.First(&user, "email = ?", email).Error; err != nil {
        return nil, err
    }
    return &user, nil
}

func (r *gormUserRepository) Save(user *entities.User) error {
    return r.db.Save(user).Error
}

func (r *gormUserRepository) Delete(id string) error {
    return r.db.Delete(&entities.User{}, "id = ?", id).Error
}
```

### 3. インフラ層: インメモリ実装（テスト用）

```go
// internal/infrastructure/memory/user_repository.go
package memory

import (
    "errors"
    "myapp/internal/domain/entities"
    "myapp/internal/domain/repositories"
    "sync"
)

// memoryUserRepository はインメモリのUserRepository実装
type memoryUserRepository struct {
    users map[string]*entities.User
    mu    sync.RWMutex
}

// NewUserRepository はインメモリ実装のUserRepositoryを生成する
func NewUserRepository() repositories.UserRepository {
    return &memoryUserRepository{
        users: make(map[string]*entities.User),
    }
}

func (r *memoryUserRepository) FindByID(id string) (*entities.User, error) {
    r.mu.RLock()
    defer r.mu.RUnlock()

    user, exists := r.users[id]
    if !exists {
        return nil, errors.New("user not found")
    }
    return user, nil
}

func (r *memoryUserRepository) FindByEmail(email string) (*entities.User, error) {
    r.mu.RLock()
    defer r.mu.RUnlock()

    for _, user := range r.users {
        if user.Email().String() == email {
            return user, nil
        }
    }
    return nil, errors.New("user not found")
}

func (r *memoryUserRepository) Save(user *entities.User) error {
    r.mu.Lock()
    defer r.mu.Unlock()

    r.users[user.ID()] = user
    return nil
}

func (r *memoryUserRepository) Delete(id string) error {
    r.mu.Lock()
    defer r.mu.Unlock()

    delete(r.users, id)
    return nil
}
```

### 4. アプリケーション層: 使用例

```go
// internal/application/services/user_service.go
package services

import (
    "myapp/internal/domain/entities"
    "myapp/internal/domain/repositories"
)

// UserService はユーザー関連のユースケースを実装する
type UserService struct {
    userRepo repositories.UserRepository // 抽象型に依存
}

// NewUserService はUserServiceを生成する
func NewUserService(userRepo repositories.UserRepository) *UserService {
    return &UserService{
        userRepo: userRepo,
    }
}

func (s *UserService) CreateUser(email, password string) (*entities.User, error) {
    // ドメインロジック: ユーザー生成
    emailVO, err := entities.NewEmail(email)
    if err != nil {
        return nil, err
    }

    passwordVO, err := entities.NewPassword(password)
    if err != nil {
        return nil, err
    }

    user := entities.NewUser(generateID(), emailVO, passwordVO)

    // 永続化
    if err := s.userRepo.Save(&user); err != nil {
        return nil, err
    }

    return &user, nil
}

func (s *UserService) FindUserByEmail(email string) (*entities.User, error) {
    return s.userRepo.FindByEmail(email)
}
```

### 5. DIコンテナ: 依存性注入

```go
// internal/registry/registry.go
package registry

import (
    "myapp/internal/application/services"
    "myapp/internal/infrastructure/persistence"
    "gorm.io/gorm"
)

// Registry はDIコンテナ
type Registry struct {
    db *gorm.DB
}

func NewRegistry(db *gorm.DB) *Registry {
    return &Registry{db: db}
}

// UserService はUserServiceのインスタンスを返す
func (r *Registry) UserService() *services.UserService {
    userRepo := persistence.NewGormUserRepository(r.db) // 具体的な実装を注入
    return services.NewUserService(userRepo)
}
```

## TypeScript での実装例

### 1. ドメイン層: 抽象型定義（TypeScript）

```typescript
// domain/repositories/user-repository.ts
import { User } from '../entities/user'

export interface UserRepository {
  findById(id: string): Promise<User | null>
  findByEmail(email: string): Promise<User | null>
  save(user: User): Promise<void>
  delete(id: string): Promise<void>
}
```

### 2. インフラ層: Prisma実装

```typescript
// infrastructure/persistence/prisma-user-repository.ts
import { PrismaClient } from '@prisma/client'
import { UserRepository } from '../../domain/repositories/user-repository'
import { User } from '../../domain/entities/user'

export class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<User | null> {
    const userData = await this.prisma.user.findUnique({ where: { id } })
    if (!userData) return null
    return this.toDomain(userData)
  }

  async findByEmail(email: string): Promise<User | null> {
    const userData = await this.prisma.user.findUnique({ where: { email } })
    if (!userData) return null
    return this.toDomain(userData)
  }

  async save(user: User): Promise<void> {
    await this.prisma.user.upsert({
      where: { id: user.getId() },
      create: this.toPersistence(user),
      update: this.toPersistence(user),
    })
  }

  async delete(id: string): Promise<void> {
    await this.prisma.user.delete({ where: { id } })
  }

  private toDomain(data: any): User {
    // Prismaのデータからドメインオブジェクトへ変換
    return User.reconstruct(data.id, data.email, data.password, data.createdAt)
  }

  private toPersistence(user: User): any {
    // ドメインオブジェクトからPrismaのデータへ変換
    return {
      id: user.getId(),
      email: user.getEmail().toString(),
      password: user.getPassword().toString(),
      createdAt: user.getCreatedAt(),
    }
  }
}
```

### 3. インフラ層: インメモリ実装（TypeScript）（テスト用）

```typescript
// infrastructure/memory/memory-user-repository.ts
import { UserRepository } from '../../domain/repositories/user-repository'
import { User } from '../../domain/entities/user'

export class MemoryUserRepository implements UserRepository {
  private users: Map<string, User> = new Map()

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) || null
  }

  async findByEmail(email: string): Promise<User | null> {
    for (const user of this.users.values()) {
      if (user.getEmail().toString() === email) {
        return user
      }
    }
    return null
  }

  async save(user: User): Promise<void> {
    this.users.set(user.getId(), user)
  }

  async delete(id: string): Promise<void> {
    this.users.delete(id)
  }
}
```

## テストでの使用例

### デトロイト派: 実際のインメモリ実装を使用

```go
package services_test

import (
    "testing"
    "myapp/internal/application/services"
    "myapp/internal/infrastructure/memory"
)

func TestUserService_CreateUser(t *testing.T) {
    // 実際のインメモリリポジトリを使用（モックではない）
    userRepo := memory.NewUserRepository()
    userService := services.NewUserService(userRepo)

    t.Run("有効なメールアドレスでユーザーを作成できる", func(t *testing.T) {
        email := "test@example.com"
        password := "password123"

        user, err := userService.CreateUser(email, password)

        if err != nil {
            t.Errorf("エラーが発生しました: %v", err)
        }
        if user.Email().String() != email {
            t.Errorf("メールアドレスが一致しません")
        }

        // リポジトリから取得して確認
        found, err := userRepo.FindByEmail(email)
        if err != nil {
            t.Errorf("ユーザーが見つかりませんでした: %v", err)
        }
        if found.Email().String() != email {
            t.Errorf("保存されたメールアドレスが一致しません")
        }
    })
}
```

## アンチパターン

### ❌ 避けるべき実装

```go
// Bad: 具体的な型を返している
type GormUserRepository struct {
    db *gorm.DB
}

func NewGormUserRepository(db *gorm.DB) *GormUserRepository {
    return &GormUserRepository{db: db}
}
```

### ✅ 正しい実装

```go
// Good: 抽象型を返している
type gormUserRepository struct {
    db *gorm.DB
}

func NewGormUserRepository(db *gorm.DB) repositories.UserRepository {
    return &gormUserRepository{db: db}
}
```

## ポイント

1. **抽象型優先**: まずドメイン層でinterfaceを定義
2. **実装は非公開**: 実装の構造体は小文字始まり（非公開）
3. **戻り値は抽象型**: コンストラクタは必ず抽象型を返す
4. **テストはインメモリ**: モックではなく実際のインメモリ実装を使用
5. **依存性逆転**: インフラ層がドメイン層に依存する
