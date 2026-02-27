# Naming Things — エッセンス

## 関連URL

- Naming Things
  - 公式サイト: <https://www.namingthings.co/>
  - Leanpub: <https://leanpub.com/naming-things>

---

## なぜ命名が重要か

コードベースはナレッジベースである。識別子（クラス・変数・関数）はコードベース全体の **約70%** を占める。

- ソフトウェアライフサイクルコストの **60〜80%** が保守作業
- 保守時間の **40〜60%** がコードの「理解」に費やされる
- つまりライフサイクルの **25〜50%** が理解コスト

良い命名は **理解速度** と **想起精度** を高め、保守コストを直接削減する。バグ解決時間も短縮され（複数単語識別子は単語識別子より14%速い）、チームの生産性と幸福度にも影響する。

---

## なぜ命名は難しいか

1. **動的・主観的な要件** — 概念もオーディエンスも時間とともに変わる。2人が同じ対象に同じ名前をつける確率は7〜18%しかない
2. **業界標準の欠如** — 統一されたベストプラクティスがなく、自動化ツールも少ない
3. **短期コスト vs 長期価値** — 名前を考える「コスト」は今すぐ発生するが、「価値」は将来にしか現れない

---

## 4つの基本原則

| 原則 | 定義 |
| ------ | ------ |
| **Understandability（理解しやすさ）** | 名前はそれが表す概念を説明するものでなければならない |
| **Conciseness（簡潔さ）** | 概念を伝えるために必要な単語のみで構成する |
| **Consistency（一貫性）** | 名前は統一的に使用され、書式も統一する |
| **Distinguishability（区別しやすさ）** | 他の名前と視覚的・音声的に区別できなければならない |

### 原則の優先順位（トレードオフ時）

```text
Consistency > Distinguishability > Understandability > Conciseness
```

**一貫性が最優先**。一貫性の欠如は他3原則すべてに同時に違反しうる。一貫性が保たれていれば、他原則の問題はリネームで修正できる。

---

## Understandability（理解しやすさ）のルール

### 概念を正確に説明する

```python
# Bad: foo, thing, scooter
# Good: bicycle
```

### 辞書の一般用語を使う

```python
# Bad: o, org
# Good: organization
```

### 問題ドメインの用語を優先する

解決ドメイン（技術実装）より問題ドメイン（ビジネス要件）の用語を使う。

```python
# Bad: schedule_events(events)
# Good: schedule_meetings(meetings)
```

### ドメイン非依存な概念には標準用語を使う

DBなら `delete/row`、Unixプロセスなら `kill/pid` など業界標準に合わせる。

### 単数・複数を正確に使う

```python
# Bad: users = User.where(id=user_id)[0]
# Good: user = User.where(id=user_id)[0]
```

### 品詞を正確に使う

| 識別子の種類 | 品詞 | 例 |
| --- | --- | --- |
| クラス | 名詞・名詞句 | `User`, `PaymentMethod` |
| 変数 | 名詞・名詞句、または連結動詞＋補語 | `name`, `birth_date`, `is_valid` |
| メソッド | 動詞・動詞句、または連結動詞＋補語 | `validate`, `delete_all`, `is_valid` |
| インターフェース | 名詞・名詞句・形容詞 | `Parser`, `Runnable` |

```python
# Bad: user.validation()
# Good: user.validate()

# Boolean returns
# Bad: user.validate()
# Good: user.is_valid()  # or user.valid?
```

### 測定値には単位を含める

```python
# Bad: elapsed_duration, remaining_distance, temperature
# Good: elapsed_duration_in_days, remaining_distance_in_meters, temperature_in_celsius
```

### 慣例外の1文字名を避ける

`i`/`j`（ループインデックス）などの慣例は除く。`l`は`1`に、`o`は`0`に見間違えやすい。

```python
# Bad: u = users[0]
# Good: user = users[0]
```

### 略語を避ける

`URL`・`DNS`・`ID` などの広く知られた略語は除く。

```python
# Bad: ap, org
# Good: accounts_payable, organization
```

### 巧みさ・ユーモアを避ける

```python
# Bad: apply_kevlar(text)   # Metallicaアルバム名の引用
# Good: remove_bullets(text)
```

### 一時的・無関係な概念を避ける

```python
# Bad: kill_em_all(processes)
# Good: kill_processes(processes)
```

---

## Conciseness（簡潔さ）のルール

### 適切な抽象度を使う（Ladder of Abstraction）

「どう実装するか」ではなく「何に使われるか（意図）」を示す名前を選ぶ。

```python
class PhoneNumberPresenter:
  # Bad: process, trim_whitespace, strip
  # Good: format  ← 実装ではなく意図を表す
  def format(phone_number): ...
```

### 意味豊かな単語を使う

```python
# Bad: SongCollection → Good: Album
# Bad: ChildTask      → Good: Subtask
# Bad: get_user(id)   → Good: fetch_user(id)  # 外部APIを呼ぶ場合
```

`get` を多用しない。`find`, `fetch`, `generate`, `calculate`, `load` などより具体的な動詞を一貫して使い分ける。

### メタデータを省く（型情報を名前に入れない）

```python
# Bad: first_name_string, person_list
# Good: first_name, people
```

