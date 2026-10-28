// Pure helper tests. Run with:
//   deno test supabase/functions/_shared/validation_test.ts \
//     supabase/functions/_shared/policy_test.ts \
//     supabase/functions/_shared/turn_test.ts
import { ApiError } from "./envelope.ts";
import {
  constantTimeEqual,
  constantTimeEqualHex,
  constantTimeSecretEqual,
  dedupeStrings,
  distanceMeters,
  formatChildContactId,
  generateChildContactId,
  generatePairingCode,
  identifierHash,
  isChildContactId,
  isLinkingIdentifier,
  isPairingCode,
  isUuid,
  normalizePairingCode,
  readDateOnly,
  readHex64,
  readInstallationId,
  readPackageName,
  readString,
  sha256Hex,
} from "./validation.ts";

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

function assertApiError(fn: () => unknown, code: string, label: string): void {
  try {
    fn();
  } catch (error) {
    if (error instanceof ApiError) {
      if (error.code !== code) {
        throw new Error(
          `ASSERTION FAILED (${label}): expected code ${code}, got ${error.code}`,
        );
      }
      assert(error.status >= 400 && error.status < 500, `${label}: 4xx status`);
      return;
    }
    throw error;
  }
  throw new Error(`ASSERTION FAILED (${label}): expected ApiError ${code}`);
}

Deno.test("readString trims, bounds and type-checks", () => {
  assertEqual(readString("  hello  ", "name"), "hello", "trims by default");
  assertEqual(
    readString("  hello  ", "name", { trim: false }),
    "  hello  ",
    "trim can be disabled",
  );
  assertApiError(() => readString(1, "name"), "validation_error", "non-string");
  assertApiError(
    () => readString("ab", "name", { min: 3 }),
    "validation_error",
    "too short",
  );
  assertApiError(
    () => readString("abcd", "name", { max: 3 }),
    "validation_error",
    "too long",
  );
  assertApiError(
    () => readString("abc", "code", { pattern: /^\d+$/ }),
    "validation_error",
    "pattern mismatch",
  );
});

Deno.test("hex, uuid and package validation", () => {
  assertEqual(readHex64(` ${"A".repeat(64)} `, "h"), "a".repeat(64), "lowercases hex");
  assertApiError(() => readHex64("abc", "h"), "validation_error", "short hex");
  assertApiError(() => readHex64("g".repeat(64), "h"), "validation_error", "non-hex");
  assert(isUuid("11111111-1111-4111-8111-111111111111"), "uuid accepted");
  assert(!isUuid("not-a-uuid"), "uuid rejected");

  assertEqual(readPackageName("com.example.app", "p"), "com.example.app", "package");
  assertApiError(() => readPackageName("com", "p"), "validation_error", "no dot");
  assertApiError(() => readPackageName("1com.example", "p"), "validation_error", "digit start");

  assertEqual(readInstallationId("install-0001"), "install-0001", "installation id");
  assertApiError(() => readInstallationId("short"), "validation_error", "short install");
  assertApiError(() => readInstallationId("bad id here"), "validation_error", "space in install");
});

Deno.test("pairing codes normalise and generate within the contract alphabet", () => {
  assertEqual(normalizePairingCode(" ab-cd 2345 "), "ABCD2345", "uppercase and strip");
  assert(isPairingCode(normalizePairingCode("abcd-2345")), "normalised code is valid");
  assert(!isPairingCode("ABCD234"), "too short");
  assert(!isPairingCode("ABCD2340"), "0 not in alphabet");
  assert(!isPairingCode("ABCD234O"), "O not in alphabet");
  assert(!isPairingCode("abcd2345"), "lowercase is not accepted raw");

  for (let i = 0; i < 200; i += 1) {
    const code = generatePairingCode();
    assertEqual(code.length, 8, "generated code length");
    assert(isPairingCode(code), `generated code ${code} must match the alphabet`);
  }
});

