#!/usr/bin/env bash
# Phase 4 live security tests against parent-control-prod.
# Prints HTTP status + response body only; never prints tokens or keys.
set -u

cd "$(dirname "$0")/.."
set -a
source .tools/live_config.env
source .tools/qa_accounts.env
set +a

URL="$SUPABASE_URL"
KEY="$SUPABASE_ANON_KEY"
FAMILY_A="c4e15505-05f4-4faf-a268-789f454fbcd4"
FAMILY_B="4c4dd6fe-e727-4f66-bfba-7edd801114a8"
CHILD_A_ID="807da242-fda8-4a4f-aff3-c86aacb3cf9b"
CHILD_B_ID="f4c59b92-af5f-430c-b78b-0b8597684e55"
CHILD_C_ID="2ef6c7b9-c4f9-46d4-be88-d78ac5cb0764"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

jget() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const v=process.argv[1].split(".").reduce((o,k)=>o==null?o:o[k],j);process.stdout.write(typeof v==="string"?v:JSON.stringify(v))}catch(e){process.stdout.write("")}})' "$1"; }

signin() {
  curl -sS --max-time 30 -X POST "$URL/auth/v1/token?grant_type=password" \
    -H "apikey: $KEY" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" >"$TMP/signin.json"
  jget access_token <"$TMP/signin.json"
}

