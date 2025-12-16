// Fill these values from Terraform outputs.
// - cognito_hosted_ui_base_url
// - cognito_user_pool_client_id
// - api_protected_endpoint

window.APP_CONFIG = {
  // e.g. "https://<cognito-domain-prefix>.auth.ap-northeast-1.amazoncognito.com"
  cognitoBaseUrl: "",
  // e.g. "<cognito_user_pool_client_id>"
  clientId: "",
  redirectUri: "http://localhost:3000/callback.html",
  logoutRedirectUri: "http://localhost:3000/logout.html",
  // e.g. "https://xxxx.execute-api.ap-northeast-1.amazonaws.com/protected"
  apiProtectedEndpoint: "",
  scopes: ["openid", "email", "profile"],
};
