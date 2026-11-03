// device-command: parent command creation, device poll and acknowledgement.
// verify_jwt=false; this function authenticates every action itself.
//
// Thin entry point (P5-TEST-01, approved testability split). All handler logic
// lives in ./handler.ts, which takes an injected `HandlerDeps`; this file only
// registers `Deno.serve` and wires the production dependencies. Importing it
// starts a server, which is exactly why tests import `handler.ts` instead.
import { handler, defaultDeps } from "./handler.ts";

Deno.serve((req: Request): Promise<Response> => handler(req, defaultDeps()));
