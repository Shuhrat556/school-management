#!/usr/bin/env bash
# Claude Code'ni docs/ai/ holatidan qayta-qayta ishga tushiradi.
#  - limit xabari chiqsa 30 daqiqa kutadi va davom etadi;
#  - PLAN.md da [ ] / [~] vazifa qolmasa yoki PROGRESS.md da qator boshida
#    "RUXSAT KERAK" paydo bo'lsa to'xtaydi;
#  - hamma chiqish docs/ai/run.log ga yoziladi.
# Ishga tushirish: tmux new -s ai './ai-loop.sh'
set -u

cd "$(dirname "$0")" || exit 1

LOG=docs/ai/run.log
PLAN=docs/ai/PLAN.md
PROGRESS=docs/ai/PROGRESS.md
LIMIT_WAIT=${LIMIT_WAIT:-1800}   # limitdan keyin kutish (s)
ERROR_WAIT=${ERROR_WAIT:-300}    # boshqa xatodan keyin kutish (s)
MAX_IDLE=${MAX_IDLE:-3}          # PROGRESS.md o'zgarmagan ketma-ket yurishlar chegarasi

PROMPT="docs/ai/ ni o'qi va KEYINGI QADAM dan davom et. Qoidalar: docs/ai/RULES.md va CLAUDE.md. \
Har kichik vazifadan keyin PLAN.md va PROGRESS.md ni yangila va commit qil."

LIMIT_RE='usage limit|limit reached|hit your (usage )?limit|limit will reset|resets at|rate.?limit|overloaded|429'

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }

idle=0
while true; do
  if [ -f "$PLAN" ] && ! grep -qE '^[[:space:]]*[-*][[:space:]]*\[( |~)\]' "$PLAN"; then
    log "Reja bajarildi: PLAN.md da ochiq vazifa yo'q."; break
  fi
  if grep -qE '^RUXSAT KERAK' "$PROGRESS" 2>/dev/null; then
    log "Ruxsat kutilmoqda — docs/ai/PROGRESS.md va QUESTIONS.md ni ko'ring."; break
  fi

  before=$(cksum < "$PROGRESS" 2>/dev/null)
  log "=== claude -p ishga tushdi ==="
  OUT=$(claude -p "$PROMPT" --permission-mode auto 2>&1)
  status=$?
  printf '%s\n' "$OUT" >> "$LOG"
  log "=== tugadi (exit $status) ==="

  # Limit: muvaffaqiyatsiz yurishda keng, muvaffaqiyatlida faqat oxirgi qatorlarda qidiramiz,
  # shunda "rate limiting" haqidagi oddiy ish hisoboti kutishga sabab bo'lmaydi.
  if { [ $status -ne 0 ] && printf '%s' "$OUT" | grep -qiE "$LIMIT_RE"; } \
     || printf '%s' "$OUT" | tail -n 3 | grep -qiE 'usage limit|limit reached|hit your (usage )?limit'; then
    log "Limit — $((LIMIT_WAIT / 60)) daqiqa kutamiz."; sleep "$LIMIT_WAIT"; continue
  fi
  if [ $status -ne 0 ]; then
    log "Xato (exit $status) — $((ERROR_WAIT / 60)) daqiqa kutamiz."; sleep "$ERROR_WAIT"; continue
  fi

  after=$(cksum < "$PROGRESS" 2>/dev/null)
  if [ "$before" = "$after" ]; then
    idle=$((idle + 1))
    if [ "$idle" -ge "$MAX_IDLE" ]; then
      log "PROGRESS.md $MAX_IDLE marta ketma-ket o'zgarmadi — to'xtatildi, run.log ni ko'ring."; break
    fi
  else
    idle=0
  fi
  sleep 10
done
