# FastAPI実験プロジェクト

このプロジェクトは、AWS LambdaとAPI Gatewayを使用したサーバーレスアプリケーションの実験・学習用プロジェクトです。Terraformを使用してインフラをコードとして管理し、PythonでLambda関数を実装しています。

## プロジェクト構成

```text
fast_api_exp/
├── infra/                    # Terraformインフラストラクチャコード
│   ├── deploy/              # デプロイスクリプト
│   ├── main.tf              # メインリソース定義
│   ├── variables.tf         # 変数定義
│   ├── outputs.tf           # 出力定義
│   ├── providers.tf         # Provider設定
│   ├── versions.tf          # Terraformバージョン制約
│   └── README_TERRAFORM.md  # Terraform詳細ドキュメント
└── lambda/                   # Lambda関数コード
    ├── hello/               # Hello World Lambda関数
    └── auth_cognito_test/   # Cognito認証テストLambda関数
└── ui/                       # Hosted UI(PKCE) のローカル検証UI
    └── hosted_ui_local/      # 静的ファイル（ブラウザだけで動作）
```

## プロジェクト概要

このプロジェクトは、AWSサーバーレスアーキテクチャの学習と実験を目的としており、以下の技術スタックを使用しています：

- **インフラ**: Terraform（IaC）
- **コンピューティング**: AWS Lambda（Python 3.12）
- **API**: AWS API Gateway（HTTP API）
- **認証**: Amazon Cognito User Pool
- **リージョン**: ap-northeast-1（東京）

## できること

### 1. Hello World API

- シンプルなHello Worldエンドポイントを提供
- 認証不要の公開エンドポイント
- Lambda関数とAPI Gatewayの基本的な連携を学習

### 2. Cognito認証機能

- **Lambda Authorizer**: Cognito User Poolから発行されたJWTトークンの検証
- **Public Endpoint** (`/public`): 認証不要のエンドポイント
- **Protected Endpoint** (`/protected`): 認証が必要なエンドポイント
- JWTトークンの検証とユーザー情報の取得

### 3. Hosted UI（Authorization Code + PKCE）をローカルで検証

- Cognito Hosted UI でログイン（Authorization Code + PKCE）
- ブラウザから `oauth2/token` にコード交換してトークン取得（PKCE）
- 取得した **Access Token** で `/protected` を呼び出して認証の疎通確認

### 3. インフラ管理

- Terraformを使用したインフラのコード化
- Lambda関数の自動パッケージングとデプロイ
- API GatewayとLambdaの統合設定
- IAMロールとポリシーの管理

## 主な機能

- **サーバーレスアーキテクチャ**: Lambda関数によるイベント駆動型の処理
- **JWT認証**: Cognito User Poolを使用したセキュアな認証
- **IaC**: Terraformによる再現可能なインフラ管理
- **自動デプロイ**: スクリプトによるデプロイ自動化

## 今回の作業まとめ（ローカル差分から）

- **Cognito Hosted UI の整備**: Hosted UI ドメインを Terraform で作成（ランダムsuffixで衝突回避）
- **OAuthフローの整理**: User Pool Client を Authorization Code に寄せ、リダイレクト先を `callback.html` / `logout.html` に統一
- **API Gateway HTTP API の調整**: CORS設定、payload format version 2.0 を明示
- **Authorizer の堅牢化**:
  - `requestContext.authorizer` / `requestContext.authorizer.lambda` の差を吸収
  - **Access Token のみ許可**（`token_use=access` を検証）
  - `client_id` を環境変数（`COGNITO_USER_POOL_CLIENT_ID`）で検証（`aud` 検証は無効化）
- **/public /protected の互換性改善**: HTTP API v2 / 旧形式の path 取得をフォールバック対応
- **ローカル検証UIの追加（ui/）**: PKCEでログイン→トークン交換→`/protected` 呼び出しまでをブラウザのみで確認

## 詳細ドキュメント

- [Terraform詳細](./infra/README_TERRAFORM.md)
- [Cognito認証テスト詳細](./lambda/auth_cognito_test/README.md)
- [Hosted UI ローカル検証UI](./ui/README.md)
