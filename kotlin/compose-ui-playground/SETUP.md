# Compose UI Playground - セットアップガイド

## 📋 プロジェクト概要

このプロジェクトは、MVI (Model-View-Intent) アーキテクチャと Jetpack Compose を使用したシンプルなカウンターアプリです。
Android Studio でのプレビュー機能のデモンストレーション用に作成されています。

## 🚀 セットアップ手順

### 1. Android Studio でプロジェクトを開く

```bash
# Android Studio を起動
# File → Open を選択
# このディレクトリ（compose-ui-playground）を選択
```

または、コマンドラインから：

```bash
cd /path/to/compose-ui-playground
open -a "Android Studio" .
```

### 2. Gradle Sync を実行

プロジェクトを開いたら、自動的に Gradle Sync が開始されます。
もし開始されない場合は、以下の手順を実行：

1. Android Studio 上部のツールバーから **File → Sync Project with Gradle Files**
2. または、エディタ上部に表示される「Sync Now」リンクをクリック

### 3. Android SDK の確認

このプロジェクトには以下が必要です：

- **compileSdk**: 34
- **minSdk**: 26
- **targetSdk**: 34
- **JDK**: 17

Android Studio の SDK Manager で必要な SDK がインストールされていることを確認してください：

1. **Tools → SDK Manager**
2. **SDK Platforms** タブで Android 14.0 (API 34) がインストールされているか確認
3. **SDK Tools** タブで Build-Tools がインストールされているか確認

## 🎨 プレビュー機能の使用方法

### CounterMviExample.kt を開く

1. Project ビューで以下のパスに移動：

   ```text
   app/src/main/java/com/example/playground/CounterMviExample.kt
   ```

2. ファイルをダブルクリックして開く

### プレビューを表示

エディタ右上の **「Split」** ボタンをクリックすると、エディタが分割されてプレビューが表示されます。

以下の5つのプレビューが確認できます：

1. ✅ 初期状態（カウント0）
2. ✅ 正の偶数（カウント10）
3. ✅ 正の奇数（カウント7）
4. ✅ 負の偶数（カウント-4）
5. ✅ ダークモード（カウント42）

### インタラクティブモードを試す

1. プレビュー画面上部の **「Interactive」** ボタンをクリック
2. ボタンをクリックしてカウンターの動作を確認

**注意**: インタラクティブモードでは実際の ViewModel は使用されないため、状態は保持されません。

## 🏃 アプリの実行

### エミュレータまたは実機で実行

1. Android Studio 上部のツールバーから実行デバイスを選択
2. 再生ボタン（緑の三角形）をクリック
3. アプリが起動し、カウンター画面が表示されます

### ビルド確認

```bash
# デバッグビルド
./gradlew :app:assembleDebug

# リリースビルド
./gradlew :app:assembleRelease
```

## 📁 プロジェクト構造

```text
compose-ui-playground/
├── app/
│   ├── src/
│   │   └── main/
│   │       ├── java/com/example/playground/
│   │       │   ├── CounterMviExample.kt  # MVIサンプル実装
│   │       │   └── MainActivity.kt       # メインアクティビティ
│   │       ├── res/
│   │       │   ├── values/
│   │       │   │   ├── strings.xml
│   │       │   │   ├── themes.xml
│   │       │   │   └── colors.xml
│   │       │   └── mipmap-*/            # アプリアイコン
│   │       └── AndroidManifest.xml
│   ├── build.gradle.kts                 # アプリモジュールのビルド設定
│   └── proguard-rules.pro
├── build.gradle.kts                      # プロジェクトレベルのビルド設定
├── settings.gradle.kts                   # Gradle設定
├── gradle.properties                     # Gradleプロパティ
├── README.md                            # プロジェクト説明
├── HOWTO_PREVIEW.md                     # プレビュー使用方法の詳細
└── SETUP.md                             # このファイル
```

## 🧪 主な機能

### 1. MVIアーキテクチャ

- **Intent**: ユーザーのアクションを型安全に定義
- **State**: 画面の状態を単一のデータクラスで管理
- **ViewModel**: ビジネスロジックと状態管理を担当

### 2. Jetpack Compose

- 宣言的UIフレームワーク
- Material Design 3 コンポーネント
- 状態駆動のリアクティブUI

### 3. プレビュー機能

- 複数の状態パターンを同時プレビュー
- ダークモード対応
- インタラクティブモード

## 🔧 トラブルシューティング

### プレビューが表示されない

1. Gradle Sync を実行: **File → Sync Project with Gradle Files**
2. ビルドを実行: **Build → Make Project**
3. Android Studio を再起動

### ビルドエラー

```bash
# Gradleキャッシュをクリア
./gradlew clean

# 再ビルド
./gradlew :app:assembleDebug
```

### SDK関連エラー

1. **Tools → SDK Manager** を開く
2. 必要なSDKがインストールされているか確認
3. Android Studio を再起動

## 📚 参考リンク

- [Jetpack Compose 公式ドキュメント](https://developer.android.com/jetpack/compose)
- [Preview in Compose](https://developer.android.com/jetpack/compose/tooling/previews)
- [MVI Architecture Pattern](https://hannesdorfmann.com/android/model-view-intent/)
- [Material Design 3](https://m3.material.io/)

## 💡 学習のヒント

1. **CounterMviExample.kt** を読んで、MVIの基本構造を理解する
2. プレビュー機能で異なる状態パターンを確認する
3. コードを修正してプレビューがリアルタイムで更新されることを確認する
4. 新しいIntentやStateプロパティを追加してみる

## 🎯 次のステップ

基本的な実装を理解したら、以下にチャレンジしてみてください：

1. 新しいIntent（例：カウントを2倍にする）を追加
2. UIに新しい要素（例：カウント履歴）を追加
3. アニメーションを追加
4. 非同期処理（例：遅延カウント）を実装

Happy Coding! 🚀
