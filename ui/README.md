# ui/

このディレクトリは **Cognito Hosted UI（Authorization Code + PKCE）** を使って、
取得した **Access Token** で API Gateway の `/protected` を呼び出すまでを検証するための静的UIです。

この UI は以下のどちらでも配信できます：

- **CloudFront + S3（推奨）**: Terraform apply 後に AWS 上へ自動デプロイして検証
- **ローカル静的ホスト**: `python -m http.server` などで配信して検証（従来どおり）

## 何ができる？

- Hosted UI にリダイレクトしてログイン（PKCE）
- `callback.html` で `oauth2/token` にコード交換してトークン取得
- `access_token` を `Authorization: Bearer ...` で付けて `/protected` を呼び出し
- `logout.html` で `sessionStorage` をクリア

## 構成

`ui/hosted_ui_local/` の中は静的ファイルだけです（ビルド不要）。

- `index.html`: 操作画面（Login / Call /protected / Logout / Clear）
- `app.js`: Hosted UI への遷移、`/protected` 呼び出し、表示更新
- `pkce.js`: PKCE（S256）のヘルパー
- `callback.html`: code + state を受け取り token 交換して `sessionStorage` に保存
- `logout.html`: `sessionStorage` をクリア
- `config.js`: 環境に依存する値
  - **CloudFront**: Terraform が生成した `config.js` が配信される（手作業不要）
  - **ローカル**: `ui/hosted_ui_local/config.js` を手で編集（従来どおり）

## 事前準備（Terraform outputs を config.js に反映）

### A. CloudFront（推奨）

Terraform 適用後に、CloudFront の URL を開きます：

```bash
cd infra
open "$(terraform output -raw ui_base_url)"
```

### B. ローカル（任意）

Terraform 適用後に、`infra/outputs.tf` の値を `ui/hosted_ui_local/config.js` に反映します。

最低限必要な値:

- `cognito_hosted_ui_base_url`
- `cognito_user_pool_client_id`
- `api_protected_endpoint`

加えて、`redirectUri` / `logoutRedirectUri` は Terraform 側の Cognito User Pool Client 設定と一致させてください。
（このリポジトリは `callback.html` / `logout.html` を前提にしています）

## 起動方法（ローカルで静的ホスト）

`ui/hosted_ui_local/` を `http://localhost:3000` で配信してください。

例（Python）:

```bash
python -m http.server 3000 --directory ui/hosted_ui_local
```

ブラウザで `http://localhost:3000/` を開きます。

## 使い方（ざっくり）

1. `Login (Hosted UI)` を押す
2. Hosted UI でサインイン → `callback.html` に戻る
3. `index.html` に戻って `Call /protected` を押す

## 注意点

- **/protected は access_token 前提**です（id_token を渡しても弾く実装になっています）。
- トークンは **`sessionStorage`** に保存しています（ブラウザを閉じると消えます）。
- API Gateway 側は CORS を許可する必要があります（Terraform で `allowed_origins` を `http://localhost:3000` に含める前提）。