例外: 動的型付け言語で型が重要な文脈、または同スコープに類似した異なる型が混在する場合。

### 実装詳細を省く

```python
# Bad: csv_processor.process_in_parallel(rows)
# Good: csv_processor.process(rows)
# 直列/並列を制御したい場合: csv_processor.process(rows, in_parallel=True)
```

### 不要な単語を省く

```python
# Bad: user.delete_now()      → Good: user.delete()
# Bad: User.delete_user(user) → Good: User.delete(user)  # クラス名が文脈を提供

# Boolean は肯定形で
# Bad: if !user.is_invalid(): ...
# Good: if user.is_valid(): ...
```

---

## Consistency（一貫性）のルール

**3つのサブ原則:**

- 各概念には名前を1つだけ
- 類似した概念には類似した名前
- 類似した名前には同じフォーマット

### 言語・フレームワークの命名規則に従う

別言語の慣習を持ち込まない（例: PythonコードにJavaのgetter/setterパターンを適用しない）。

### 同義語を避ける

同じ概念に `user` と `end-user` を混在させない。コンテキストが変わっても同じ名前を使う。

```python
# Bad
onboarding_workflow.start()
offboarding_workflow.initiate()

# Good
onboarding_workflow.start()
offboarding_workflow.start()
```

### 類似した概念には類似した名前を使う

同種のリーダークラスが `UserReader`, `PostReader`, `CommentFetcher` では一貫性がない。

---

## Distinguishability（区別しやすさ）のルール

### 多義語（polyseme）を避ける

`book`（本？予約？）、`email`（メール本文？アドレス？）など複数の意味を持つ語は使わない。

```python
# Bad: email  (メッセージかアドレスか不明)
# Good: email_address
```

---

## 識別子の種類別ガイドライン

### クラス

- 名詞または名詞句（動詞は使わない）
- `ValidateUser` → `UserValidator`（インスタンスはアクションではなくオブジェクト）
- キャメルケースの頭字語は統一（`XmlParser` か `XMLParser` か、混在禁止）

### 変数

- 型名と同じ名前が基本。意味のある区別がある場合のみ変える（例: `User` の投稿者は `author`）
- Boolean: `is_`/`has_` プレフィックス or `?` サフィックス。名詞は禁止（`status` → `is_complete`）
- コレクション: 複数形。型サフィックス不要（`user_list` → `users`）
- ハッシュマップ: `user_id_to_user` のようにキー→値の順で表現

### メソッド

- 動詞または動詞句
- 名前は「何をするか」を表し「どうするか（実装）」は含めない
- 副作用があれば名前に明示（`find_user` がユーザーを更新してはならない）

### 引数

- 変数に準じるが、渡すべきデータを明確に示す
- `copy_permissions(x, y)` ではなく `copy_permissions(source_user, target_user)`

### インターフェース

- `Interface` サフィックス不要（`ComparisonInterface` → `Comparable`）
- `-able` サフィックスか `Can` プレフィックスを一貫して使う

### 定数

- 言語の慣習に従う（多くは `ALL_CAPS_WITH_UNDERSCORES`）
- 例: `MAX_FILE_SIZE_IN_BYTES`

---

## リネーミングの判断基準（技術的負債として考える）

悪い名前は技術的負債。**元本**（リネームコスト）と**利子**（悪い名前を放置し続けるコスト）で判断する。

```text
利子コスト（継続）: 理解の遅延、想起困難、コミュニケーション負荷、バグ、士気低下
元本コスト（一時）: 名前選定、ステークホルダー調整、リネーム作業、切り替えコスト
```

**今日のリネームコスト < 将来の累積利子** なら、リネームは投資に値する。

### リネームのスコープ

- **完全リネーム推奨**: 一貫性の利点を最大化できる
- **部分リネームのリスク**: 同じエンジニアが両方のコードに触れる場合、混乱を招く
- **大規模システム**: 旧コードを複製→新コードでリネーム→段階的移行→旧コード削除

### プロセス

1. スコープの決定（全体 or 特定コンポーネント）
2. ステークホルダーの特定
3. 新名前の提案（この文書の原則で評価）
4. 利子・元本コストの比較
5. 小規模: 議論→合意。大規模: 文書化→承認

---

## コントロールドボキャブラリー（統制語彙）

チーム・組織内での命名一貫性を保つために用語集を作る。

- **小規模**: README にグロッサリーを追加
- **中規模**: Wiki または専用ドキュメント
- **DDD との連携**: Domain-Driven Design の「ユビキタス言語（Ubiquitous Language）」が統制語彙にあたる

---

## ドメイン固有名の見つけ方

1. **ウェブ検索**: 業界の企業・製品サイトで使われている名前を調査
2. **APIドキュメント**: 技術的かつ構造化されていて素早く調査できる
3. **ドメイン専門家に相談**: プロダクト・マーケ・コンテンツ担当、長期在籍メンバー
4. **チームメンバーに聞く**: 自分には明快でも他者には不可解な場合がある

---

## 実践ステップ

1. 新しい名前を付けるたびに、この文書の4原則で評価する
2. コードレビューで他者の名前に思慮深いフィードバックを与える
3. 現在のコードベースにある問題のある名前を特定し、チームと議論する
4. 最も利子コストが高い名前のリネームを計画する