call() { # token body -> "STATUS BODY"
  local token="$1" body="$2" code
  code=$(curl -sS --max-time 30 -o "$TMP/out.json" -w "%{http_code}" \
    -X POST "$URL/functions/v1/pairing" \
    -H "apikey: $KEY" -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" -d "$body")
  printf '%s %s' "$code" "$(cat "$TMP/out.json")"
}

sep() { printf '\n===== %s =====\n' "$1"; }

PT=$(signin "$PARENT_A_USER" "$PARENT_A_PASS")
PB=$(signin "$PARENT_B_USER" "$PARENT_B_PASS")
CA=$(signin "$CHILD_A_USER" "$CHILD_A_PASS")
CB=$(signin "$CHILD_B_USER" "$CHILD_B_PASS")
CC=$(signin "$CHILD_C_USER" "$CHILD_C_PASS")
printf 'sessions: parentA=%s parentB=%s childA=%s childB=%s childC=%s\n' \
  "${PT:+ok}" "${PB:+ok}" "${CA:+ok}" "${CB:+ok}" "${CC:+ok}"

sep "T1 existing child A get_contact_id (first call)"
R1=$(call "$CA" '{"action":"get_contact_id"}'); echo "$R1"
CID_A=$(printf '%s' "$R1" | sed 's/^[0-9]* //' | jget data.contact_id)
sep "T1 existing child A get_contact_id (second call, must equal first)"
R2=$(call "$CA" '{"action":"get_contact_id"}'); echo "$R2"
CID_A2=$(printf '%s' "$R2" | sed 's/^[0-9]* //' | jget data.contact_id)
printf 'stable=%s first=%s second=%s\n' "$([ "$CID_A" = "$CID_A2" ] && echo YES || echo NO)" "$CID_A" "$CID_A2"

sep "T1b child B get_contact_id (new row, no duplicate profile)"
RB=$(call "$CB" '{"action":"get_contact_id"}'); echo "$RB"
CID_B=$(printf '%s' "$RB" | sed 's/^[0-9]* //' | jget data.contact_id)

sep "T2 malformed Child ID as parent A"
M1=$(call "$PT" '{"action":"invite","family_id":"'"$FAMILY_A"'","child_id":"PC123"}'); echo "$M1"
sep "T2b well-formed unknown Child ID as parent A"
M2=$(call "$PT" '{"action":"invite","family_id":"'"$FAMILY_A"'","child_id":"PC23456789"}'); echo "$M2"
MB1=$(printf '%s' "$M1" | sed 's/^[0-9]* //'); MB2=$(printf '%s' "$M2" | sed 's/^[0-9]* //')
printf 'uniform_bodies=%s\n' "$([ "$MB1" = "$MB2" ] && echo YES || echo NO)"

sep "T3 child role cannot invite (forbidden)"
echo "child-invite: $(call "$CA" '{"action":"invite","family_id":"'"$FAMILY_A"'","child_id":"'"$CID_A"'"}')"
sep "T3b unauthenticated invite"
echo "no-auth: $(call "" '{"action":"invite","family_id":"'"$FAMILY_A"'","child_id":"'"$CID_A"'"}')"

sep "T4 parent A invites existing child A by Child ID"
IR=$(call "$PT" '{"action":"invite","family_id":"'"$FAMILY_A"'","child_id":"'"$CID_A"'"}'); echo "$IR"
REQ1=$(printf '%s' "$IR" | sed 's/^[0-9]* //' | jget data.request_id)
sep "T4b repeat invite returns the same live request (no duplicate)"
IR2=$(call "$PT" '{"action":"invite","family_id":"'"$FAMILY_A"'","child_id":"'"$CID_A"'"}'); echo "$IR2"
REQ1b=$(printf '%s' "$IR2" | sed 's/^[0-9]* //' | jget data.request_id)
printf 'same_request=%s\n' "$([ "$REQ1" = "$REQ1b" ] && echo YES || echo NO)"

sep "T4c ID alone: family has no device for child A before approval"
curl -sS --max-time 30 "$URL/rest/v1/devices?family_id=eq.$FAMILY_A&child_user_id=eq.$CHILD_A_ID&select=id,status" \
  -H "apikey: $KEY" -H "Authorization: Bearer $PT"; echo
sep "T4d child A sees the pending request"
echo "pending_child: $(call "$CA" '{"action":"pending_child"}')"

sep "T5 child A approves the request"
echo "respond: $(call "$CA" '{"action":"respond","request_id":"'"$REQ1"'","approve":true}')"
sep "T5b child A gets stable ID again after approval (unchanged)"
RC=$(call "$CA" '{"action":"get_contact_id"}'); echo "$RC"
CID_A3=$(printf '%s' "$RC" | sed 's/^[0-9]* //' | jget data.contact_id)
printf 'unchanged=%s\n' "$([ "$CID_A" = "$CID_A3" ] && echo YES || echo NO)"

sep "T6 unlink by parent A; stable Child ID must survive"
echo "unlink: $(call "$PT" '{"action":"unlink","family_id":"'"$FAMILY_A"'","child_user_id":"'"$CHILD_A_ID"'"}')"
RD=$(call "$CA" '{"action":"get_contact_id"}'); echo "after-unlink-get_contact_id: $RD"
CID_A4=$(printf '%s' "$RD" | sed 's/^[0-9]* //' | jget data.contact_id)
printf 'stable-after-unlink=%s\n' "$([ "$CID_A" = "$CID_A4" ] && echo YES || echo NO)"

sep "T7 child C contact id"
RCC=$(call "$CC" '{"action":"get_contact_id"}'); echo "$RCC"
CID_C=$(printf '%s' "$RCC" | sed 's/^[0-9]* //' | jget data.contact_id)
sep "T7b parent A invites child C (linked to another family) -> uniform invalid_code"
echo "cross-family: $(call "$PT" '{"action":"invite","family_id":"'"$FAMILY_A"'","child_id":"'"$CID_C"'"}')"
sep "T7c parent B invites child C (same family) -> child_already_linked"
echo "same-family: $(call "$PB" '{"action":"invite","family_id":"'"$FAMILY_B"'","child_id":"'"$CID_C"'"}')"

sep "T8 legacy code replay: child B creates a code, parent B redeems twice"
CR=$(call "$CB" '{"action":"create"}'); CSTATUS=$(printf '%s' "$CR" | cut -d' ' -f1)
CODE=$(printf '%s' "$CR" | sed 's/^[0-9]* //' | jget data.code)
echo "create_status: $CSTATUS code_length: ${#CODE}"
RR1=$(call "$PB" '{"action":"redeem","family_id":"'"$FAMILY_B"'","code":"'"$CODE"'"}'); echo "redeem1: $RR1"
RR2=$(call "$PB" '{"action":"redeem","family_id":"'"$FAMILY_B"'","code":"'"$CODE"'}'); echo "redeem2(replay): $RR2"
REQ8=$(printf '%s' "$RR1" | sed 's/^[0-9]* //' | jget data.request_id)
echo "cancel-test-request: $(call "$PB" '{"action":"cancel","request_id":"'"$REQ8"'"}')"

sep "T9 BUG-033 concurrency: 6 parallel invites by parent A for child B"
for i in 1 2 3 4 5 6; do
  ( call "$PT" '{"action":"invite","family_id":"'"$FAMILY_A"'","child_id":"'"$CID_B"'"}' >"$TMP/c$i.txt" ) &
done
wait
for i in 1 2 3 4 5 6; do printf 'call%s: %s\n' "$i" "$(cat "$TMP/c$i.txt")"; done
for i in 1 2 3 4 5 6; do sed 's/^[0-9]* //' "$TMP/c$i.txt" | jget data.created; echo; done | sort | uniq -c
for i in 1 2 3 4 5 6; do sed 's/^[0-9]* //' "$TMP/c$i.txt" | jget data.request_id; echo; done | sort -u | sed '/^$/d' | wc -l | xargs printf 'unique_request_ids=%s\n'
REQ9=$(sed 's/^[0-9]* //' "$TMP/c1.txt" | jget data.request_id)
echo "approve-childB: $(call "$CB" '{"action":"respond","request_id":"'"$REQ9"'","approve":true}')"
echo "unlink-childB: $(call "$PT" '{"action":"unlink","family_id":"'"$FAMILY_A"'","child_user_id":"'"$CHILD_B_ID"'"}')"

sep "T10 rate limit: parent B sends 6 well-formed unknown Child IDs"
for c in PC2345678A PC2345678B PC2345678C PC2345678D PC2345678E PC2345678F; do
  printf '%s -> %s\n' "$c" "$(call "$PB" '{"action":"invite","family_id":"'"$FAMILY_B"'","child_id":"'"$c"'"}')"
done

sep "DONE"
