// In-memory fake for the PostgREST surface the Edge Function handlers use.
//
// Why this exists (P5-TEST-01, docs/implementation/_work/p4-test01.md step 3):
// `_shared/auth.ts` builds a *module-memoised* service-role client from
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY, so a test could not substitute a
// client without editing that file. A handler that receives its client through
// an injected `deps.db` can instead be driven by this fake — the real
// `auth.ts`, `audit.ts`, `envelope.ts` and `error_mapping.ts` code still runs;
// only the database answer comes from memory.
//
// Design rules, all of them anti-false-green:
//   1. Unknown tables throw. A typo'd or renamed table must not quietly read as
//      "no rows" (which would look like a 404 and pass).
//   2. Unknown builder methods throw. supabase-js has ~30 methods; this
//      implements the ones handlers use, and a future handler that reaches for
//      `or()` / `match()` / `contains()` gets a loud error instead of `undefined`.
//   3. Unknown RPC names throw. `rpc()` is only answerable when the test
//      registered a handler, so an RPC rename cannot pass silently.
//   4. Column projection is honoured: `select("id, deleted_at")` returns only
//      those keys, like PostgREST. Code that accidentally reads an unprojected
//      column therefore fails here too.
//   5. `.single()` on zero or multiple rows answers the PGRST116 error, like
//      supabase-js v2.
//   6. Every executed call is recorded in `log` in execution order, with its
//      filters and patch, so "the owner assertion precedes the delete" can be
//      asserted on observed order rather than on source text.
//
// Run with:
//   deno test --allow-read supabase/functions/
// No network, no environment variables, no Supabase client.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export type Row = Record<string, unknown>;

/** Same minimal shape `_shared/error_mapping.ts` accepts. */
export interface FakePostgrestError {
  message?: string | null;
  code?: string | null;
  details?: string | null;
  hint?: string | null;
}

export type FilterOp = "eq" | "neq" | "gt" | "gte" | "lt" | "lte" | "in" | "is";

export interface FakeFilter {
  op: FilterOp;
  column: string;
  value: unknown;
}

export type FakeVerb = "select" | "insert" | "update" | "delete" | "upsert";

export interface FakeCallRecord {
  /** Position in the global execution order (across tables, rpc and auth). */
  index: number;
  kind: "from" | "rpc" | "auth";
  table: string | null;
  rpc: string | null;
  verb: FakeVerb | null;
  filters: FakeFilter[];
  order: { column: string; ascending: boolean } | null;
  limit: number | null;
  /** Row(s) written by insert/upsert, patch applied by update, or the rpc args. */
  payload: Row | Row[] | null;
  /** Requested columns; `null` when the call never asked for a projection. */
  columns: string | null;
  requestedCount: boolean;
  terminal: "maybeSingle" | "single" | null;
  /** True when the call answered with an error (injected or PGRST116). */
  failed: boolean;
  /** Rows the call affected. */
  count: number;
  /** Rows the call returned to the caller. */
  returned: Row[];
}

export interface FakeResult {
  data: unknown;
  error: FakePostgrestError | null;
  count: number | null;
}

export interface RpcContext {
  args: Record<string, unknown>;
}

export type RpcImplementation = (ctx: RpcContext) => unknown;

export type InsertHook = (row: Row) => Row;

interface FailureRule {
  table?: string;
  rpc?: string;
  verb?: FakeVerb;
  filter?: (call: FakeCallRecord) => boolean;
  error: FakePostgrestError;
  remaining: number;
}

/** `select("a, b")` → ["a","b"]; `select("*")` → null (no projection). */
function parseColumns(columns: string): string[] | null {
  const names = columns.split(",").map((name) => name.trim()).filter((name) =>
    name.length > 0
  );
  if (names.length === 0) return null;
  if (names.length === 1 && names[0] === "*") return null;
  return names;
}

function clone<T>(value: T): T {
  return value === undefined ? value : structuredClone(value);
}

function project(rows: Row[], columns: string[] | null): Row[] {
  if (!columns) return rows;
  return rows.map((row) => {
    const out: Row = {};
    for (const column of columns) {
      if (Object.hasOwn(row, column)) out[column] = clone(row[column]);
    }
    return out;
  });
}

