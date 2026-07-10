# Privacy

NatureRemoMac is designed as a local client with no developer-operated backend.

- The Nature Remo personal access token is stored as a generic password in the
  user's macOS Keychain.
- The token is sent only to `https://api.nature.global` in the HTTPS
  `Authorization` header.
- Account, device, sensor, and appliance responses are held in app memory and
  are not uploaded to the project maintainer.
- The app includes no analytics, advertising, crash-reporting, or telemetry SDK.
- Removing the token in Settings deletes the app's Keychain item.

Nature Inc. processes data received by the Nature API under its own terms and
privacy policy. This project does not control that processing.

## 日本語

NatureRemoMacは、開発者が運用するバックエンドを持たないローカルクライアントです。

- アクセストークンはmacOS Keychainの汎用パスワードとして保存します。
- トークンはHTTPSの`Authorization`ヘッダーで`https://api.nature.global`にのみ送信します。
- アカウント、デバイス、センサー、家電情報はアプリのメモリ上で扱い、開発者へ送信しません。
- 解析、広告、クラッシュレポート、テレメトリSDKは含みません。
- Settingsからトークンを削除すると、Keychain項目も削除します。

Nature APIへ送信されたデータは、Nature株式会社の規約とプライバシーポリシーに基づいて
同社が処理します。本プロジェクトはその処理を管理しません。
