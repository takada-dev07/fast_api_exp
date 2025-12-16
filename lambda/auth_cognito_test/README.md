# Auth Cognito Test Lambda

Cognito User Pool を使った JWT 認証（Authorizer）と、
検証用の `/public`・`/protected` を **1つのLambdaに統合**したサンプルです。

## 機能

このLambda関数は3つの機能を統合しています：

1. **Lambda Authorizer**: Cognito User Poolから発行されたJWTトークンを検証
2. **Public Endpoint** (`/public`): 認証不要のエンドポイント
3. **Protected Endpoint** (`/protected`): 認証が必要なエンドポイント

## 依存関係

- `python-jose[cryptography]`: JWT検証用ライブラリ

## 環境変数

- `COGNITO_USER_POOL_ID`: Cognito User Pool ID
- `COGNITO_USER_POOL_CLIENT_ID`: User Pool App Client ID（access token の `client_id` 検証に使用）
- `APP_AWS_REGION`: AWSリージョン（デフォルト: ap-northeast-1）
- `DEBUG_AUTHORIZER_CONTEXT`: `1` のとき `requestContext.authorizer` の中身をログ出力（デフォルト `0`）

## デプロイ方法

このLambdaは Terraform 管理（`infra/`）でデプロイする想定です。
依存関係（`requirements.txt`）込みのZIP作成は Terraform の `local-exec` で行います。

詳細は `infra/README_TERRAFORM.md` を参照してください。

### エンドポイント

- `/public`: 認証不要のエンドポイント
- `/protected`: 認証が必要なエンドポイント（API Gateway から Lambda Authorizer を経由）

## 認証方法

Protectedエンドポイントにアクセスする際は、AuthorizationヘッダーにJWTトークンを付与してください:

```text
Authorization: Bearer <JWT_TOKEN>
```

このサンプルは **Access Token 前提**です（`token_use=access` を検証します）。

## 実装メモ（今回の変更点）

- **Authorizer context の吸収**:
  - HTTP API の payload 2.0 では `requestContext.authorizer.lambda` 配下に context が入ることがあるため、
    どちらでも取れるように正規化しています。
- **トークン検証の方針**:
  - Cognito の access token では `aud` 検証が環境差で扱いづらいことがあるため `verify_aud` を無効化し、
    代わりに `client_id` を `COGNITO_USER_POOL_CLIENT_ID` と照合します。
- **/protected のレスポンス**:
  - `sub` / `username` / `client_id` / `scope` を返します（access token は claim が少ないため）。