function compareValues(left: unknown, right: unknown): number {
  if (typeof left === "number" && typeof right === "number") {
    return left === right ? 0 : left < right ? -1 : 1;
  }
  const a = String(left);
  const b = String(right);
  return a === b ? 0 : a < b ? -1 : 1;
}

function matchesFilter(row: Row, filter: FakeFilter): boolean {
  const actual = row[filter.column];
  switch (filter.op) {
    case "eq":
      return actual === filter.value;
    case "neq":
      return actual !== filter.value;
    case "is":
      // PostgREST `is` is used for null / true / false only.
      return actual === filter.value ||
        (filter.value === null && actual === undefined);
    case "in":
      return Array.isArray(filter.value) && filter.value.includes(actual);
    case "gt":
      return compareValues(actual, filter.value) > 0;
    case "gte":
      return compareValues(actual, filter.value) >= 0;
    case "lt":
      return compareValues(actual, filter.value) < 0;
    case "lte":
      return compareValues(actual, filter.value) <= 0;
    default:
      throw new Error(`FakePostgrest: unhandled filter op "${filter.op}"`);
  }
}

/**
 * A chainable, awaitable PostgREST query builder over `FakePostgrest`'s tables.
 * `FakePostgrest.from()` wraps it in a Proxy so an unimplemented method throws
 * at the call site instead of returning `undefined`.
 */
export class FakeQueryBuilder {
  verb: FakeVerb | null = null;
  payload: Row | Row[] | null = null;
  patch: Row | null = null;
  onConflict = "id";
  columns: string | null = null;
  requestedCount = false;
  readonly filters: FakeFilter[] = [];
  orderSpec: { column: string; ascending: boolean } | null = null;
  limitCount: number | null = null;
  terminal: "maybeSingle" | "single" | null = null;

  constructor(
    private readonly fake: FakePostgrest,
    private readonly table: string,
  ) {}

  select(
    columns = "*",
    options?: { count?: "exact" | "planned" | "estimated" },
  ): this {
    if (this.verb === null) this.verb = "select";
    this.columns = columns;
    if (options?.count) this.requestedCount = true;
    return this;
  }

  insert(rows: Row | Row[]): this {
    this.verb = "insert";
    this.payload = rows;
    return this;
  }

  upsert(rows: Row | Row[], options: { onConflict?: string } = {}): this {
    this.verb = "upsert";
    this.payload = rows;
    this.onConflict = options.onConflict ?? "id";
    return this;
  }

  update(patch: Row): this {
    this.verb = "update";
    this.patch = patch;
    return this;
  }

  delete(options?: { count?: "exact" | "planned" | "estimated" }): this {
    this.verb = "delete";
    if (options?.count) this.requestedCount = true;
    return this;
  }

  eq(column: string, value: unknown): this {
    return this.filter("eq", column, value);
  }

  neq(column: string, value: unknown): this {
    return this.filter("neq", column, value);
  }

  gt(column: string, value: unknown): this {
    return this.filter("gt", column, value);
  }

  gte(column: string, value: unknown): this {
    return this.filter("gte", column, value);
  }

  lt(column: string, value: unknown): this {
    return this.filter("lt", column, value);
  }

  lte(column: string, value: unknown): this {
    return this.filter("lte", column, value);
  }

  /** PostgREST `in()`. `in` is a legal property name, so the method keeps the
   * real supabase-js spelling and handler call sites stay verbatim. */
  in(column: string, values: readonly unknown[]): this {
    return this.filter("in", column, [...values]);
  }

  is(column: string, value: unknown): this {
    return this.filter("is", column, value);
  }

  order(column: string, options?: { ascending?: boolean }): this {
    this.orderSpec = { column, ascending: options?.ascending ?? true };
    return this;
  }

  limit(count: number): this {
    this.limitCount = count;
    return this;
  }

  maybeSingle(): this {
    this.terminal = "maybeSingle";
    return this;
  }

  single(): this {
    this.terminal = "single";
    return this;
  }

