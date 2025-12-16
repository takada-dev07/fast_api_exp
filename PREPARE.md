# PREPARE（他環境で動かす手順）

このドキュメントは、このリポジトリを **別のPC/別アカウント/別環境** で動かすときに、
Terraform でフル apply した後に必要になる「手作業」をまとめたものです。

## 前提

- AWS 認証情報が設定済み（Terraform が apply できる権限）
- `terraform` / `python` / `pip` / `zip` がローカルにあること  
  （`infra/main.tf` の `local-exec` で `pip install` と `zip` を使って Lambda をパッケージします）

## 1) Terraform を apply する

```bash
cd infra
terraform init
terraform apply
```

## 2) Terraform outputs を確認する（後続手順で使用）

以下の output を使います（定義は `infra/outputs.tf`）。

- `cognito_hosted_ui_base_url`
- `cognito_user_pool_client_id`
- `api_protected_endpoint`

例:

```bash
cd infra
terraform output
```

個別に raw で取得したい場合:

```bash
cd infra
terraform output -raw cognito_hosted_ui_base_url
terraform output -raw cognito_user_pool_client_id
terraform output -raw api_protected_endpoint
```

## 3) Cognito にユーザーを追加する

Hosted UI でログインするために、User Pool にユーザーを作成します。

### 方法A: AWS Console で作成

1. Cognito → User pools → 対象の User Pool を開く  
2. Users → Create user  
3. ユーザー名/メールアドレス、初期パスワードを設定  
4. 初回サインイン時にパスワード変更が要求されたら変更する  

※メール検証が必要な設定の場合、確認コード入力や検証完了が必要です。

### 方法B: AWS CLI で作成（例）

User Pool ID は `terraform output -raw cognito_user_pool_id` で取得できます。

```bash
aws cognito-idp admin-create-user \
  --user-pool-id "$(cd infra && terraform output -raw cognito_user_pool_id)" \
  --username "test-user" \
  --user-attributes Name=email,Value="test-user@example.com" \
  --temporary-password "TempPassw0rd!"
```

（必要に応じて）恒久パスワードに設定:

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id "$(cd infra && terraform output -raw cognito_user_pool_id)" \
  --username "test-user" \
  --password "NewPassw0rd!" \
  --permanent
```

## 4) ローカル検証UIの `config.js` に outputs を反映する

ローカル検証UI（`ui/hosted_ui_local/`）は静的ファイルで、
環境ごとの値は `ui/hosted_ui_local/config.js` に手で設定します。

`ui/hosted_ui_local/config.js` の以下を埋めてください:

- `cognitoBaseUrl` ← `cognito_hosted_ui_base_url`
- `clientId` ← `cognito_user_pool_client_id`
- `apiProtectedEndpoint` ← `api_protected_endpoint`

注意:

- `redirectUri` は `http://localhost:3000/callback.html`
- `logoutRedirectUri` は `http://localhost:3000/logout.html`

これらは Terraform 側の Cognito User Pool Client 設定（callback/logout URLs）と一致している必要があります。

## 5) UI をローカルで起動する

`http://localhost:3000` で `ui/hosted_ui_local/` を配信します。

例（Python）:

```bash
python -m http.server 3000 --directory ui/hosted_ui_local
```

ブラウザで `http://localhost:3000/` を開きます。

## 6) 動作確認（Hosted UI → PKCE → /protected）

1. `Login (Hosted UI)` を押して Hosted UI でログイン  
2. `callback.html` にリダイレクトされ、token 交換が成功すると `sessionStorage` に保存されます  
3. `index.html` に戻って `Call /protected` を押す  

補足:

- `/protected` は **access token 前提**です（UI は `access_token` を送る実装です）
- もし 401/403 になる場合は、`config.js` の値・Cognitoユーザー・CORS設定（`allowed_origins`）を確認してください

## よくあるハマりどころ

- **CORS**: ブラウザから `/protected` を叩くため、Terraform の `allowed_origins` に `http://localhost:3000` を含める必要があります
- **Hosted UI の callback/logout URL 不一致**: Cognito 側の設定と `config.js` の `redirectUri` / `logoutRedirectUri` がズレるとログイン後にエラーになります
- **依存パッケージのzip作成に失敗**: `pip` や `zip` が無い/古いと Terraform apply 中に失敗します
