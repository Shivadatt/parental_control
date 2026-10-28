// Pure validation / crypto helpers. No network or Supabase imports so these
// can be unit-tested with `deno test` without credentials.
import { ApiError } from "./envelope.ts";

export const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const HEX64_RE = /^[0-9a-f]{64}$/;
// Android application ids: at least two dot-separated segments.
export const PACKAGE_RE = /^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/;
export const INSTALLATION_ID_RE = /^[A-Za-z0-9._:-]+$/;
// The contract uses this 30-character unambiguous subset.
export const PAIRING_ALPHABET = "23456789ABCDEFGHJKMNPQRSTVWXYZ";
export const PAIRING_CODE_LENGTH = 8;
export const PAIRING_CODE_RE = /^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$/;

// A permanent Child ID is an identifier, never a credential. The "PC" prefix
// makes it impossible to confuse with an 8-character linking code, so the
// server can route on format alone without one path becoming an oracle for the
// other.
export const CHILD_CONTACT_PREFIX = "PC";
export const CHILD_CONTACT_BODY_LENGTH = 8;
export const CHILD_CONTACT_RE = /^PC[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$/;

const encoder = new TextEncoder();

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function requireRecord(
  value: unknown,
  field: string,
): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new ApiError("validation_error", `${field} must be an object.`, 400);
  }
  return value;
}

export interface StringOptions {
  min?: number;
  max?: number;
  trim?: boolean;
  pattern?: RegExp;
  patternMessage?: string;
}

export function readString(
  value: unknown,
  field: string,
  options: StringOptions = {},
): string {
  if (typeof value !== "string") {
    throw new ApiError("validation_error", `${field} must be a string.`, 400);
  }
  let result = options.trim === false ? value : value.trim();
  const min = options.min ?? 0;
  const max = options.max ?? 2000;
  if (result.length < min || result.length > max) {
    throw new ApiError(
      "validation_error",
      `${field} must contain between ${min} and ${max} characters.`,
      400,
    );
  }
  if (options.pattern && !options.pattern.test(result)) {
    throw new ApiError(
      "validation_error",
      options.patternMessage ?? `${field} has an invalid format.`,
      400,
    );
  }
  return result;
}

export function readOptionalString(
  value: unknown,
  field: string,
  options: StringOptions = {},
): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value === "string" && value.trim().length === 0) return undefined;
  return readString(value, field, options);
}

export function readBoolean(value: unknown, field: string): boolean {
  if (typeof value !== "boolean") {
    throw new ApiError("validation_error", `${field} must be a boolean.`, 400);
  }
  return value;
}

export function readOptionalBoolean(
  value: unknown,
  field: string,
): boolean | undefined {
  if (value === undefined || value === null) return undefined;
  return readBoolean(value, field);
}

export function readInteger(
  value: unknown,
  field: string,
  min: number,
  max: number,
): number {
  if (typeof value !== "number" || !Number.isInteger(value)) {
    throw new ApiError("validation_error", `${field} must be an integer.`, 400);
  }
  if (value < min || value > max) {
    throw new ApiError(
      "validation_error",
      `${field} must be between ${min} and ${max}.`,
      400,
    );
  }
  return value;
}

export function readOptionalInteger(
  value: unknown,
  field: string,
  min: number,
  max: number,
): number | undefined {
  if (value === undefined || value === null) return undefined;
  return readInteger(value, field, min, max);
}

export function readNumber(
  value: unknown,
  field: string,
  min: number,
  max: number,
): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new ApiError("validation_error", `${field} must be a number.`, 400);
  }
  if (value < min || value > max) {
    throw new ApiError(
      "validation_error",
      `${field} must be between ${min} and ${max}.`,
      400,
    );
  }
  return value;
}

export function readUuid(value: unknown, field: string): string {
  if (typeof value !== "string" || !UUID_RE.test(value)) {
    throw new ApiError("validation_error", `${field} must be a UUID.`, 400);
  }
  return value;
}

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_RE.test(value);
}

export function isHex64(value: unknown): value is string {
  return typeof value === "string" && HEX64_RE.test(value);
}

export function readHex64(value: unknown, field: string): string {
  if (typeof value !== "string") {
    throw new ApiError("validation_error", `${field} must be a hex string.`, 400);
  }
  const normalized = value.trim().toLowerCase();
  if (!HEX64_RE.test(normalized)) {
    throw new ApiError(
      "validation_error",
      `${field} must be a 64-character SHA-256 hex digest.`,
      400,
    );
  }
  return normalized;
}

export function readEnum<T extends string>(
  value: unknown,
  field: string,
  allowed: readonly T[],
): T {
  if (typeof value !== "string" || !allowed.includes(value as T)) {
    throw new ApiError(
      "validation_error",
      `${field} must be one of: ${allowed.join(", ")}.`,
      400,
    );
  }
  return value as T;
}

export function readArray(value: unknown, field: string, max: number): unknown[] {
  if (!Array.isArray(value)) {
    throw new ApiError("validation_error", `${field} must be an array.`, 400);
  }
  if (value.length > max) {
    throw new ApiError(
      "validation_error",
      `${field} may contain at most ${max} items.`,
      400,
    );
  }
  return value;
}

export function isPackageName(value: unknown): value is string {
  return typeof value === "string" && value.length <= 150 && PACKAGE_RE.test(value);
}