  /** Awaiting the builder executes it, exactly like supabase-js. */
  then(
    onFulfilled?: (value: FakeResult) => unknown,
    onRejected?: (reason: unknown) => unknown,
  ): Promise<unknown> {
    return this.fake.execute(this.table, this).then(onFulfilled, onRejected);
  }

  private filter(op: FilterOp, column: string, value: unknown): this {
    this.filters.push({ op, column, value });
    return this;
  }
}

export class FakePostgrest {
  readonly rows: Record<string, Row[]>;
  /** Every executed call (from / rpc / auth), in execution order. */
  readonly log: FakeCallRecord[] = [];
  readonly rpcHandlers: Record<string, RpcImplementation> = {};
  private readonly insertHooks: Record<string, InsertHook[]> = {};
  private readonly failures: FailureRule[] = [];
  private authUser: Row | null = null;
  private authError: FakePostgrestError | null = null;
  private nextIndex = 0;

  /** `auth.getUser` is part of the client surface `requireUser` reaches for. */
  readonly auth: {
    getUser: (
      token: string,
    ) => Promise<{ data: { user: Row | null }; error: FakePostgrestError | null }>;
  };

  constructor(initial: Record<string, Row[]> = {}) {
    this.rows = {};
    for (const [table, rows] of Object.entries(initial)) {
      this.rows[table] = rows.map(clone);
    }
    this.auth = {
      getUser: async (token: string) => {
        const record = this.begin({
          kind: "auth",
          table: null,
          rpc: null,
          verb: null,
          payload: { token },
        });
        if (this.authError) {
          record.failed = true;
          return { data: { user: null }, error: this.authError };
        }
        return { data: { user: clone(this.authUser) }, error: null };
      },
    };
  }

  /** Declares a table that starts empty (audit_logs, or a write-only table). */
  declareTable(table: string): this {
    if (!Object.hasOwn(this.rows, table)) this.rows[table] = [];
    return this;
  }

  setUser(user: Row | null): this {
    this.authUser = user;
    return this;
  }

  setUserError(error: FakePostgrestError | null): this {
    this.authError = error;
    return this;
  }

  /** Registers the answer for an RPC. Named `setRpc` because `rpc` is the
   * client method the handlers call. */
  setRpc(name: string, implementation: RpcImplementation): this {
    this.rpcHandlers[name] = implementation;
    return this;
  }

  /** Emulates a column default (trigger / `gen_random_uuid()` / `now()`). */
  onInsert(table: string, hook: InsertHook): this {
    (this.insertHooks[table] ??= []).push(hook);
    return this;
  }

  /**
   * Makes the next matching call (or the next `times` of them) answer with a
   * PostgREST error, so a 42501 / 23505 path can be driven end to end.
   */
  failOn(rule: {
    table?: string;
    rpc?: string;
    verb?: FakeVerb;
    filter?: (call: FakeCallRecord) => boolean;
    error: FakePostgrestError;
    times?: number;
  }): this {
    this.failures.push({ ...rule, remaining: rule.times ?? 1 });
    return this;
  }

  from(table: string): FakeQueryBuilder {
    if (!Object.hasOwn(this.rows, table)) {
      throw new Error(
        `FakePostgrest: table "${table}" is not declared. Seed it in the ` +
          `constructor or call declareTable("${table}") — an undeclared table ` +
          `must not read as "no rows".`,
      );
    }
    const builder = new FakeQueryBuilder(this, table);
    return new Proxy(builder, {
      get(target, prop) {
        if (typeof prop === "symbol" || Reflect.has(target, prop)) {
          const value = Reflect.get(target, prop);
          return typeof value === "function" ? value.bind(target) : value;
        }
        throw new Error(
          `FakePostgrest: builder method "${prop}" is not implemented for ` +
            `table "${table}". Implement it (and keep its semantics faithful) ` +
            `rather than letting the handler silently receive undefined.`,
        );
      },
    });
  }

