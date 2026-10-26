// CORS helpers shared by every Edge Function.
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-device-id, x-device-secret, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

export function preflightResponse(): Response {
  return new Response("ok", { status: 200, headers: corsHeaders });
}
