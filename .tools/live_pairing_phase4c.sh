#!/usr/bin/env bash
# Phase 4c: cross-parent replay of a legacy code; replay must not create a second request.
set -u
cd "$(dirname "$0")/.."
set -a; source .tools/live_config.env; source .tools/qa_accounts.env; set +a
URL="$SUPABASE_URL"; KEY="$SUPABASE_ANON_KEY"
FAMILY_A="c4e15505-05f4-4faf-a268-789f454fbcd4"
FAMILY_B="4c4dd6fe-e727-4f66-bfba-7edd801114a8"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
jget() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const v=process.argv[1].split(".").reduce((o,k)=>o==null?o:o[k],j);process.stdout.write(typeof v==="string"?v:JSON.stringify(v))}catch(e){process.stdout.write("")}})' "$1"; }
signin() { curl -sS --max-time 30 -X POST "$URL/auth/v1/token?grant_type=password" -H "apikey: $KEY" -H "Content-Type: application/json" -d "{\"email\":\"$1\",\"password\":\"$2\"}" >"$TMP/s.json"; jget access_token <"$TMP/s.json"; }
call() { local t="$1" b="$2" c; c=$(curl -sS --max-time 30 -o "$TMP/o.json" -w "%{http_code}" -X POST "$URL/functions/v1/pairing" -H "apikey: $KEY" -H "Authorization: Bearer $t" -H "Content-Type: application/json" -d "$b"); printf '%s %s' "$c" "$(cat "$TMP/o.json")"; }
body() { node -e 'console.log(JSON.stringify(JSON.parse(process.argv[1])))' "$1"; }
sep() { printf '\n===== %s =====\n' "$1"; }

PT=$(signin "$PARENT_A_USER" "$PARENT_A_PASS")
PB=$(signin "$PARENT_B_USER" "$PARENT_B_PASS")
CB=$(signin "$CHILD_B_USER" "$CHILD_B_PASS")
printf 'sessions: A=%s B=%s cB=%s lengths=%s/%s/%s\n' "${PT:+ok}" "${PB:+ok}" "${CB:+ok}" "${#PT}" "${#PB}" "${#CB}"
printf 'jget-self-test=%s | file-bytes=%s | jget-file=%s\n' "$(printf '{"access_token":"X"}' | jget access_token)" "$(wc -c <"$TMP/s.json" | tr -d ' ')" "$(jget access_token <"$TMP/s.json" | wc -c | tr -d ' ')"

sep "child B mints a legacy code (child B is unlinked)"
CR=$(call "$CB" '{"action":"create"}'); CST=$(printf '%s' "$CR" | cut -d' ' -f1)
CODE=$(printf '%s' "$CR" | sed 's/^[0-9]* //' | jget data.code)
printf 'create_status=%s code_length=%s\n' "$CST" "${#CODE}"

sep "parent A redeems it into family A (first use)"
R1=$(call "$PT" "$(body '{"action":"redeem","family_id":"'"$FAMILY_A"'","code":"'"$CODE"'"}')")
echo "redeem_A: $R1"
REQ=$(printf '%s' "$R1" | sed 's/^[0-9]* //' | jget data.id)

sep "parent B replays the SAME code (replay must be rejected, no second request)"
R2=$(call "$PB" "$(body '{"action":"redeem","family_id":"'"$FAMILY_B"'","code":"'"$CODE"'"}')")
echo "redeem_B_replay: $R2"

sep "parent A replays the SAME code again (same parent/family)"
R3=$(call "$PT" "$(body '{"action":"redeem","family_id":"'"$FAMILY_A"'","code":"'"$CODE"'"}')")
echo "redeem_A_replay: $R3"

sep "cleanup: cancel request opened by parent A"
if [ -n "${REQ:-}" ]; then echo "cancel: $(call "$PT" "$(body '{"action":"cancel","request_id":"'"$REQ"'"}')")"; else echo "no request id"; fi
sep "DONE"