export function readPackageName(value: unknown, field: string): string {
  const result = readString(value, field, { min: 1, max: 150 });
  if (!PACKAGE_RE.test(result)) {
    throw new ApiError(
      "validation_error",
      `${field} is not a valid Android package name.`,
      400,
    );
  }
  return result;
}

export function readInstallationId(value: unknown): string {
  const result = readString(value, "installation_id", { min: 8, max: 128 });
  if (!INSTALLATION_ID_RE.test(result)) {
    throw new ApiError(
      "validation_error",
      "installation_id contains unsupported characters.",
      400,
    );
  }
  return result;
}

export function normalizePairingCode(raw: string): string {
  return raw.toUpperCase().replace(/[^0-9A-Z]/g, "");
}

export function isPairingCode(value: unknown): value is string {
  return typeof value === "string" && PAIRING_CODE_RE.test(value);
}

/** True for a canonical (unformatted) Child ID such as `PCAB12CD34`. */
export function isChildContactId(value: unknown): value is string {
  return typeof value === "string" && CHILD_CONTACT_RE.test(value);
}

/** True for an 8-character linking code or a Child ID. */
export function isLinkingIdentifier(value: unknown): value is string {
  return isPairingCode(value) || isChildContactId(value);
}

/** `PCAB12CD34` → `PC-AB12CD34` for display. Canonical form is what is stored. */
export function formatChildContactId(canonical: string): string {
  return `${canonical.slice(0, CHILD_CONTACT_PREFIX.length)}-${
    canonical.slice(CHILD_CONTACT_PREFIX.length)
  }`;
}

function randomAlphabetString(length: number): string {
  const alphabetLength = PAIRING_ALPHABET.length; // 30
  const limit = Math.floor(256 / alphabetLength) * alphabetLength; // 240
  const bytes = new Uint8Array(16);
  let result = "";
  while (result.length < length) {
    crypto.getRandomValues(bytes);
    for (const byte of bytes) {
      if (byte < limit && result.length < length) {
        result += PAIRING_ALPHABET[byte % alphabetLength];
      }
    }
  }
  return result;
}

/** Cryptographically random 8-character code from the contract alphabet. */
export function generatePairingCode(): string {
  return randomAlphabetString(PAIRING_CODE_LENGTH);
}

/** Cryptographically random canonical Child ID, e.g. `PC7K4M2QRX`. */
export function generateChildContactId(): string {
  return CHILD_CONTACT_PREFIX + randomAlphabetString(CHILD_CONTACT_BODY_LENGTH);
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

// Emitted once per isolate so a missing pepper is visible without flooding logs.
let pairingHashPepperWarned = false;

/**
 * Keyed digest used for stored pairing-attempt lookups.
 *
 * The identifier space (30^8) is small enough that an unsalted SHA-256 can be
 * brute-forced from a database dump, so pairing_attempts must use an HMAC keyed
 * by a server-side secret. When no pepper is configured we fall back to the
 * legacy plain SHA-256 so the function remains deployable without the secret.
 */
export async function identifierHash(
  value: string,
  pepper?: string,
): Promise<string> {
  const key = pepper ?? Deno.env.get("PAIRING_HASH_PEPPER") ?? "";
  if (key.length === 0) {
    if (!pairingHashPepperWarned) {
      pairingHashPepperWarned = true;
      console.warn("pairing_hash_pepper_missing");
    }
    return await sha256Hex(value);
  }
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    encoder.encode(value),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function constantTimeEqual(a: string, b: string): boolean {
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  const length = Math.max(left.length, right.length);
  let diff = left.length ^ right.length;
  for (let i = 0; i < length; i += 1) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

export function constantTimeEqualHex(a: string, b: string): boolean {
  return constantTimeEqual(a.toLowerCase(), b.toLowerCase());
}

/** Compares shared secrets without leaking length through early exit. */
export async function constantTimeSecretEqual(
  provided: string,
  expected: string,
): Promise<boolean> {
  const [left, right] = await Promise.all([sha256Hex(provided), sha256Hex(expected)]);
  return constantTimeEqualHex(left, right);
}

export function readIsoDate(value: unknown, field: string): Date {
  if (typeof value !== "string" || value.length < 10 || value.length > 64) {
    throw new ApiError(
      "validation_error",
      `${field} must be an ISO-8601 timestamp.`,
      400,
    );
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new ApiError(
      "validation_error",
      `${field} must be an ISO-8601 timestamp.`,
      400,
    );
  }
  return parsed;
}

/** Validates a YYYY-MM-DD calendar date and returns it unchanged. */
export function readDateOnly(value: unknown, field: string): string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new ApiError("validation_error", `${field} must be YYYY-MM-DD.`, 400);
  }
  const [year, month, day] = value.split("-").map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (
    Number.isNaN(parsed.getTime()) ||
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    throw new ApiError("validation_error", `${field} is not a real date.`, 400);
  }
  return value;
}

export function toIso(date: Date): string {
  return date.toISOString();
}

/** Haversine distance in metres. */
export function distanceMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const earthRadius = 6371000;
  const toRad = (degrees: number) => (degrees * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * earthRadius * Math.asin(Math.min(1, Math.sqrt(a)));
}

export function dedupeStrings(values: string[]): string[] {
  return Array.from(new Set(values));
}
