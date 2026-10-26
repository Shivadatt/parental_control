// Audit helper. Audit failures fail the request instead of silently losing an
// accountability record.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { ApiError } from "./envelope.ts";

export interface AuditInput {
  familyId?: string | null;
  actorUserId?: string | null;
  deviceId?: string | null;
  eventType: string;
  targetType?: string | null;
  targetId?: string | null;
  metadata?: Record<string, unknown>;
}

export async function recordAudit(
  db: SupabaseClient,
  input: AuditInput,
): Promise<void> {
  const { error } = await db.from("audit_logs").insert({
    family_id: input.familyId ?? null,
    actor_user_id: input.actorUserId ?? null,
    device_id: input.deviceId ?? null,
    event_type: input.eventType,
    target_type: input.targetType ?? null,
    target_id: input.targetId ?? null,
    metadata: input.metadata ?? {},
  });
  if (error) {
    console.error(`audit_insert_failed:${error.code ?? "unknown"}`);
    throw new ApiError(
      "audit_failed",
      "The action could not be recorded in the audit log.",
      500,
    );
  }
}
