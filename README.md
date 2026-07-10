# NatureRemoMac

Nature RemoをMacから操作するための、非公式・オープンソースのmacOSアプリです。
Nature株式会社による公式アプリではなく、同社の承認・サポートを受けたものではありません。

> [!IMPORTANT]
> 現在はソースコードのみを公開対象としています。Developer ID署名・Notarization済みの
> `.app` ダウンロードは提供していません。利用するMac上でソースからビルドしてください。

## 主な機能

- Nature Remoアカウント、デバイス、センサー値の取得
- 登録済み家電と学習済み赤外線信号の一覧表示・送信
- エアコンの運転モード、温度、風量、風向、電源操作
- ライトとテレビの主要ボタン操作
- ダッシュボードとメニューバーからのクイック操作
- Personal access tokenのmacOS Keychain保存
- 1分間隔の家電状態更新

## 必要なもの

- macOS 13 Ventura以降
- Xcode 15以降
- Natureアカウント
- Nature Remo本体と、Nature公式アプリで登録済みの家電
- 自分のNature Remo Personal access token

## セットアップ

### 1. Xcodeを準備する

[Mac App Store](https://apps.apple.com/jp/app/xcode/id497799835)からXcodeをインストールし、
一度起動して初期設定を完了してください。

ターミナルで次のコマンドを実行し、開発ツールが使用できることを確認します。

```bash
xcode-select -p
swift --version
```

### 2. ソースコードを取得する

```bash
git clone https://github.com/tomato-ga/NatureRemoMac.git
cd NatureRemoMac
```

### 3. ビルドして起動する

```bash
./script/build_and_run.sh
```

このスクリプトは次の処理を行います。

1. SwiftPMでアプリをビルド
2. `dist/NatureRemoMac.app` を生成
3. ローカル実行用のAd Hoc署名を付与
4. 生成したアプリを起動

ローカルビルドにはApple Developer Programへの加入は不要です。

### 4. `/Applications` に配置する

Release構成のアプリを生成します。

```bash
./script/build_and_run.sh --build-only --configuration release
open dist
```

Finderで `NatureRemoMac.app` を「アプリケーション」フォルダへドラッグしてください。
以後はLaunchpad、Spotlight、または `/Applications/NatureRemoMac.app` から起動できます。

古いコピーを別の場所から起動するとKeychain設定を正しく読めない場合があります。
通常利用するアプリは `/Applications/NatureRemoMac.app` の1つに統一してください。

### 5. Nature Remoアクセストークンを発行する

1. [Nature Home](https://home.nature.global/)を開く
2. Natureアカウントでログインする
3. アクセストークン発行画面から新しいPersonal access tokenを発行する
4. 表示されたトークンをコピーする

トークンはNature Remoと登録家電を操作できる認証情報です。他人と共有しないでください。

### 6. アプリにトークンを設定する

1. NatureRemoMacを起動する
2. `Personal access token` 欄にトークンを貼り付ける
3. `保存` ボタンを押す
4. アカウント名、デバイス、家電が表示されることを確認する

保存時に `/1/users/me`、`/1/devices`、`/1/appliances` へ接続し、トークンと
レスポンスを検証します。すべて成功した場合だけ、トークンをmacOS Keychainへ保存します。

保存先のKeychainサービス名は次のとおりです。

```text
io.github.tomato-ga.NatureRemoMac
```

## 基本的な使い方

### データを更新する

ウィンドウ右上の更新ボタン、または `Command + R` を押します。

更新時に次の情報を取得します。

- Natureアカウント
- Nature Remoデバイスとセンサー値
- 登録済み家電
- 家電の現在状態
- 学習済み赤外線信号

アプリの起動中は、家電状態だけを1分間隔で自動更新します。

### 家電を選択する

左サイドバーから操作したい家電を選択します。家電の種類に応じて、エアコン、ライト、
テレビ、学習リモコン用の操作画面が表示されます。

### エアコンを操作する

エアコン画面では、Nature APIがその機種について返した選択肢の範囲で次を変更できます。

- 電源オン・オフ
- 運転モード
- 設定温度
- 風量
- 上下風向
- 左右風向
- 内部クリーンなどの固定ボタン

操作後は家電状態を再取得します。Nature Remoが保持している状態であり、家電本体から
リアルタイムに読み取った状態とは限りません。

### ライト・テレビを操作する

Nature公式アプリで登録済みのボタンが表示されます。ボタンが表示されない場合は、先に
Nature公式アプリで対象家電とリモコンボタンを設定してください。

### 学習済み信号を送信する

家電詳細画面の「その他の操作」から、Nature公式アプリで学習済みの赤外線信号を送信できます。

### メニューバーから操作する

アプリ起動中はメニューバーにRemoアイコンが表示されます。よく使うライト、テレビ、
学習済み信号を、メインウィンドウを開かずに送信できます。

### トークンを確認・変更・削除する

ウィンドウ右上の歯車ボタンから設定画面を開きます。

- `確認`: 保存済みトークンでデータを再取得
- `トークンを保存`: 新しいトークンを検証して保存
- `削除`: Keychainからトークンを削除して未接続状態へ戻す

セキュリティ上、保存済みトークンをアプリ画面へ再表示する機能はありません。

## アプリを更新する

```bash
cd NatureRemoMac
git pull --ff-only
swift test
./script/build_and_run.sh --build-only --configuration release
open dist
```

Finderで新しい `NatureRemoMac.app` を「アプリケーション」フォルダへドラッグし、既存アプリを
置き換えてください。Bundle IDが同じであれば、Keychainのトークンは引き続き使用されます。

## 開発・確認用コマンド

```bash
# Debugビルドして起動
./script/build_and_run.sh

# 起動せずにDebugアプリを生成
./script/build_and_run.sh --build-only

# Releaseアプリを生成
./script/build_and_run.sh --build-only --configuration release

# ビルド・起動後にプロセスを確認
./script/build_and_run.sh --verify

# 実トークンを使用しない単体テスト
swift test

# アイコンを正本PNGから再生成
./script/generate_app_icon.sh
```

テストでは匿名化したfixtureと `MockURLProtocol` を使用します。CIや単体テストから実際の
Nature APIへ接続することはありません。

## トラブルシューティング

### `The Nature Remo access token was rejected` と表示される

トークンが無効または失効しています。[Nature Home](https://home.nature.global/)で新しい
トークンを発行し、設定画面から保存し直してください。

### `HTTP 429` またはリクエスト制限が表示される

Nature Cloud APIは、アカウント単位で5分間に30リクエスト以上を受けるとHTTP 429を返します。
数分待ってから再度更新してください。アプリは429を受け取るとバックグラウンド更新を一時停止します。

### 家電やボタンが表示されない

- Nature公式アプリで対象家電が登録済みか確認する
- Nature Remo本体がオンラインか確認する
- 設定画面の `確認` またはウィンドウ右上の更新ボタンを押す
- Nature公式アプリでリモコンボタンや赤外線信号を登録する

### アプリを置き換えた後に `Token Required` と表示される

- `/Applications/NatureRemoMac.app` を起動しているか確認する
- 古いBundle IDのアプリや、別ディレクトリにあるコピーを終了する
- 設定画面でトークンを保存し直す

### ビルドできない

Xcodeを一度起動して初期設定とライセンス確認を完了した後、次を確認してください。

```bash
xcode-select -p
swift --version
```

## トークンとプライバシー

- トークンはローカルのmacOS Keychainに保存します
- トークンはHTTPSの `Authorization` ヘッダーで `https://api.nature.global` にのみ送信します
- 開発者が運用するバックエンドはありません
- 解析、広告、クラッシュレポート、テレメトリSDKは含みません
- アカウント、デバイス、家電情報を開発者へ送信しません

トークンをIssue、Pull Request、スクリーンショット、テストfixture、ログへ貼らないでください。
漏えいした場合は、投稿を削除するだけでなくNature Homeから直ちに失効させてください。

詳細は[PRIVACY.md](PRIVACY.md)と[SECURITY.md](SECURITY.md)を参照してください。

## プロジェクトの状態

初期のソースリリースです。家電やNature Remoの構成によって動作が異なる可能性があります。
無人運転や、人の生命・身体・財産に影響する安全性が重要な用途には使用しないでください。

## コントリビューション

変更を送る前に[CONTRIBUTING.md](CONTRIBUTING.md)を確認してください。

## 法的表示

Nature APIの利用にはNatureの規約が適用されます。商用利用にはNature株式会社との個別合意が
必要になる場合があります。「Nature」「Nature Remo」はNature株式会社の商標または登録商標です。
詳細は[NOTICE.md](NOTICE.md)を参照してください。

## ライセンス

本プロジェクトのコードとプロジェクト独自資産は[MIT License](LICENSE)で公開します。
このライセンスは、Nature株式会社のAPI、サービス、商標に関する権利を許諾するものではありません。
