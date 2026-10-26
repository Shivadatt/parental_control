// ICE server configuration. TURN uses coturn REST ephemeral credentials:
// username = "<unix-expiry>:<userId>", credential = base64(HMAC-SHA1(secret,
// username)). The shared TURN secret never leaves this function.

export interface TurnEnv {
  stunUrl?: string;
  turnUrl?: string;
  turnSecret?: string;
  turnTtlSeconds?: string | number;
}

export interface IceServerEntry {
  urls: string[];
  username?: string;
  credential?: string;
}

export interface IceConfigResult {
  ice_servers: IceServerEntry[];
  turn_configured: boolean;
  warning?: string;
  expires_at?: string;
}

const DEFAULT_STUN = "stun:stun.l.google.com:19302";
const DEFAULT_TTL_SECONDS = 600;
const MIN_TTL_SECONDS = 60;
const MAX_TTL_SECONDS = 86400;

export function readTurnEnv(
  read: (key: string) => string | undefined = (key) => Deno.env.get(key),
): TurnEnv {
  return {
    stunUrl: read("STUN_URL"),
    turnUrl: read("TURN_URL"),
    turnSecret: read("TURN_SECRET"),
    turnTtlSeconds: read("TURN_TTL_SECONDS"),
  };
}

function splitUrls(value: string | undefined): string[] {
  if (!value) return [];
  return value
    .split(/[\s,]+/)
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function clampTtl(raw: string | number | undefined): number {
  const parsed = typeof raw === "number" ? raw : Number.parseInt(String(raw ?? ""), 10);
  if (!Number.isFinite(parsed)) return DEFAULT_TTL_SECONDS;
  return Math.min(MAX_TTL_SECONDS, Math.max(MIN_TTL_SECONDS, Math.trunc(parsed)));
}

async function hmacSha1Base64(secret: string, value: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(value));
  const bytes = new Uint8Array(signature);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export async function buildIceConfig(
  env: TurnEnv,
  userId: string,
  now: Date = new Date(),
): Promise<IceConfigResult> {
  const stunUrls = splitUrls(env.stunUrl ?? DEFAULT_STUN).filter((url) =>
    /^stuns?:/i.test(url)
  );
  const iceServers: IceServerEntry[] = [];
  if (stunUrls.length > 0) {
    iceServers.push({ urls: stunUrls });
  }

  const turnUrls = splitUrls(env.turnUrl).filter((url) => /^turns?:/i.test(url));
  const secret = (env.turnSecret ?? "").trim();
  if (turnUrls.length === 0 || secret.length === 0) {
    return {
      ice_servers: iceServers,
      turn_configured: false,
      warning:
        "TURN is not configured. Audio and video may fail on restrictive networks.",
    };
  }

  const ttl = clampTtl(env.turnTtlSeconds);
  const expirySeconds = Math.floor(now.getTime() / 1000) + ttl;
  const username = `${expirySeconds}:${userId}`;
  const credential = await hmacSha1Base64(secret, username);
  iceServers.push({ urls: turnUrls, username, credential });

  return {
    ice_servers: iceServers,
    turn_configured: true,
    expires_at: new Date(expirySeconds * 1000).toISOString(),
  };
}
