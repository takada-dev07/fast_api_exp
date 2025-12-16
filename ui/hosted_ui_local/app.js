function getConfig() {
  if (!window.APP_CONFIG) throw new Error("Missing APP_CONFIG. Edit config.js first.");
  return window.APP_CONFIG;
}

function setStatus(text) {
  document.getElementById("status").textContent = text;
}

function setJson(id, value) {
  const el = document.getElementById(id);
  el.textContent = typeof value === "string" ? value : JSON.stringify(value, null, 2);
}

async function startLogin() {
  const cfg = getConfig();

  const state = randomString(16);
  const verifier = randomString(48);
  const challenge = await pkceChallengeFromVerifier(verifier);

  sessionStorage.setItem("pkce_state", state);
  sessionStorage.setItem("pkce_verifier", verifier);

  const url = new URL(cfg.cognitoBaseUrl.replace(/\/$/, "") + "/oauth2/authorize");
  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", cfg.clientId);
  url.searchParams.set("redirect_uri", cfg.redirectUri);
  url.searchParams.set("scope", (cfg.scopes || []).join(" "));
  url.searchParams.set("state", state);
  url.searchParams.set("code_challenge_method", "S256");
  url.searchParams.set("code_challenge", challenge);

  window.location.assign(url.toString());
}

async function callProtected() {
  const cfg = getConfig();
  const accessToken = sessionStorage.getItem("access_token");
  if (!accessToken) {
    setStatus("No access_token in sessionStorage. Login first.");
    return;
  }

  setStatus("Calling /protected ...");
  const resp = await fetch(cfg.apiProtectedEndpoint, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });

  const text = await resp.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }

  setJson("protectedResponse", { status: resp.status, body });
  setStatus("Done.");
}

function decodeJwtClaims(token) {
  if (!token) return null;
  const parts = token.split(".");
  if (parts.length < 2) return null;
  const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "===".slice((b64.length + 3) % 4);
  const json = atob(padded);
  return JSON.parse(json);
}

function showToken() {
  const idToken = sessionStorage.getItem("id_token") || "";
  const accessToken = sessionStorage.getItem("access_token") || "";
  setJson("idToken", idToken);
  setJson("accessToken", accessToken);
  setJson("idTokenClaims", decodeJwtClaims(idToken) || {});
}

function clearSession() {
  sessionStorage.removeItem("id_token");
  sessionStorage.removeItem("access_token");
  sessionStorage.removeItem("pkce_state");
  sessionStorage.removeItem("pkce_verifier");
  showToken();
  setJson("protectedResponse", "");
  setStatus("Cleared sessionStorage.");
}

function cognitoLogout() {
  const cfg = getConfig();
  const url = new URL(cfg.cognitoBaseUrl.replace(/\/$/, "") + "/logout");
  url.searchParams.set("client_id", cfg.clientId);
  url.searchParams.set("logout_uri", cfg.logoutRedirectUri);
  window.location.assign(url.toString());
}

window.addEventListener("DOMContentLoaded", () => {
  document.getElementById("loginBtn").addEventListener("click", () => startLogin().catch((e) => setStatus(String(e))));
  document.getElementById("callProtectedBtn").addEventListener("click", () => callProtected().catch((e) => setStatus(String(e))));
  document.getElementById("clearBtn").addEventListener("click", clearSession);
  document.getElementById("logoutBtn").addEventListener("click", cognitoLogout);

  showToken();
});
