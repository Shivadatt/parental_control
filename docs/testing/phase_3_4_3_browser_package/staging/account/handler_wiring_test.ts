import { assert } from "jsr:@std/assert";

Deno.test("staged account: delete and retention actions use the extracted modules", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));

  assert(
    source.includes('from "./validation.ts";'),
    "the handler must import the account validation module",
  );
  assert(
    source.includes('from "./retention.ts";'),
    "the handler must import the retention module",
  );
  assert(
    source.includes('from "./deletion.ts";'),
    "the handler must import the deletion module",
  );
  assert(
    source.includes('from "./shared-auth.ts";'),
    "the handler must import the shared auth module",
  );
  assert(
    source.includes('from "./shared-cors.ts";'),
    "the handler must import the shared cors module",
  );
  assert(
    source.includes('from "./shared-envelope.ts";'),
    "the handler must import the shared envelope module",
  );
  assert(
    source.includes('from "./shared-audit.ts";'),
    "the handler must import the shared audit module",
  );
  assert(
    source.includes("const failure = validateDeleteAccountInput({"),
    "delete_account must validate confirm/email strictly",
  );
});
