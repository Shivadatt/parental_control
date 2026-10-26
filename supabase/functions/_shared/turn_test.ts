// Pure TURN/ICE configuration tests. The shared TURN secret must never appear
// in the produced configuration.
import { buildIceConfig, readTurnEnv, type TurnEnv } from "./turn.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`ASSERTION FAILED: ${message}`);
}

function assertEqual(actual: unknown, expected: unknown, message: string): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error(`ASSERTION FAILED (${message}): expected ${e}, got ${a}`);
  }
}

const USER_ID = "33333333-3333-4333-8333-333333333333";
const NOW = new Date("2026-01-01T00:00:00.000Z");
const NOW_EPOCH = Math.floor(NOW.getTime() / 1000);

Deno.test("STUN-only fallback when TURN is not configured", async () => {
  const result = await buildIceConfig({}, USER_ID, NOW);
  assertEqual(result.turn_configured, false, "TURN disabled");
  assertEqual(result.expires_at, undefined, "no expiry without TURN");
  assertEqual(
    result.ice_servers,
    [{ urls: ["stun:stun.l.google.com:19302"] }],
    "default STUN server",
  );
  assert(
    (result.warning ?? "").includes("TURN is not configured"),
    "warning explains the fallback",
  );
});

Deno.test("custom STUN URLs are split and scheme-filtered", async () => {
  const result = await buildIceConfig(
    {
      stunUrl: "stun:stun.example.test:3478, stuns:stuns.example.test:5349, http://bad.test",
    },
    USER_ID,
    NOW,
  );
  assertEqual(
    result.ice_servers,
    [{ urls: ["stun:stun.example.test:3478", "stuns:stuns.example.test:5349"] }],
    "only STUN schemes are kept",
  );
  assertEqual(result.turn_configured, false, "TURN still disabled");
});

Deno.test("coturn REST credentials are deterministic and scoped to the user", async () => {
  const env: TurnEnv = {
    turnUrl: "turn:turn.example.test:3478?transport=udp, turns:turn.example.test:5349",
    turnSecret: "test-turn-secret",
    turnTtlSeconds: "600",
  };
  const result = await buildIceConfig(env, USER_ID, NOW);
  assertEqual(result.turn_configured, true, "TURN configured");
  assertEqual(result.ice_servers.length, 2, "STUN + TURN entries");
  assertEqual(
    result.ice_servers[0].urls,
    ["stun:stun.l.google.com:19302"],
    "default STUN remains",
  );

  const turn = result.ice_servers[1];
  assertEqual(
    turn.urls,
    [
      "turn:turn.example.test:3478?transport=udp",
      "turns:turn.example.test:5349",
    ],
    "TURN URLs split",
  );
  assertEqual(
    turn.username,
    `${NOW_EPOCH + 600}:${USER_ID}`,
    "username is expiry:userId",
  );
  const credential = turn.credential ?? "";
  assert(/^[A-Za-z0-9+/]{27}=$/.test(credential), "base64 HMAC-SHA1 credential");
  assertEqual(
    result.expires_at,
    new Date((NOW_EPOCH + 600) * 1000).toISOString(),
    "expiry timestamp",
  );
  assert(
    !JSON.stringify(result).includes("test-turn-secret"),
    "shared secret must never be returned",
  );

  const repeat = await buildIceConfig(env, USER_ID, NOW);
  assertEqual(repeat, result, "same inputs produce the same credentials");

  const otherUser = await buildIceConfig(env, "other-user", NOW);
  assert(
    otherUser.ice_servers[1].credential !== credential,
    "credentials are scoped to the user",
  );
});

Deno.test("TTL is clamped to 60..86400 seconds", async () => {
  const base: TurnEnv = {
    turnUrl: "turn:turn.example.test:3478",
    turnSecret: "s3cret",
  };
  const minimum = await buildIceConfig({ ...base, turnTtlSeconds: "1" }, USER_ID, NOW);
  assertEqual(
    minimum.ice_servers[1].username,
    `${NOW_EPOCH + 60}:${USER_ID}`,
    "TTL floor",
  );
  const maximum = await buildIceConfig(
    { ...base, turnTtlSeconds: "999999" },
    USER_ID,
    NOW,
  );
  assertEqual(
    maximum.ice_servers[1].username,
    `${NOW_EPOCH + 86400}:${USER_ID}`,
    "TTL ceiling",
  );
  const fallback = await buildIceConfig(
    { ...base, turnTtlSeconds: "not-a-number" },
    USER_ID,
    NOW,
  );
  assertEqual(
    fallback.ice_servers[1].username,
    `${NOW_EPOCH + 600}:${USER_ID}`,
    "invalid TTL uses the default",
  );
  const defaultTtl = await buildIceConfig(base, USER_ID, NOW);
  assertEqual(
    defaultTtl.ice_servers[1].username,
    `${NOW_EPOCH + 600}:${USER_ID}`,
    "absent TTL uses the default",
  );
});

Deno.test("missing secret or non-TURN URL falls back safely", async () => {
  const noSecret = await buildIceConfig(
    { turnUrl: "turn:turn.example.test:3478", turnSecret: "   " },
    USER_ID,
    NOW,
  );
  assertEqual(noSecret.turn_configured, false, "blank secret disables TURN");
  assertEqual(noSecret.ice_servers.length, 1, "STUN only");

  const badScheme = await buildIceConfig(
    { turnUrl: "http://turn.example.test", turnSecret: "s3cret" },
    USER_ID,
    NOW,
  );
  assertEqual(badScheme.turn_configured, false, "non-TURN scheme disables TURN");
  assertEqual(badScheme.ice_servers.length, 1, "STUN only");

  const blankTurn = await buildIceConfig(
    { turnUrl: "", turnSecret: "s3cret" },
    USER_ID,
    NOW,
  );
  assertEqual(blankTurn.turn_configured, false, "blank URL disables TURN");
});

Deno.test("secret whitespace is trimmed without leaking it", async () => {
  const result = await buildIceConfig(
    {
      turnUrl: "turn:turn.example.test:3478",
      turnSecret: "  padded-secret  ",
      turnTtlSeconds: "120",
    },
    USER_ID,
    NOW,
  );
  assertEqual(result.turn_configured, true, "trimmed secret works");
  assert(
    !JSON.stringify(result).includes("padded-secret"),
    "trimmed secret is not returned",
  );
});

Deno.test("readTurnEnv reads the documented variable names", () => {
  const values: Record<string, string> = {
    STUN_URL: "stun:stun.example.test:3478",
    TURN_URL: "turn:turn.example.test:3478",
    TURN_SECRET: "read-only-secret",
    TURN_TTL_SECONDS: "120",
  };
  const env = readTurnEnv((key) => values[key]);
  assertEqual(env.stunUrl, values.STUN_URL, "STUN_URL");
  assertEqual(env.turnUrl, values.TURN_URL, "TURN_URL");
  assertEqual(env.turnSecret, values.TURN_SECRET, "TURN_SECRET");
  assertEqual(env.turnTtlSeconds, values.TURN_TTL_SECONDS, "TURN_TTL_SECONDS");
});

Deno.test("invalid STUN URLs leave no ICE servers", async () => {
  const result = await buildIceConfig(
    { stunUrl: "http://not-stun.test" },
    USER_ID,
    NOW,
  );
  assertEqual(result.ice_servers, [], "scheme filtering removes bad STUN URLs");
  assertEqual(result.turn_configured, false, "TURN disabled");
});
