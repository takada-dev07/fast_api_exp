# Auth Cognito Test Lambda

Cognito User Poolを使用したJWT認証を実装した統合Lambda関数です。

## 機能

このLambda関数は3つの機能を統合しています：

1. **Lambda Authorizer**: Cognito User Poolから発行されたJWTトークンを検証
2. **Public Endpoint** (`/public`): 認証不要のエンドポイント
3. **Protected Endpoint** (`/protected`): 認証が必要なエンドポイント

## 依存関係

- `python-jose[cryptography]`: JWT検証用ライブラリ

## 環境変数

- `COGNITO_USER_POOL_ID`: Cognito User Pool ID
- `APP_AWS_REGION`: AWSリージョン（デフォルト: ap-northeast-1）

## 使用方法

### Serverless Frameworkでデプロイ

```bash
cd lambda/auth_cognito_test
npm install  # 初回のみ
sls deploy
```

### エンドポイント

- `/public`: 認証不要のエンドポイント
- `/protected`: 認証が必要なエンドポイント（このAuthorizerを使用）

## 認証方法

Protectedエンドポイントにアクセスする際は、AuthorizationヘッダーにJWTトークンを付与してください:

```
Authorization: Bearer <JWT_TOKEN>
```

JWTトークンは、Cognito User Poolから取得したIDトークンまたはアクセストークンを使用します。
