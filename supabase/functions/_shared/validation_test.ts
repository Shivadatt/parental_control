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
  generatePairingCode,
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
