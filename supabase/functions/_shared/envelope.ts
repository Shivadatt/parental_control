// Uniform {ok,data} / {ok,error} envelope and JSON body parsing.
import { corsHeaders } from "./cors.ts";

export type JsonObject = Record<string, unknown>;

export class ApiError extends Error {
  readonly code: string;
  readonly status: number;
  readonly details?: Record<string, unknown>;

  constructor(
    code: string,
    message: string,
    status = 400,
    details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = "ApiError";
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

export function ok(data: unknown, status = 200): Response {
  return json({ ok: true, data: data ?? {} }, status);
}

export function fail(
  code: string,
  message: string,
  status = 400,
  details?: Record<string, unknown>,
): Response {
  const error: Record<string, unknown> = { code, message };
  // Additive only: existing clients read code/message and ignore the rest.
  if (details) error.details = details;
  return json({ ok: false, error }, status);
}

/**
 * Converts thrown values into the stable error envelope. Internal errors are
 * logged as a short code only — never headers, bodies or secrets.
 */
export function errorResponse(error: unknown): Response {
  if (error instanceof ApiError) {
    return fail(error.code, error.message, error.status, error.details);
  }
  const name = error instanceof Error ? error.name : "unknown";
  console.error(`unhandled_edge_error:${name}`);
  return fail("internal_error", "The server could not complete the request.", 500);
}

export async function readJson(req: Request): Promise<JsonObject> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > 512 * 1024) {
    throw new ApiError("payload_too_large", "The request body is too large.", 413);
  }
  let text: string;
  try {
    text = await req.text();
  } catch {
    throw new ApiError("validation_error", "The request body could not be read.", 400);
  }
  if (text.length > 512 * 1024) {
    throw new ApiError("payload_too_large", "The request body is too large.", 413);
  }
  if (text.trim().length === 0) {
    throw new ApiError("validation_error", "A JSON object body is required.", 400);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new ApiError("validation_error", "The request body is not valid JSON.", 400);
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new ApiError("validation_error", "The request body must be a JSON object.", 400);
  }
  return parsed as JsonObject;
}

export function requireAction(body: JsonObject): string {
  const action = body.action;
  if (typeof action !== "string" || action.length < 1 || action.length > 64) {
    throw new ApiError("validation_error", "A valid action is required.", 400);
  }
  return action;
}

/** Maps a PostgREST/SQL error to a safe 500 unless a caller handles it first. */
export function ensureNoError(
  result: { error: { message?: string; code?: string } | null },
  message = "The database rejected the request.",
): void {
  if (result.error) {
    console.error(`db_error:${result.error.code ?? "unknown"}`);
    throw new ApiError("internal_error", message, 500);
  }
}
