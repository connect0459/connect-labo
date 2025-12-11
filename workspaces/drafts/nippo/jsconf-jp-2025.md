# 【日報】2025-11-17

## JSConf JP 2025

[JSConf JP 2025](https://jsconf.jp/2025/ja) に行ってきた。面白かったTemporal APIとusing宣言についてサッと紹介したい。

### Immutable Date ObjectとしてのTemporal API

Temporal APIはJSで広く利用されてきたDateオブジェクトが抱える根本的な欠陥を解決するための新機能。ミュータビリティ（可変性）、タイムゾーン処理の曖昧さ、0ベースの月インデックス、信頼性の低い文字列パースなどに焦点を当ててより堅牢なオブジェクト生成を目指した設計となっている。例をいくつか紹介する。

#### 1. ミュータブル（可変性）の問題

`Date`オブジェクトはミュータブルで、setterメソッドが元のオブジェクトを変更することができる。生オブジェクトのままでは不変性を保証できないので、扱いに注意を要する。

```javascript
const today = new Date(2025, 10, 16);
const tomorrow = today;

tomorrow.setDate(tomorrow.getDate() + 1);

console.log(today);    // Sun Nov 17 2025 (意図しない変更)
console.log(tomorrow); // Sun Nov 17 2025

// 同じオブジェクトを参照している
console.log(today === tomorrow); // true
```

これに対してTemporalでは、すべてのメソッドが新しいインスタンスを返すイミュータブルな設計になっている。

```javascript
const today = Temporal.PlainDate.from('2025-11-16');
const tomorrow = today.add({ days: 1 });

console.log(today.toString());    // "2025-11-16" (変更されない)
console.log(tomorrow.toString()); // "2025-11-17"

// 異なるオブジェクト
console.log(today === tomorrow); // false
```

#### 2. タイムゾーンサポートの欠如

`Date`はUTCとローカルタイムゾーンの2つしかサポートせず、任意のタイムゾーンを指定できない。これにより、異なるタイムゾーンのユーザー間でデータを共有すると不整合が発生したり、サーバーとクライアントでタイムゾーンが異なると日付がずれたりする。

```javascript
// ローカルタイムゾーンで作成される
const date = new Date(1999, 0, 1); // 1999年1月1日 00:00:00

// タイムゾーンによって異なるタイムスタンプが生成される
// UTC: 915148800000
// UTC+3:00: 915138000000
// UTC-5:00: 915166800000

// 特定のタイムゾーンを指定する方法がない
const meetingTime = new Date(2025, 10, 20, 14, 0);
// これは常にローカルタイムゾーンで解釈される
```

Temporalではタイムゾーンを明示的に指定でき、IANAのタイムゾーンデータベースに対応している。これにより、Dateオブジェクトよりも簡単にタイムゾーンの指定や変換が可能となっている。

```javascript
// 特定のタイムゾーンで日時を作成
const tokyoMeeting = Temporal.ZonedDateTime.from({
  year: 2025, month: 11, day: 20,
  hour: 14, minute: 0,
  timeZone: 'Asia/Tokyo'
});

// 他のタイムゾーンに変換
const nyMeeting = tokyoMeeting.withTimeZone('America/New_York');

console.log(tokyoMeeting.toString());
// "2025-11-20T14:00:00+09:00[Asia/Tokyo]"

console.log(nyMeeting.toString());
// "2025-11-20T00:00:00-05:00[America/New_York]"

console.log(`東京14:00 = ニューヨーク${nyMeeting.hour}:00`);
// "東京14:00 = ニューヨーク0:00"
```

2025-11-16現在、Temporal APIはECMAScript標準化の議論においてStage 3にあり、ブラウザの標準サポートの完了を待つ段階となっている。安定サポートしているブラウザは現状Firefoxのみらしく、ChromeやSafariは実験導入の段階にあるそう。そのため、本番利用はまだ先の話になる見通し。

### using宣言によるリソース管理

`using`宣言は、リソースの自動クリーンアップを保証する新しいJavaScriptの機能。これにより、ファイル、データベース接続、ロックなどのリソースの開放処理が楽に書けるらしい。

例としては、以下のようなコードでリソースを手動で管理する場合、解放を忘れたり、エラー発生時に解放されないリスクがあった。

```javascript
// 従来の方法
function processFile() {
  const file = openFile('data.txt');
  
  try {
    // ファイル処理
    const data = file.read();
    // エラーが発生する可能性
    processData(data);
  } finally {
    // 手動でクリーンアップが必要
    file.close();
  }
}
```

ここで新たに定義された`using`宣言を使うと、スコープを抜ける際に自動的にリソースが解放されるようになる。

```javascript
function processFile() {
  using file = openFile('data.txt');
  
  // ファイル処理
  const data = file.read();
  processData(data);
  
  // スコープを抜けると自動的にfile.close()が呼ばれる
}
```

以下のように、複数のファイルやDBコネクションなども`using`で宣言すると、スコープを抜けたと同時にリソースが解放されるので、どちらかと言えばバックエンドの処理に向いてる感じかな。

```javascript
function transferData() {
  using source = openFile('source.txt');
  using destination = openFile('destination.txt');
  
  // 両方のファイルを使った処理
  destination.write(source.read());
  
  // 両方のファイルが自動的に閉じられる
  // (宣言の逆順で: destination → source)
}
```

`using`宣言は現在Stage 3となっており、安定化を待つ状況。イメージとしては、Go言語の `defer` に近い気もする。ただ、 `defer` は任意の関数に対して明示的に宣言するのに対して、JSの `using` は解放対象に `Symbol.dispose` メソッドを実装する必要があることや、ブロックの終了時に解放操作が行われるので、その辺の違いはありそう。