  /** PostgREST RPC call, as `db.rpc(name, args)`. */
  rpc(name: string, args: Record<string, unknown>): Promise<FakeResult> {
    const record = this.begin({
      kind: "rpc",
      table: null,
      rpc: name,
      verb: null,
      payload: args,
    });
    const injected = this.takeFailure(record);
    if (injected) {
      record.failed = true;
      return Promise.resolve({ data: null, error: injected, count: null });
    }
    const implementation = this.rpcHandlers[name];
    if (!implementation) {
      throw new Error(
        `FakePostgrest: rpc "${name}" has no handler in this test. Register one ` +
          `with fake.setRpc("${name}", ...) so an RPC rename cannot pass silently.`,
      );
    }
    const raw = implementation({ args });
    const shaped = raw && typeof raw === "object" &&
        (Object.hasOwn(raw as Row, "data") || Object.hasOwn(raw as Row, "error"));
    const result: FakeResult = shaped
      ? {
        data: (raw as FakeResult).data ?? null,
        error: (raw as FakeResult).error ?? null,
        count: (raw as FakeResult).count ?? null,
      }
      : { data: clone(raw), error: null, count: null };
    record.failed = result.error !== null && result.error !== undefined;
    record.returned = Array.isArray(result.data) ? result.data as Row[] : [];
    return Promise.resolve(result);
  }

  /** Execution entry point for a query builder; called only via `then`. */
  execute(table: string, builder: FakeQueryBuilder): Promise<FakeResult> {
    const record: FakeCallRecord = this.begin({
      kind: "from",
      table,
      rpc: null,
      verb: builder.verb,
      payload: builder.payload === null ? builder.patch : clone(builder.payload),
    });
    record.filters = builder.filters.map(clone);
    record.order = builder.orderSpec ? clone(builder.orderSpec) : null;
    record.limit = builder.limitCount;
    record.columns = builder.columns;
    record.requestedCount = builder.requestedCount;
    record.terminal = builder.terminal;

    const injected = this.takeFailure(record);
    if (injected) {
      record.failed = true;
      return Promise.resolve({ data: null, error: injected, count: null });
    }
    return Promise.resolve(this.run(table, builder, record));
  }

  private takeFailure(record: FakeCallRecord): FakePostgrestError | null {
    for (const rule of this.failures) {
      if (rule.remaining <= 0) continue;
      if (rule.table !== undefined && rule.table !== record.table) continue;
      if (rule.rpc !== undefined && rule.rpc !== record.rpc) continue;
      if (rule.verb !== undefined && rule.verb !== record.verb) continue;
      if (rule.filter && !rule.filter(record)) continue;
      rule.remaining -= 1;
      return rule.error;
    }
    return null;
  }

  private run(table: string, builder: FakeQueryBuilder, record: FakeCallRecord): FakeResult {
    const verb: FakeVerb = builder.verb ?? "select";
    const columns = builder.columns === null ? null : parseColumns(builder.columns);
    let matched = this.rows[table].filter((row) =>
      builder.filters.every((filter) => matchesFilter(row, filter))
    );
    if (builder.orderSpec) {
      const { column, ascending } = builder.orderSpec;
      matched = [...matched].sort((left, right) =>
        compareValues(left[column], right[column]) * (ascending ? 1 : -1)
      );
    }
    if (builder.limitCount !== null) matched = matched.slice(0, builder.limitCount);

    let affected: Row[] = matched;
    if (verb === "insert") {
      const incoming = Array.isArray(builder.payload)
        ? builder.payload
        : [builder.payload as Row];
      affected = incoming.map((row) => {
        let next = clone(row);
        for (const hook of this.insertHooks[table] ?? []) next = hook(next);
        this.rows[table].push(next);
        return next;
      });
    } else if (verb === "update") {
      const patch = builder.patch ?? {};
      affected = matched.map((row) => {
        for (const [key, value] of Object.entries(patch)) row[key] = clone(value);
        return row;
      });
    } else if (verb === "delete") {
      affected = matched;
      const doomed = new Set(matched);
      this.rows[table] = this.rows[table].filter((row) => !doomed.has(row));
    } else if (verb === "upsert") {
      const incoming = Array.isArray(builder.payload)
        ? builder.payload
        : [builder.payload as Row];
      affected = incoming.map((row) => {
        const key = builder.onConflict;
        const existing = this.rows[table].find(
          (candidate) => candidate[key] === row[key],
        );
        if (existing) {
          Object.assign(existing, clone(row));
          return existing;
        }
        const added = clone(row);
        this.rows[table].push(added);
        return added;
      });
    }

    record.count = affected.length;
    // PostgREST only returns bodies for select, or for a write with `select`.
    const returnsRows = verb === "select" || builder.columns !== null;
    let data: unknown = returnsRows ? project(affected.map(clone), columns) : null;
    let error: FakePostgrestError | null = null;

    if (builder.terminal === "maybeSingle") {
      data = affected.length === 0
        ? null
        : project([clone(affected[0])], columns)[0];
    } else if (builder.terminal === "single") {
      if (affected.length !== 1) {
        error = {
          message: `JSON object requested, multiple (or no) rows returned (${affected.length} rows)`,
          code: "PGRST116",
          details: null,
          hint: null,
        };
        data = null;
        record.failed = true;
      } else {
        data = project([clone(affected[0])], columns)[0];
      }
    }

    record.returned = Array.isArray(data)
      ? data as Row[]
      : (data && typeof data === "object" ? [data as Row] : []);
    return {
      data,
      error,
      count: builder.requestedCount ? affected.length : null,
    };
  }

