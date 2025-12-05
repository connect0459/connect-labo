# Promise と async/await 完全ガイド

JavaScriptの非同期処理を理解するための包括的なガイドです。

## 目次

1. [同期 vs 非同期](#同期-vs-非同期)
2. [Promiseとは何か](#promiseとは何か)
3. [resolve と reject](#resolve-と-reject)
4. [async/await の使い方](#asyncawait-の使い方)
5. [並列実行パターン](#並列実行パターン)
6. [実践例](#実践例)

---

## 同期 vs 非同期

### 同期処理

**同期的**とは「コードが書かれた順番通りに、1つ終わるまで次に進まない」実行です。

```javascript
console.log('1');
const result = 10 + 20; // この計算が終わるまで次に行かない
console.log('2');
console.log(result);

// 出力: 1 → 2 → 30 (必ずこの順)
```

日常の例え: レジで順番待ちをしている状態。前の人が終わるまで自分の番は来ません。

### 非同期処理

**非同期的**とは「時間がかかる処理を開始したら、完了を待たずに次に進む」実行です。

```javascript
console.log('1');
setTimeout(() => console.log('非同期'), 1000);
console.log('2');

// 出力: 1 → 2 → (1秒後) 非同期
```

日常の例え: 宅配便を注文して、配達を待たずに他の作業を続ける状態。荷物は後で届きます。

### なぜ非同期が必要か

```javascript
// 同期的に書くと、画面が2秒間フリーズする
const data = fetchDataSync('/api'); // 2秒かかる
console.log('次の処理'); // fetchが終わるまで実行されない

// 非同期なら、待っている間に他の処理ができる
fetchDataAsync('/api').then(data => {
  console.log(data);
});
console.log('次の処理'); // すぐ実行される
```

---

## Promiseとは何か

### タイムカプセルの比喩

**Promiseは「未来のある時点で値が得られる」ことを表すタイムカプセル**です。

```javascript
// タイムカプセルを作成（中には非同期処理が入っている）
const capsule = new Promise((resolve, reject) => {
  setTimeout(() => {
    resolve('宝物'); // 1秒後に中身が決まる
  }, 1000);
});

// タイムカプセルが開くのを待って中身を取り出す
capsule.then(treasure => {
  console.log(treasure); // '宝物'
});
```

### 重要な特徴

1. **Promiseを作った瞬間に処理が開始される**

    ```javascript
    const promise = new Promise((resolve) => {
      console.log('処理開始!'); // すぐ実行される
      setTimeout(() => resolve('完了'), 1000);
    });

    console.log('次の処理');
    // 出力: 処理開始! → 次の処理 → (1秒後) 完了
    ```

2. **awaitしなくても処理は進行している**

    ```javascript
    async function example() {
      const capsule = fetch('/api'); // タイムカプセル作成＆処理開始
      
      console.log('他の作業...');
      // この間もfetchは裏で進行している
      
      const result = await capsule; // 完了を待って取り出す
    }
    ```

### Promiseの状態

Promiseは常に3つの状態のいずれかにあります:

- **pending**: 処理中（タイムカプセルがまだ開いていない）
- **fulfilled**: 成功（resolveが呼ばれた）
- **rejected**: 失敗（rejectが呼ばれた）

```javascript
const promise = fetch('/api');
console.log(promise); // Promise { <pending> }

// しばらくすると...
// Promise { <fulfilled>: Response }
// または
// Promise { <rejected>: Error }
```

---

## resolve と reject

### resolve: 成功時の値を返す

```javascript
const successPromise = new Promise((resolve, reject) => {
  const success = true;
  
  if (success) {
    resolve('成功しました!'); // この値が.thenに渡される
  }
});

successPromise.then(value => {
  console.log(value); // '成功しました!'
});
```

### reject: 失敗時のエラーを返す

```javascript
const failPromise = new Promise((resolve, reject) => {
  const success = false;
  
  if (!success) {
    reject(new Error('失敗しました')); // このエラーが.catchに渡される
  }
});

failPromise.catch(error => {
  console.error(error); // Error: 失敗しました
});
```

### 実用例: APIリクエスト

```javascript
function fetchUser(id) {
  return new Promise((resolve, reject) => {
    // データベースからユーザーを取得（仮）
    setTimeout(() => {
      if (id > 0) {
        resolve({ id, name: 'Akira' }); // 成功
      } else {
        reject(new Error('Invalid ID')); // 失敗
      }
    }, 1000);
  });
}

// 使い方
fetchUser(1)
  .then(user => console.log(user))   // { id: 1, name: 'Akira' }
  .catch(err => console.error(err));

fetchUser(-1)
  .then(user => console.log(user))
  .catch(err => console.error(err)); // Error: Invalid ID
```

---

## async/await の使い方

### async/awaitは糖衣構文

**Promise の連鎖を同期的な見た目で書けるようにしたもの**です。

```javascript
// Promise方式（読みにくい）
function getUserData() {
  return fetch('/api/user')
    .then(res => res.json())
    .then(data => data.profile)
    .then(profile => profile.name)
    .catch(err => console.error(err));
}

// async/await方式（読みやすい）
async function getUserData() {
  try {
    const res = await fetch('/api/user');
    const data = await res.json();
    const profile = data.profile;
    return profile.name;
  } catch (err) {
    console.error(err);
  }
}
```

### awaitの動作

```javascript
const res = await fetch('/api');
const data = await res.json();
```

ステップごとの解説:

1. `fetch('/api')` が **Promise<Response>** を返す
2. `await` でそのPromiseが解決されるまで待つ
3. `res` には **Response オブジェクト**（もうPromiseではない）が入る
4. `res.json()` が **Promise<any>** を返す
5. `await` でそのPromiseが解決されるまで待つ
6. `data` には **パース済みのオブジェクト** が入る

### 重要な原則

**awaitは「右側の式が返すPromise」が解決されるまで待つ**:

```javascript
// ❌ 誤解
await res.json(); // resのPromiseを待つ（resはもうPromiseではない）

// ✅ 正確
await res.json(); // res.json()が返すPromiseを待つ
```

### エラーハンドリング

```javascript
async function fetchData() {
  try {
    const res = await fetch('/api');
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    const data = await res.json();
    return data;
  } catch (error) {
    console.error('エラー:', error);
    // エラー処理
    return null;
  }
}
```

---

## 並列実行パターン

### 誤解: JavaScriptは真の並列実行はしない

JavaScriptは**シングルスレッド**なので、CPUレベルでの並列実行はありません。
しかし、**複数の非同期処理を同時に開始**することはできます。

### パターン1: 逐次実行（遅い）

```javascript
async function sequential() {
  const user = await fetch('/api/user');     // 2秒待つ
  const posts = await fetch('/api/posts');   // さらに2秒待つ
  // 合計: 4秒
}
```

日常の例え: スーパーで肉を買ってから、次に魚売り場に行く。

### パターン2: 同時開始（速い）

```javascript
async function concurrent() {
  // 両方すぐに開始（awaitしない）
  const userPromise = fetch('/api/user');
  const postsPromise = fetch('/api/posts');
  
  // 両方の完了を待つ
  const [user, posts] = await Promise.all([userPromise, postsPromise]);
  // 合計: 2秒（長い方に合わせる）
}
```

日常の例え: 肉と魚を別々の人に頼んで、両方揃うまで待つ。

### パターン3: Promise.all

```javascript
async function fetchMultiple() {
  try {
    const results = await Promise.all([
      fetch('/api/user'),
      fetch('/api/posts'),
      fetch('/api/comments')
    ]);
    
    // すべて成功した場合のみここに来る
    const [user, posts, comments] = results;
    return { user, posts, comments };
  } catch (error) {
    // 1つでも失敗したらここに来る
    console.error('いずれかが失敗:', error);
  }
}
```

### パターン4: Promise.allSettled（全部待つ）

```javascript
async function fetchMultipleSafe() {
  const results = await Promise.allSettled([
    fetch('/api/user'),
    fetch('/api/posts'),
    fetch('/api/comments')
  ]);
  
  // すべて完了（成功/失敗問わず）
  results.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      console.log(`結果${index}:`, result.value);
    } else {
      console.error(`エラー${index}:`, result.reason);
    }
  });
}
```

### パターン5: Promise.race（最初の1つ）

```javascript
async function fetchFastest() {
  const result = await Promise.race([
    fetch('https://api1.example.com/data'),
    fetch('https://api2.example.com/data'),
    fetch('https://api3.example.com/data')
  ]);
  
  // 最初に完了した1つだけ取得
  return result;
}
```

---

## 実践例

### 例1: データ取得と加工

```javascript
async function getUserProfile(userId) {
  try {
    // ユーザー情報を取得
    const userRes = await fetch(`/api/users/${userId}`);
    const user = await userRes.json();
    
    // そのユーザーの投稿を取得
    const postsRes = await fetch(`/api/users/${userId}/posts`);
    const posts = await postsRes.json();
    
    // データを統合
    return {
      ...user,
      postCount: posts.length,
      latestPost: posts[0]
    };
  } catch (error) {
    console.error('プロフィール取得失敗:', error);
    throw error;
  }
}

// 使い方
getUserProfile(123)
  .then(profile => console.log(profile))
  .catch(err => console.error(err));
```

### 例2: リトライロジック

```javascript
async function fetchWithRetry(url, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const res = await fetch(url);
      if (res.ok) {
        return await res.json();
      }
      throw new Error(`HTTP ${res.status}`);
    } catch (error) {
      console.log(`試行 ${i + 1}/${maxRetries} 失敗`);
      
      if (i === maxRetries - 1) {
        // 最後の試行も失敗
        throw error;
      }
      
      // 1秒待ってリトライ
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }
}
```

### 例3: タイムアウト付きfetch

```javascript
async function fetchWithTimeout(url, timeout = 5000) {
  const timeoutPromise = new Promise((_, reject) => {
    setTimeout(() => reject(new Error('タイムアウト')), timeout);
  });
  
  const fetchPromise = fetch(url);
  
  // どちらか早い方が採用される
  const res = await Promise.race([fetchPromise, timeoutPromise]);
  return await res.json();
}

// 使い方
try {
  const data = await fetchWithTimeout('/api/slow', 3000);
  console.log(data);
} catch (error) {
  console.error('失敗:', error.message); // 'タイムアウト'
}
```

### 例4: 複数APIの並列取得と統合

```javascript
async function getDashboardData(userId) {
  try {
    // 3つのAPIを同時に叩く
    const [user, posts, notifications] = await Promise.all([
      fetch(`/api/users/${userId}`).then(r => r.json()),
      fetch(`/api/users/${userId}/posts`).then(r => r.json()),
      fetch(`/api/users/${userId}/notifications`).then(r => r.json())
    ]);
    
    return {
      user,
      stats: {
        totalPosts: posts.length,
        unreadNotifications: notifications.filter(n => !n.read).length
      },
      recentPosts: posts.slice(0, 5),
      recentNotifications: notifications.slice(0, 10)
    };
  } catch (error) {
    console.error('ダッシュボードデータ取得失敗:', error);
    throw error;
  }
}
```

### 例5: 順次処理が必要な場合

```javascript
async function processItems(items) {
  const results = [];
  
  for (const item of items) {
    // 前の処理が終わってから次を実行
    const result = await processItem(item);
    results.push(result);
    
    // 処理結果に応じて次の処理を変える
    if (result.needsFollowUp) {
      await followUpProcess(result);
    }
  }
  
  return results;
}

async function processItem(item) {
  const res = await fetch('/api/process', {
    method: 'POST',
    body: JSON.stringify(item)
  });
  return await res.json();
}
```

---

## まとめ

### Promiseの本質

- **タイムカプセル**: 未来の値を表すオブジェクト
- **即座に開始**: 作成と同時に処理が始まる
- **状態管理**: pending → fulfilled/rejected

### async/awaitの本質

- **糖衣構文**: Promiseチェーンを読みやすくしたもの
- **awaitの役割**: Promiseの完了を待って値を取り出す
- **エラー処理**: try/catchで直感的に書ける

### パフォーマンスの鉄則

```javascript
// ❌ 遅い: 逐次実行
const a = await fetch('/api/a');
const b = await fetch('/api/b');

// ✅ 速い: 同時開始
const [a, b] = await Promise.all([
  fetch('/api/a'),
  fetch('/api/b')
]);
```

### 覚えておくべきこと

1. Promiseは作成時に処理が開始される
2. awaitは「Promiseが返す値」を待つ（Promiseを返す関数ではない）
3. 独立した複数の非同期処理は`Promise.all`で同時実行
4. 依存関係がある処理は順番に`await`する
5. JavaScriptはシングルスレッド（真の並列実行ではない）

この理解があれば、async/awaitを使った非同期処理は十分に扱えます！
