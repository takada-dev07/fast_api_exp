# Hello World API - Terraform Infrastructure

このプロジェクトは、AWS API Gateway (HTTP API) と Lambda (Python) を使用して Hello World API を構築する Terraform コードです。

## 構成

- **リージョン**: ap-northeast-1 (東京)
- **API Gateway**: HTTP API
- **Lambda**: Python 3.12
- **VPC 接続**: オプション（デフォルト: 無効、コスト最適化のため）

## 前提条件

- Terraform >= 1.0 がインストールされていること
- AWS CLI がインストール・設定されていること
- IAM Identity Center (SSO) を使用して AWS にアクセスできること

## ファイル構成

```
.
├── infra/
│   ├── main.tf              # メインリソース定義
│   ├── variables.tf         # 変数定義
│   ├── outputs.tf          # 出力定義
│   ├── providers.tf        # Provider 設定
│   ├── versions.tf         # Terraform バージョン制約
│   └── README_TERRAFORM.md # このファイル
└── lambda/
    └── hello/
        └── app.py          # Lambda 関数コード
```

## 実行手順

### 1. AWS SSO ログイン

IAM Identity Center (SSO) を使用して AWS にログインします。

```bash
# SSO プロファイルでログイン
aws sso login --profile <PROFILE>

# プロファイルを環境変数に設定
export AWS_PROFILE=<PROFILE>
```

### 2. Terraform の初期化

```bash
cd infra
terraform init
```

### 3. 実行計画の確認

```bash
terraform plan
```

### 4. リソースの作成

```bash
terraform apply
```

確認プロンプトで `yes` を入力すると、リソースが作成されます。

### 5. API のテスト

作成が完了すると、Invoke URL が出力されます。以下のコマンドで API をテストできます。

```bash
# Invoke URL を取得（terraform apply の出力から）
curl $(terraform output -raw api_gateway_invoke_url)
```

または、直接 URL を指定：

```bash
curl https://<api-id>.execute-api.ap-northeast-1.amazonaws.com/hello
```

期待されるレスポンス：

```json
{"message": "Hello from Lambda!"}
```

### 6. リソースの削除

```bash
terraform destroy
```

確認プロンプトで `yes` を入力すると、すべてのリソースが削除されます。

## VPC 接続について

### デフォルト動作（VPC なし）

デフォルトでは、Lambda は VPC に接続されていません。これにより：

- ✅ **コストが最小限**: NAT Gateway や VPC Endpoint が不要
- ✅ **低レイテンシ**: VPC 内のネットワークオーバーヘッドなし
- ✅ **外部アクセス可能**: Lambda からインターネットへのアクセスが可能

### VPC 接続を有効にする場合

VPC 接続を有効にするには、`terraform apply` 時に変数を指定します：

```bash
terraform apply -var="enable_vpc=true"
```

または、`terraform.tfvars` ファイルを作成：

```hcl
enable_vpc = true
```

#### VPC 接続時の注意事項

⚠️ **重要な制約**: この構成では NAT Gateway を作成していません（コスト最適化のため）。そのため：

- ❌ **外部インターネットアクセス不可**: VPC 内の Lambda から外部 API やインターネットリソースへのアクセスができません
- ✅ **VPC 内リソースへのアクセス可能**: RDS、ElastiCache などの VPC 内リソースにはアクセス可能です
- 💡 **外部アクセスが必要な場合**: NAT Gateway または VPC Endpoint（PrivateLink）を追加する必要があります（追加コストが発生します）

#### VPC 構成

VPC 接続を有効にすると、以下のリソースが作成されます：

- VPC (CIDR: 10.0.0.0/16)
- Private Subnet 1 (ap-northeast-1a, CIDR: 10.0.1.0/24)
- Private Subnet 2 (ap-northeast-1c, CIDR: 10.0.2.0/24)
- Security Group (Lambda 用、全egress許可)

## 作成されるリソース

### 必須リソース

- Lambda 関数 (`hello-vpc`)
- API Gateway HTTP API (`hello-vpc-api`)
- Lambda 実行用 IAM ロール・ポリシー
- CloudWatch Logs ロググループ（保持期間: 7日）
- Lambda 権限（API Gateway からの Invoke 許可）

### オプションリソース（`enable_vpc=true` 時）

- VPC
- Private Subnet × 2
- Security Group
- VPC アクセス用 IAM ポリシー

## コスト最適化

この構成は以下の点でコストを最小化しています：

- NAT Gateway なし（VPC 接続時も）
- VPC Endpoint なし
- 最小限のリソース構成
- CloudWatch Logs 保持期間: 7日

## トラブルシューティング

### Lambda がタイムアウトする

- VPC 接続を有効にしている場合、外部アクセスができないためタイムアウトする可能性があります
- デフォルト（VPC なし）に戻すか、NAT Gateway を追加してください

### API Gateway から 403 エラー

- Lambda の権限設定を確認してください
- `aws_lambda_permission` リソースが正しく作成されているか確認

### CloudWatch Logs が見つからない

- Lambda 関数名とロググループ名が一致しているか確認
- IAM ロールに CloudWatch Logs の権限があるか確認

## 参考情報

- [AWS Lambda ドキュメント](https://docs.aws.amazon.com/lambda/)
- [API Gateway HTTP API ドキュメント](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
- [Terraform AWS Provider ドキュメント](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
