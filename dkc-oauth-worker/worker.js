// --- JWT Helpers ---
function bufferToBase64Url(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlToBuffer(b64url) {
  const b64 = b64url.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(b64.padEnd(b64.length + (4 - (b64.length % 4)) % 4, '='));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function encodeUtf8(str) { return new TextEncoder().encode(str).buffer; }
function decodeUtf8(buffer) { return new TextDecoder().decode(buffer); }

async function signJwt(payload, secret) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const data = bufferToBase64Url(encodeUtf8(JSON.stringify(header))) + '.' + bufferToBase64Url(encodeUtf8(JSON.stringify(payload)));
  const key = await crypto.subtle.importKey('raw', encodeUtf8(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign('HMAC', key, encodeUtf8(data));
  return data + '.' + bufferToBase64Url(signature);
}

async function verifyJwt(token, secret) {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const data = parts[0] + '.' + parts[1];
  const key = await crypto.subtle.importKey('raw', encodeUtf8(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
  const isValid = await crypto.subtle.verify('HMAC', key, base64UrlToBuffer(parts[2]), encodeUtf8(data));
  if (!isValid) return null;
  const payload = JSON.parse(decodeUtf8(base64UrlToBuffer(parts[1])));
  if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) return null;
  return payload;
}

// --- Cookie Helpers ---
function getCookie(request, name) {
  const cookieString = request.headers.get('Cookie');
  if (!cookieString) return null;
  const match = cookieString.match(new RegExp('(^|; )' + name + '=([^;]+)'));
  return match ? match[2] : null;
}

function serializeCookie(name, value, maxAge) {
  return \`\${name}=\${value}; HttpOnly; Secure; Path=/; Max-Age=\${maxAge}; SameSite=Lax\`;
}

// --- UI Template ---
const renderHtml = (content) => \`<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>DKC OAuth Login</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Sarabun:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --clr-primary:       #4a90b8; 
      --clr-primary-dark:  #2e6f96; 
      --clr-primary-pale:  #eef6fb; 
      --clr-accent:        #c9a84c; 
      --clr-white:   #ffffff;
      --clr-bg:      #f5f8fc; 
      --clr-surface: #ffffff; 
      --clr-border:  #dde8f2;
      --clr-text:       #1e2c3a;
      --clr-text-muted: #5a7186;
      --clr-text-light: #8dafc7; 
      --clr-success: #1f8c5b;
      --clr-warning: #d97706;
      --clr-danger:  #c0392b;
      --radius-sm: 4px;
      --radius-md: 8px;   
      --radius-lg: 14px;  
      --shadow-sm: 0 1px 3px rgba(26,111,168,.08), 0 1px 2px rgba(0,0,0,.04);
      --shadow-md: 0 4px 16px rgba(26,111,168,.10), 0 2px 6px rgba(0,0,0,.04);
      --shadow-lg: 0 10px 40px rgba(26,111,168,.14);
      --font-th: 'Sarabun', sans-serif;
      --font-en: 'Sarabun', sans-serif; 
    }
    * { box-sizing: border-box; }
    html { font-size: 100%; } 
    body { 
      font-family: var(--font-th);
      background-color: var(--clr-bg);
      color: var(--clr-text);
      line-height: 1.65; 
      margin: 0;
      padding: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      min-height: 100vh;
    }
    @media (prefers-reduced-motion: reduce) {
      * { animation: none !important; transition: none !important; scroll-behavior: auto !important; }
    }
    h1, h2 { color: var(--clr-primary-dark); margin-top: 0; }
    h1 { font-size: 1.55rem; font-weight: 600; line-height: 1.3; }
    h2 { font-size: 1.3rem; font-weight: 600; line-height: 1.4; }
    @media (max-width: 768px) {
      h1 { font-size: 1.2rem; }
      input, select, textarea { font-size: 16px; }
      .container { padding: 20px 16px 40px; }
    }
    .container {
      max-width: 1280px;
      width: 100%;
      margin-inline: auto;
      padding: 32px 24px 48px;
    }
    .card {
      background: var(--clr-surface);
      border-radius: var(--radius-lg);
      box-shadow: var(--shadow-sm);
      padding: 24px;
      max-width: 500px;
      margin: 40px auto;
      transition: transform .2s, box-shadow .2s;
    }
    .card:hover {
      transform: translateY(-2px);
      box-shadow: var(--shadow-md);
    }
    .btn {
      display: inline-block;
      background-color: var(--clr-primary);
      color: var(--clr-white);
      text-decoration: none;
      padding: 8px 16px;
      border-radius: var(--radius-md);
      font-weight: 500;
      transition: background-color .15s;
      border: none;
      cursor: pointer;
    }
    .btn:hover { background-color: var(--clr-primary-dark); }
    .btn:focus-visible {
      outline: none;
      border-color: var(--clr-primary);
      box-shadow: 0 0 0 3px rgba(26,111,168,.12);
    }
    .btn-danger {
      background-color: transparent;
      color: var(--clr-danger);
      border: 1px solid rgba(255,0,0,.6);
    }
    .btn-danger:hover {
      background-color: rgba(220,80,80,.40);
      color: #fff;
    }
    .profile-info {
      background: var(--clr-primary-pale);
      padding: 16px;
      border-radius: var(--radius-md);
      margin-bottom: 24px;
    }
    .error-msg {
      background: #fef2f2;
      color: var(--clr-danger);
      padding: 12px;
      border-radius: var(--radius-md);
      margin-bottom: 16px;
    }
  </style>
</head>
<body>
  <div class="container">
    \${content}
  </div>
</body>
</html>\`;

// --- Worker Request Handler ---
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const OAUTH_BASE_URI = env.OAUTH_BASE_URI || "https://oauth.dhammakaya.network";
    const JWT_SECRET = env.JWT_SECRET || "fallback-secret-for-dev";

    // 1. Home / Profile
    if (url.pathname === '/') {
      const error = url.searchParams.get('error');
      const token = getCookie(request, 'session');
      const user = token ? await verifyJwt(token, JWT_SECRET) : null;
      
      let content = '';
      if (error) {
        content += \`<div class="error-msg">Error: \${error}</div>\`;
      }
      
      if (user) {
        content += \`
          <div class="card">
            <h1>ยินดีต้อนรับ, \${user.display_name}</h1>
            <div class="profile-info">
              <p><strong>Username:</strong> \${user.username}</p>
              <p><strong>หน่วยงาน:</strong> \${user.offices && user.offices.length > 0 ? \`\${user.offices[0].position} \${user.offices[0].kong}\` : 'ไม่มีข้อมูล'}</p>
            </div>
            <a href="/logout" class="btn btn-danger">ออกจากระบบ</a>
          </div>
        \`;
      } else {
        content += \`
          <div class="card" style="text-align: center;">
            <h1>ระบบล็อกอิน</h1>
            <p style="color: var(--clr-text-muted); margin-bottom: 24px;">กรุณาเข้าสู่ระบบด้วยบัญชีองค์กรของคุณ</p>
            <a href="/login" class="btn">เข้าสู่ระบบ (DKC OAuth)</a>
          </div>
        \`;
      }
      
      return new Response(renderHtml(content), {
        headers: { 'Content-Type': 'text/html; charset=utf-8' }
      });
    }

    // 2. Login Redirect
    if (url.pathname === '/login') {
      const state = crypto.randomUUID();
      const params = new URLSearchParams({
        client_id: env.OAUTH_CLIENT_ID,
        redirect_uri: env.OAUTH_REDIRECT_URI,
        response_type: 'code',
        state: state
      });
      
      return new Response(null, {
        status: 302,
        headers: {
          'Location': \`\${OAUTH_BASE_URI}/oauth/authorize?\${params.toString()}\`,
          'Set-Cookie': serializeCookie('oauth_state', state, 300)
        }
      });
    }

    // 3. Callback
    if (url.pathname === '/callback') {
      const code = url.searchParams.get('code');
      const state = url.searchParams.get('state');
      const error = url.searchParams.get('error');
      
      if (error) return Response.redirect(\`\${url.origin}/?error=\` + encodeURIComponent('User declined or error occurred'), 302);
      
      const expectedState = getCookie(request, 'oauth_state');
      // Create headers to clear the state cookie
      const headers = new Headers();
      headers.append('Set-Cookie', serializeCookie('oauth_state', '', 0));

      if (!expectedState || state !== expectedState) {
        headers.set('Location', \`\${url.origin}/?error=\` + encodeURIComponent('Invalid state parameter'));
        return new Response(null, { status: 302, headers });
      }
      
      // Token exchange
      const tokenRes = await fetch(\`\${OAUTH_BASE_URI}/oauth/token\`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json'
        },
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          client_id: env.OAUTH_CLIENT_ID,
          client_secret: env.OAUTH_CLIENT_SECRET,
          redirect_uri: env.OAUTH_REDIRECT_URI,
          code: code
        })
      });
      
      if (!tokenRes.ok) {
        headers.set('Location', \`\${url.origin}/?error=\` + encodeURIComponent('Failed to exchange token'));
        return new Response(null, { status: 302, headers });
      }
      
      const tokenData = await tokenRes.json();
      
      // Fetch Profile
      const profileRes = await fetch(\`\${OAUTH_BASE_URI}/api/user\`, {
        headers: {
          'Authorization': \`Bearer \${tokenData.access_token}\`,
          'Accept': 'application/json'
        }
      });
      
      if (!profileRes.ok) {
        headers.set('Location', \`\${url.origin}/?error=\` + encodeURIComponent('Failed to fetch profile'));
        return new Response(null, { status: 302, headers });
      }
      
      const profile = await profileRes.json();
      
      // Create JWT Session
      const sessionToken = await signJwt({
        id: profile.id,
        username: profile.username,
        display_name: profile.display_name,
        offices: profile.offices,
        exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24)
      }, JWT_SECRET);
      
      headers.append('Set-Cookie', serializeCookie('session', sessionToken, 60 * 60 * 24));
      headers.set('Location', \`\${url.origin}/\`);
      return new Response(null, { status: 302, headers });
    }

    // 4. Logout
    if (url.pathname === '/logout') {
      const redirectUrl = encodeURIComponent(\`\${url.origin}/\`);
      return new Response(null, {
        status: 302,
        headers: {
          'Location': \`\${OAUTH_BASE_URI}/logout?redirect_url=\${redirectUrl}\`,
          'Set-Cookie': serializeCookie('session', '', 0)
        }
      });
    }

    return new Response('Not Found', { status: 404 });
  }
};
