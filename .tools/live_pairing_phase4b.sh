#!/usr/bin/env bash
# Phase 4b: approval, legacy replay, cleanup, concurrency re-check.
set -u
cd "$(dirname "$0")/.."
set -a; source .tools/live_config.env; source .tools/qa_accounts.env; set +a
URL="$SUPABASE_URL"; KEY="$SUPABASE_ANON_KEY"
FAMILY_A="c4e15505-05f4-4faf-a268-789f454fbcd4"
FAMILY_B="4c4dd6fe-e727-4f66-bfba-7edd801114a8"
CHILD_A_ID="807da242-fda8-4a4f-aff3-c86aacb3cf9b"
CHILD_B_ID="f4c59b92-af5f-430c-b78b-0b8597684e55"
REQ_A="ada11b6e-8e8b-40cf-9f60-480c03e06a5c"
REQ_B="661cee7c-889c-41a6-8dfd-e023d03e27fe"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
jget() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const v=process.argv[1].split(".").reduce((o,k)=>o==null?o:o[k],j);process.stdout.write(typeof v==="string"?v:JSON.stringify(v))}catch(e){process.stdout.write("")}})' "$1"; }
signin() { curl -sS --max-time 30 -X POST "$URL/auth/v1/token?grant_type=password" -H "apikey: $KEY" -H "Content-Type: application/json" -d "{\"email\":\"$1\",\"password\":\"$2\"}" >"$TMP/s.json"; jget access_token <"$TMP/s.json"; }
call() { local t="$1" b="$2" c; c=$(curl -sS --max-time 30 -o "$TMP/o.json" -w "%{http_code}" -X POST "$URL/functions/v1/pairing" -H "apikey: $KEY" -H "Authorization: Bearer $t" -H "Content-Type: application/json" -d "$b"); printf '%s %s' "$c" "$(cat "$TMP/o.json")"; }
body() { node -e 'console.log(JSON.stringify(JSON.parse(process.argv[1])))' "$1"; }
sep() { printf '\n===== %s =====\n' "$1"; }

PT=$(signin "$PARENT_A_USER" "$PARENT_A_PASS")
PB=$(signin "$PARENT_B_USER" "$PARENT_B_PASS")
CA=$(signin "$CHILD_A_USER" "$CHILD_A_PASS")
CB=$(signin "$CHILD_B_USER" "$CHILD_B_PASS")
printf 'sessions: A=%s B=%s cA=%s cB=%s\n' "${PT:+ok}" "${PB:+ok}" "${CA:+ok}" "${CB:+ok}"

sep "T5 child A approves pending request $REQ_A"
echo "respond: $(call "$CA" "$(body '{"action":"respond","request_id":"'"$REQ_A"'","approve":true}')")"

sep "T5c child A membership is active now"
curl -sS --max-time 30 "$URL/rest/v1/family_members?user_id=eq.$CHILD_A_ID&select=family_id,role,status" -H "apikey: $KEY" -H "Authorization: Bearer $CA"; echo

sep "T6 unlink by parent A after a real approval"
echo "unlink: $(call "$PT" "$(body '{"action":"unlink","family_id":"'"$FAMILY_A"'","child_user_id":"'"$CHILD_A_ID"'"}')")"
curl -sS --max-time 30 "$URL/rest/v1/family_members?user_id=eq.$CHILD_A_ID&select=family_id,role,status" -H "apikey: $KEY" -H "Authorization: Bearer $CA"; echo

sep "T8b legacy replay with parent A (parent B is rate-limited): child B mints a code"
CR=$(call "$CB" '{"action":"create"}'); CST=$(printf '%s' "$CR" | cut -d' ' -f1)
CODE=$(printf '%s' "$CR" | sed 's/^[0-9]* //' | jget data.code)
printf 'create_status=%s code_length=%s\n' "$CST" "${#CODE}"
R1=$(call "$PT" "$(body '{"action":"redeem","family_id":"'"$FAMILY_A"'","code":"'"$CODE"'"}')"); echo "redeem1: $R1"
R2=$(call "$PT" "$(body '{"action":"redeem","family_id":"'"$FAMILY_A"'","code":"'"$CODE"'"}')"); echo "redeem2(replay): $R2"
REQ8=$(printf '%s' "$R1" | sed 's/^[0-9]* //' | jget data.id)
echo "cancel8: $(call "$PT" "$(body '{"action":"cancel","request_id":"'"$REQ8"'"}')")"

sep "T9b cancel leftover pending invite for child B"
echo "cancel9: $(call "$PT" "$(body '{"action":"cancel","request_id":"'"$REQ_B"'"}')")"

sep "T9c concurrency re-check: 6 parallel invites parent A -> child A (no live request)"
for i in 1 2 3 4 5 6; do ( call "$PT" '{"action":"invite","family_id":"'"$FAMILY_A"'","child_id":"PC94EAJ78H"}' >"$TMP/c$i.txt" ) & done
wait
for i in 1 2 3 4 5 6; do sed 's/^[0-9]* //' "$TMP/c$i.txt" | jget data.id; echo; done >"$TMP/ids.txt"
printf 'unique_request_ids=%s\n' "$(sed '/^$/d' "$TMP/ids.txt" | sort -u | wc -l | tr -d ' ')"
head -1 "$TMP/ids.txt" | xargs -I{} printf 'request_id=%s\n' {}
REQ_C=$(head -1 "$TMP/ids.txt")
echo "cancel-concurrent: $(call "$PT" "$(body '{"action":"cancel","request_id":"'"$REQ_C"'"}')")"

sep "T4e devices in family A for both QA children after all linking (expect none active)"
curl -sS --max-time 30 "$URL/rest/v1/devices?family_id=eq.$FAMILY_A&select=id,child_user_id,status" -H "apikey: $KEY" -H "Authorization: Bearer $PT"; echo
sep "DONE"
