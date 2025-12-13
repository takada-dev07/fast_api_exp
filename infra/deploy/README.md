# Lambda関数デプロイスクリプト

このディレクトリには、Serverless Frameworkを使用してLambda関数をデプロイするためのスクリプトが含まれています。

## 概要

`deploy-function.sh`は、各Lambda関数ディレクトリ内の`serverless.yml`を使用して、Lambda関数のみをデプロイするスクリプトです。

## 前提条件

- Serverless Frameworkがインストールされていること

  ```bash
  npm install -g serverless
  ```

- AWS認証情報が設定されていること（環境変数または`~/.aws/credentials`）

## ディレクトリ構造

```
lambda/
  └── <function_directory>/
      ├── app.py
      └── serverless.yml  # 各Lambda関数ごとに配置
```

## 使用方法

### 基本的な使い方

```bash
# infra/deployディレクトリに移動
cd infra/deploy

# Lambda関数ディレクトリ名を指定してデプロイ
./deploy-function.sh <lambda_directory>
```

### 例

```bash
# hello関数をデプロイ
./deploy-function.sh hello

# 引数なしで実行した場合（エラー表示）
./deploy-function.sh
# → "エラー: ディレクトリ名を指定してください"
```

## serverless.ymlの設定

各Lambda関数ディレクトリ（例: `lambda/hello/`）に`serverless.yml`を配置します。

### 設定例

```yaml
service: hello-vpc

frameworkVersion: '3'

provider:
  name: aws
  runtime: python3.12
  region: ap-northeast-1
  stage: ${opt:stage, 'dev'}

functions:
  hello:
    name: hello-vpc  # AWS Lambda関数名を指定
    handler: app.lambda_handler
    description: Hello VPC Lambda function
    package:
      patterns:
        - '!**'
        - '*.py'
    environment:
      ENVIRONMENT: ${self:provider.stage}

package:
  patterns:
    - '!**'
    - '*.py'
```

### 重要なポイント

- **関数キー**（例: `hello`）: `sls deploy function -f hello`で使用されるキー
- **関数名**（`name`プロパティ）: 実際のAWS Lambda関数名（例: `hello-vpc`）
- **パッケージパターン**: 現在のディレクトリ内のファイルをパッケージングする設定

## スクリプトの動作

1. 引数チェック: ディレクトリ名が指定されているか確認
2. ディレクトリ存在確認: `lambda/<引数>/`ディレクトリが存在するか確認
3. serverless.yml確認: `lambda/<引数>/serverless.yml`が存在するか確認
4. 関数キー取得: `serverless.yml`から関数キーを自動取得
5. デプロイ実行: `sls deploy function -f <関数キー>`を実行

## トラブルシューティング

### Serverless Frameworkがインストールされていない

```bash
npm install -g serverless
```

### serverless.ymlが見つからない

各Lambda関数ディレクトリに`serverless.yml`を配置してください。

### ディレクトリが見つからない

`lambda/<指定したディレクトリ名>/`が存在するか確認してください。

## 注意事項

- 初回デプロイ時は、先に`sls deploy`でスタック全体をデプロイする必要がある場合があります
- 既存のLambda関数（Terraformで作成済み）にコードのみをデプロイする場合は、`sls deploy function`で問題ありません
- 関数名（`name`プロパティ）は、Terraformで作成したLambda関数名と一致させる必要があります