Deno.test("generated Child IDs match the permanent identifier format", () => {
  const childIdRe = /^PC[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$/;
  for (let i = 0; i < 200; i += 1) {
    const childId = generateChildContactId();
    assert(childIdRe.test(childId), `generated Child ID ${childId} must match`);
    assertEqual(childId.length, 10, "Child ID length (PC + 8 characters)");
  }
});

Deno.test("isChildContactId accepts canonical only", () => {
  assert(isChildContactId("PC7K4M2QRX"), "canonical Child ID accepted");
  assert(isChildContactId(generateChildContactId()), "generated Child ID accepted");
  assert(!isChildContactId("PC-7K4M2QRX"), "dashed display form rejected");
  assert(!isChildContactId("pc7k4m2qrx"), "lowercase rejected");
  assert(!isChildContactId("PC12345678"), "ambiguous characters rejected");
  assert(!isChildContactId("XX7K4M2QRX"), "wrong prefix rejected");
  assert(!isChildContactId("PC7K4M2QR"), "too short rejected");
});

Deno.test("formatChildContactId inserts the display dash", () => {
  assertEqual(formatChildContactId("PC7K4M2QRX"), "PC-7K4M2QRX", "display form");
});

Deno.test("isLinkingIdentifier accepts codes and canonical Child IDs", () => {
  assert(isLinkingIdentifier("4K9M2QRT"), "8-character code accepted");
  assert(isLinkingIdentifier("PC7K4M2QRX"), "canonical Child ID accepted");
  assert(!isLinkingIdentifier("PC-7K4M2QRX"), "dashed Child ID rejected");
  assert(!isLinkingIdentifier("ABC"), "short identifier rejected");
  assert(!isLinkingIdentifier("PC12345678"), "ambiguous Child ID rejected");
});

Deno.test("generatePairingCode keeps its legacy 8-character format", () => {
  const legacyRe = /^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$/;
  const seen = new Set<string>();
  for (let i = 0; i < 100; i += 1) {
    const code = generatePairingCode();
    assertEqual(code.length, 8, "legacy code length");
    assert(legacyRe.test(code), `legacy code ${code} must match`);
    assert(isPairingCode(code), `legacy code ${code} must be accepted`);
    seen.add(code);
  }
  assert(seen.size > 90, "generated codes must vary");
});

Deno.test("two sample Child ID generations differ", () => {
  const first = generateChildContactId();
  const second = generateChildContactId();
  assert(
    first !== second,
    `expected two different Child IDs, got ${first} twice`,
  );
});

Deno.test("SHA-256 and constant-time comparisons", async () => {
  assertEqual(
    await sha256Hex("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    "known SHA-256 vector",
  );
  assert(constantTimeEqual("same", "same"), "equal strings");
  assert(!constantTimeEqual("same", "sane"), "different strings");
  assert(!constantTimeEqual("", "x"), "different lengths");
  assert(constantTimeEqualHex("ABCDEF", "abcdef"), "hex compare folds case");
  assert(!constantTimeEqualHex("abc", "abd"), "hex compare detects difference");

  assert(await constantTimeSecretEqual("secret", "secret"), "secret matches");
  assert(!(await constantTimeSecretEqual("secret", "other")), "secret mismatch");
});

Deno.test("identifierHash is a keyed HMAC that differs from plain SHA-256", async () => {
  const value = "PC7K4M2QRX";
  const digests = await Promise.all([
    identifierHash(value, "pepper-1"),
    sha256Hex(value),
  ]);
  const [keyed, plain] = digests;
  assert(keyed !== plain, "peppered digest must differ from unsalted SHA-256");
  // Pinned once from an independent implementation (OpenSSL
  // `openssl dgst -sha256 -hmac pepper-1`). If this changes, previously stored
  // pairing_attempts.code_hash values stop matching: treat it as breaking.
  assertEqual(
    keyed,
    "a059cfea2d3b2220a0f0f7a3f96396858c78c38c765f736135520bdd38c73e2d",
    "stable HMAC-SHA-256 vector for PC7K4M2QRX with pepper-1",
  );
  assertEqual(
    plain,
    "0dda31e891580e01c635ea09453553d57eeae9ed3834ad03dc6074a57ce1fa3d",
    "legacy SHA-256 for the same identifier is unchanged",
  );
});

Deno.test("identifierHash is deterministic and key/input sensitive", async () => {
  const base = await identifierHash("PC7K4M2QRX", "pepper-1");
  assertEqual(
    await identifierHash("PC7K4M2QRX", "pepper-1"),
    base,
    "same input and pepper are deterministic",
  );
  assert(
    (await identifierHash("PC7K4M2QRX", "pepper-2")) !== base,
    "a different pepper changes the digest",
  );
  assert(
    (await identifierHash("PC7K4M2QX", "pepper-1")) !== base,
    "a different identifier changes the digest",
  );
  assert(
    (await identifierHash("pc7k4m2qrx", "pepper-1")) !== base,
    "value is used as given, without case folding",
  );
});

Deno.test("identifierHash always emits 64 lowercase hex characters", async () => {
  const hex64 = /^[0-9a-f]{64}$/;
  const values = ["4K9M2QRT", "PC7K4M2QRX", "", " child-id ", "ünïcode"];
  for (const value of values) {
    const keyed = await identifierHash(value, "pepper-1");
    assert(hex64.test(keyed), `keyed digest for ${JSON.stringify(value)} is hex64`);
    assertEqual(keyed.length, 64, "keyed digest length");
  }
});

Deno.test("identifierHash falls back to sha256Hex without a pepper", async () => {
  // The warning guard is module-level, so this must be the first test in the
  // file to call identifierHash with an empty key.
  const warnings: string[] = [];
  const originalWarn = console.warn;
  console.warn = (...args: unknown[]) => {
    warnings.push(args.map((arg) => String(arg)).join(" "));
  };
  try {
    const legacy = await identifierHash("PC7K4M2QRX", "");
    assert(
      /^[0-9a-f]{64}$/.test(legacy),
      "unkeyed fallback still satisfies pairing_attempts.code_hash",
    );
    assertEqual(
      legacy,
      await sha256Hex("PC7K4M2QRX"),
      "empty pepper keeps the legacy digest",
    );
    assertEqual(
      await identifierHash("4K9M2QRT", ""),
      await sha256Hex("4K9M2QRT"),
      "fallback applies to codes as well as Child IDs",
    );
  } finally {
    console.warn = originalWarn;
  }
  assertEqual(warnings, ["pairing_hash_pepper_missing"], "warns once per isolate");
});

Deno.test("date-only validation rejects impossible dates", () => {
  assertEqual(readDateOnly("2024-02-29", "day"), "2024-02-29", "leap day");
  assertApiError(() => readDateOnly("2023-02-29", "day"), "validation_error", "non-leap");
  assertApiError(() => readDateOnly("2024-13-01", "day"), "validation_error", "month 13");
  assertApiError(() => readDateOnly("2024-1-01", "day"), "validation_error", "format");
  assertApiError(() => readDateOnly("yesterday", "day"), "validation_error", "word");
});

Deno.test("haversine distance is sane", () => {
  assertEqual(distanceMeters(51.5, -0.12, 51.5, -0.12), 0, "same point");
  const oneDegree = distanceMeters(0, 0, 0, 1);
  assert(oneDegree > 111000 && oneDegree < 111500, "one degree of longitude at equator");
  const londonToParis = distanceMeters(51.5074, -0.1278, 48.8566, 2.3522);
  assert(
    londonToParis > 340000 && londonToParis < 347000,
    "London to Paris is about 343 km",
  );
});

Deno.test("dedupeStrings preserves first-seen order", () => {
  assertEqual(dedupeStrings(["b", "a", "b", "c", "a"]), ["b", "a", "c"], "dedupe");
});