  private begin(
    partial: Pick<FakeCallRecord, "kind" | "table" | "rpc" | "verb" | "payload">,
  ): FakeCallRecord {
    const record: FakeCallRecord = {
      index: this.nextIndex++,
      kind: partial.kind,
      table: partial.table,
      rpc: partial.rpc,
      verb: partial.verb,
      filters: [],
      order: null,
      limit: null,
      payload: partial.payload ?? null,
      columns: null,
      requestedCount: false,
      terminal: null,
      failed: false,
      count: 0,
      returned: [],
    };
    this.log.push(record);
    return record;
  }

  // ---- inspection helpers used by the tests ---------------------------------

  callsFor(table: string, verb?: FakeVerb): FakeCallRecord[] {
    return this.log.filter(
      (call) => call.kind === "from" && call.table === table &&
        (verb === undefined || call.verb === verb),
    );
  }

  rowsOf(table: string): Row[] {
    return clone(this.rows[table] ?? []);
  }

  /** `event_type` of every audit row currently stored, in insertion order. */
  auditEvents(): string[] {
    return (this.rows["audit_logs"] ?? []).map((row) => String(row["event_type"]));
  }

  /** The value a call filtered a column on (first match for that op). */
  filterValue(call: FakeCallRecord, column: string, op: FilterOp = "eq"): unknown {
    return call.filters.find((filter) =>
      filter.column === column && filter.op === op
    )?.value;
  }

  /** Human-readable ordered trace, for failure messages. */
  trace(): string {
    return this.log.map((call) => {
      if (call.kind === "auth") return `${call.index} auth.getUser`;
      if (call.kind === "rpc") {
        return `${call.index} rpc ${call.rpc}${call.failed ? " ERROR" : ""}`;
      }
      const filters = call.filters
        .map((filter) => `${filter.op}(${filter.column},${JSON.stringify(filter.value)})`)
        .join(",");
      return `${call.index} ${call.table} ${call.verb ?? "select"}` +
        (filters ? ` [${filters}]` : "") +
        (call.terminal ? ` .${call.terminal}` : "") +
        (call.failed ? " ERROR" : "");
    }).join("\n");
  }

  resetLog(): void {
    this.log.length = 0;
    this.nextIndex = 0;
  }

  /** The single injection point from fake → `deps.db`. The cast lives at the
   * seam, never in production code. */
  asClient(): SupabaseClient {
    return this as unknown as SupabaseClient;
  }

  /** `() => SupabaseClient`, shaped for `HandlerDeps.db`. */
  asDb(): () => SupabaseClient {
    return () => this.asClient();
  }
}

/** Factory mirroring the constructor, for call-site readability. */
export function fakePostgrest(initial: Record<string, Row[]> = {}): FakePostgrest {
  return new FakePostgrest(initial);
}
