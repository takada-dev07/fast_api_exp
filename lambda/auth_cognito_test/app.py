import json
import os
import urllib.request
import urllib.error
from jose import jwt
from jose.exceptions import JWTError


def get_authorizer_context(request_context: dict) -> dict:
    """
    Normalize API Gateway authorizer context across payload formats.

    - HTTP API Lambda authorizer (payload 2.0) commonly stores custom context under:
        requestContext.authorizer.lambda
    - Other formats may store it directly under:
        requestContext.authorizer
    """
    authorizer = (request_context or {}).get("authorizer", {}) or {}
    if isinstance(authorizer, dict) and isinstance(authorizer.get("lambda"), dict):
        return authorizer["lambda"]
    return authorizer


def lambda_handler(event, context):
    """
    Unified Lambda function for:
    1. Lambda Authorizer (JWT validation)
    2. Public endpoint (/public)
    3. Protected endpoint (/protected)
    """
    # Check if this is an Authorizer call
    if "methodArn" in event or "routeArn" in event:
        return handle_authorizer(event, context)

    # Check if this is a regular API Gateway request
    if "requestContext" in event:
        return handle_api_request(event, context)

    # Unknown event type
    return {
        "statusCode": 400,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"error": "Unknown event type"}),
    }


def handle_authorizer(event, context):
    """
    Lambda Authorizer for JWT token validation using Cognito
    """
    # Get Cognito User Pool ID from environment variable
    user_pool_id = os.environ.get("COGNITO_USER_POOL_ID")
    # Used to validate client_id claim for access token
    user_pool_client_id = os.environ.get("COGNITO_USER_POOL_CLIENT_ID")
    # NOTE:
    # AWS_REGION is a reserved env var key for Lambda and cannot be set via CreateFunction/UpdateFunctionConfiguration.
    # Prefer APP_AWS_REGION, but keep AWS_REGION as a fallback for other runtimes/tools.
    region = (
        os.environ.get("APP_AWS_REGION")
        or os.environ.get("AWS_REGION")
        or "ap-northeast-1"
    )

    if not user_pool_id:
        return generate_policy(
            "user", "Deny", event.get("methodArn", event.get("routeArn", "*"))
        )

    # Extract token from Authorization header
    token = None
    if "authorizationToken" in event:
        # API Gateway REST API format
        auth_header = event.get("authorizationToken", "")
    elif "headers" in event:
        # API Gateway HTTP API format
        headers = event.get("headers", {})
        auth_header = headers.get("authorization") or headers.get("Authorization", "")
    else:
        auth_header = ""

    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
    elif auth_header:
        token = auth_header

    if not token:
        return generate_policy(
            "user", "Deny", event.get("methodArn", event.get("routeArn", "*"))
        )

    try:
        # Get JWKS (JSON Web Key Set) from Cognito
        jwks_url = f"https://cognito-idp.{region}.amazonaws.com/{user_pool_id}/.well-known/jwks.json"
        jwks = get_jwks(jwks_url)

        # Decode and verify JWT token
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")

        # Find the key with matching kid
        key = None
        for jwk in jwks.get("keys", []):
            if jwk.get("kid") == kid:
                key = jwk
                break

        if not key:
            raise JWTError("Unable to find a matching key")

        # Verify and decode the token
        # NOTE:
        # For Cognito access tokens, audience verification is not reliable across setups.
        # We disable aud verification and instead validate the client_id claim.
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            issuer=f"https://cognito-idp.{region}.amazonaws.com/{user_pool_id}",
            options={"verify_aud": False},
        )

        # Ensure we only accept access tokens in this sample
        token_use = claims.get("token_use")
        if token_use != "access":
            raise JWTError(f"Invalid token_use: {token_use}")

        # Validate the token was issued for our app client
        token_client_id = claims.get("client_id")
        if user_pool_client_id and token_client_id != user_pool_client_id:
            raise JWTError("Invalid client_id")

        # Extract user information from claims
        principal_id = claims.get("sub", "user")

        # Generate IAM policy
        method_arn = event.get("methodArn", event.get("routeArn", "*"))
        policy = generate_policy(principal_id, "Allow", method_arn)

        # Add context with user information (access token has limited claims)
        policy["context"] = {
            "sub": claims.get("sub", ""),
            "client_id": claims.get("client_id", ""),
            "scope": claims.get("scope", ""),
            "username": claims.get("username", "")
            or claims.get("cognito:username", ""),
        }

        return policy

    except JWTError as e:
        print(f"JWT validation error: {str(e)}")
        return generate_policy(
            "user", "Deny", event.get("methodArn", event.get("routeArn", "*"))
        )
    except Exception as e:
        print(f"Error validating token: {str(e)}")
        return generate_policy(
            "user", "Deny", event.get("methodArn", event.get("routeArn", "*"))
        )


def handle_api_request(event, context):
    """
    Handle regular API Gateway requests
    """
    # Support both HTTP API payload format 2.0 and older/other formats
    request_context = event.get("requestContext", {}) or {}
    http_info = request_context.get("http", {}) or {}
    path = (
        http_info.get("path")
        or event.get("rawPath")
        or event.get("path")
        or request_context.get("path")
        or ""
    )

    # Route based on path
    if path == "/public" or path.endswith("/public"):
        return handle_public_endpoint(event, context)
    elif path == "/protected" or path.endswith("/protected"):
        return handle_protected_endpoint(event, context)
    else:
        return {
            "statusCode": 404,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Not found", "path": path}),
        }


def handle_public_endpoint(event, context):
    """
    Public endpoint - No authentication required
    """
    request_context = event.get("requestContext", {}) or {}
    http_info = request_context.get("http", {}) or {}
    path = (
        http_info.get("path")
        or event.get("rawPath")
        or event.get("path")
        or request_context.get("path")
        or "/public"
    )

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(
            {
                "message": "This is a public endpoint - no authentication required",
                "path": path,
            }
        ),
    }


def handle_protected_endpoint(event, context):
    """
    Protected endpoint - Authentication required
    """
    request_context = event.get("requestContext", {}) or {}
    auth_ctx = get_authorizer_context(request_context)

    # Debug: print authorizer structure when needed
    if os.environ.get("DEBUG_AUTHORIZER_CONTEXT") == "1":
        print(
            "authorizer_raw=",
            json.dumps(request_context.get("authorizer", {}), ensure_ascii=False),
        )
        print("authorizer_ctx=", json.dumps(auth_ctx, ensure_ascii=False))

    # Get user information from authorizer context
    user_sub = auth_ctx.get("sub", "unknown")
    client_id = auth_ctx.get("client_id", "")
    scope = auth_ctx.get("scope", "")
    username = auth_ctx.get("username", "")
    http_info = request_context.get("http", {}) or {}
    path = (
        http_info.get("path")
        or event.get("rawPath")
        or event.get("path")
        or request_context.get("path")
        or "/protected"
    )

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(
            {
                "message": "This is a protected endpoint - authentication successful",
                "user": {
                    "sub": user_sub,
                    "username": username,
                    "client_id": client_id,
                    "scope": scope,
                },
                "path": path,
            }
        ),
    }


def get_jwks(jwks_url):
    """
    Fetch JWKS from Cognito
    """
    try:
        with urllib.request.urlopen(jwks_url) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as e:
        print(f"Error fetching JWKS: {str(e)}")
        raise


def generate_policy(principal_id, effect, resource):
    """
    Generate IAM policy for API Gateway
    """
    policy = {
        "principalId": principal_id,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {"Action": "execute-api:Invoke", "Effect": effect, "Resource": resource}
            ],
        },
    }
    return policy
