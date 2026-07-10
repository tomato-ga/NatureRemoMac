# NatureRemoMac

[English](README.md)

Nature RemoをMacから操作するための、非公式・オープンソースのmacOSアプリです。
Nature株式会社による公式アプリではなく、同社の承認・サポートを受けたものではありません。

> [!IMPORTANT]
> 現在はソースコードのみを公開対象としています。Developer ID署名・Notarization済みの
> `.app` ダウンロードは提供しません。

## 主な機能

- Nature Remoアカウント、デバイス、センサー値の取得
- 家電と学習済み赤外線信号の一覧表示・送信
- ライト・テレビの主要ボタン操作
- エアコンの基本設定と電源オフ
- ダッシュボードとメニューバーからのクイック操作
- Personal access tokenのmacOS Keychain保存

## 必要環境

- macOS 13 Ventura以降
- Xcode 15以降（アプリ生成スクリプトがXcodeのローカライズツールを使用します）
- Natureアカウントと、自分で発行したNature Remoアクセストークン

## ビルドと起動

リポジトリをcloneし、次を実行します。

```bash
./script/build_and_run.sh
```

SwiftPMでビルドした後、`dist/NatureRemoMac.app` を生成し、ローカル用のAd Hoc署名を
付けて起動します。ローカルビルドにApple Developer Programへの加入は不要です。

```bash
# 起動せずにアプリをビルド
./script/build_and_run.sh --build-only

# Release構成でビルド
./script/build_and_run.sh --build-only --configuration release

# ビルド・起動・プロセス確認
./script/build_and_run.sh --verify

# 実トークンを使わない単体テスト
swift test
```

## 初回設定

1. [Nature Home](https://home.nature.global/)を開きます。
2. 自分のPersonal access tokenを発行またはコピーします。
3. NatureRemoMacの初期設定画面にトークンを貼り付けます。
4. 保存すると、APIで有効性を確認してからKeychainへ保存します。

トークンをIssue、Pull Request、スクリーンショット、テストfixture、ログへ貼らないで
ください。漏えいした場合は、Nature Homeから直ちに失効させてください。

## データフローとプライバシー

開発者が運用するバックエンドはなく、解析・広告SDKも含みません。APIリクエストはMacから
`https://api.nature.global` へ直接送信され、トークンはローカルのmacOS Keychainへ
保存されます。詳細は[PRIVACY.md](PRIVACY.md)を参照してください。

## APIリクエスト制限

Nature Cloud APIは、アカウント単位で5分30リクエストを超えるとHTTP 429を返す場合が
あります。本アプリは操作後の再取得回数を抑え、429時にはバックグラウンド更新を一時停止しますが、
短時間の連続操作では制限に達する可能性があります。

## プロジェクトの状態

初期のソースリリースです。家電やRemoの構成によって動作が異なる可能性があります。
無人運転や安全性が重要な用途には使用しないでください。

## コントリビューションとセキュリティ

変更を送る前に[CONTRIBUTING.md](CONTRIBUTING.md)を確認してください。脆弱性は公開Issueではなく、
[SECURITY.md](SECURITY.md)の方法で報告してください。

## 法的表示

Nature APIの利用にはNatureの規約が適用されます。商用利用にはNature株式会社との個別合意が
必要になる場合があります。「Nature」「Nature Remo」はNature株式会社の商標または登録商標です。
詳細は[NOTICE.md](NOTICE.md)を参照してください。

## ライセンス

本プロジェクトのコードとプロジェクト独自資産は[MIT License](LICENSE)で公開します。
このライセンスは、Nature株式会社のAPI、サービス、商標に関する権利を許諾するものではありません。
