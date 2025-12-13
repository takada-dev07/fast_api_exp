#!/bin/bash

# Lambda関数デプロイスクリプト
# 使用方法: ./deploy-function.sh <lambda_directory>
# 例: ./deploy-function.sh hello
# 例: ./deploy-function.sh hello-vpc

set -e

# 引数チェック
if [ $# -eq 0 ]; then
    echo "エラー: ディレクトリ名を指定してください"
    echo "使用方法: ./deploy-function.sh <lambda_directory>"
    echo "例: ./deploy-function.sh hello"
    exit 1
fi

# Lambda関数のディレクトリ名を取得
LAMBDA_DIR=$1

# スクリプトのディレクトリを取得（infra/deploy）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# プロジェクトルートを取得（infra/deploy から ../../ でルートへ）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Lambda関数のディレクトリパス
LAMBDA_PATH="$PROJECT_ROOT/lambda/$LAMBDA_DIR"

# ディレクトリの存在確認
if [ ! -d "$LAMBDA_PATH" ]; then
    echo "エラー: ディレクトリが見つかりません: lambda/$LAMBDA_DIR"
    exit 1
fi

echo "=========================================="
echo "Lambda関数デプロイを開始します"
echo "ディレクトリ: lambda/$LAMBDA_DIR"
echo "=========================================="

# serverless.ymlの存在確認
if [ ! -f "$LAMBDA_PATH/serverless.yml" ]; then
    echo "エラー: serverless.yml が見つかりません: lambda/$LAMBDA_DIR/serverless.yml"
    exit 1
fi

# Lambda関数のディレクトリに移動
cd "$LAMBDA_PATH"

# Serverless Frameworkがインストールされているか確認
if ! command -v sls &> /dev/null; then
    echo "エラー: Serverless Framework (sls) がインストールされていません"
    echo "インストール方法: npm install -g serverless"
    exit 1
fi

# serverless.ymlから関数名を取得（functionsセクションの最初のキーを取得）
FUNCTION_KEY=$(grep -A 1 "^functions:" serverless.yml | grep -v "^functions:" | head -1 | sed 's/^[[:space:]]*\([^:]*\):.*/\1/' | tr -d ' ')

if [ -z "$FUNCTION_KEY" ]; then
    echo "エラー: serverless.yml から関数名を取得できませんでした"
    exit 1
fi

echo "関数キー: $FUNCTION_KEY"

# AWS CLIの存在確認
if ! command -v aws &> /dev/null; then
    echo "エラー: AWS CLI (aws) がインストールされていません"
    exit 1
fi

# AWSプロファイルの決定（未指定なら、SSO用profileがあればそれを優先）
EFFECTIVE_AWS_PROFILE="${AWS_PROFILE:-}"
if [ -z "$EFFECTIVE_AWS_PROFILE" ]; then
    if aws configure list-profiles 2>/dev/null | tr -d '\r' | grep -qx "takada_test"; then
        EFFECTIVE_AWS_PROFILE="takada_test"
    else
        EFFECTIVE_AWS_PROFILE="default"
    fi
fi

# SSOプロファイルかどうかを表示
SSO_SESSION=$(aws configure get sso_session --profile "$EFFECTIVE_AWS_PROFILE" 2>/dev/null || true)
if [ -n "$SSO_SESSION" ]; then
    echo "AWSプロファイル: $EFFECTIVE_AWS_PROFILE (SSO)"
else
    echo "AWSプロファイル: $EFFECTIVE_AWS_PROFILE"
fi

# AWS認証情報の確認（失敗時はSSOログインを促す）
if ! aws sts get-caller-identity --profile "$EFFECTIVE_AWS_PROFILE" &>/dev/null; then
    echo "エラー: AWS認証情報が取得できません。"
    echo "以下を実行してから再実行してください:"
    echo "  aws sso login --profile $EFFECTIVE_AWS_PROFILE"
    echo "  (ブラウザを自動で開かせたくない場合は --no-browser も使えます)"
    exit 1
fi

# Serverless側のprofile解釈差異を回避するため、AWS CLIでSSOの一時クレデンシャルを環境変数に展開
# これにより Serverless(AWS SDK) は環境変数認証で動作します
if ! eval "$(aws configure export-credentials --profile "$EFFECTIVE_AWS_PROFILE" --format env 2>/dev/null)"; then
    echo "エラー: 一時クレデンシャルのエクスポートに失敗しました。"
    echo "以下を確認してください:"
    echo "  aws sso login --profile $EFFECTIVE_AWS_PROFILE"
    exit 1
fi

# Serverless(AWS SDK) が AWS_PROFILE を優先して「未設定」扱いするケースを回避するため、
# ここから先は環境変数クレデンシャルを強制する
unset AWS_PROFILE
unset AWS_DEFAULT_PROFILE
export AWS_SDK_LOAD_CONFIG=0

# 念のためリージョンも環境変数に固定（未設定時のみ）
if [ -z "${AWS_REGION:-}" ]; then
    export AWS_REGION="$(aws configure get region --profile "$EFFECTIVE_AWS_PROFILE" 2>/dev/null || true)"
fi
if [ -n "${AWS_REGION:-}" ] && [ -z "${AWS_DEFAULT_REGION:-}" ]; then
    export AWS_DEFAULT_REGION="$AWS_REGION"
fi

echo "デプロイを実行中..."

# Lambda関数をデプロイ
sls deploy function -f "$FUNCTION_KEY"

if [ $? -eq 0 ]; then
    echo "=========================================="
    echo "デプロイが正常に完了しました"
    echo "ディレクトリ: lambda/$LAMBDA_DIR"
    echo "関数キー: $FUNCTION_KEY"
    echo "=========================================="
else
    echo "=========================================="
    echo "デプロイ中にエラーが発生しました"
    echo "=========================================="
    exit 1
fi
