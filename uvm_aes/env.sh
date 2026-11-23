# Uso: source env.sh
VCS_MODULE="${VCS_MODULE:-vcs}"        # ex.: vcs/U-2023.03-SP2
VERDI_MODULE="${VERDI_MODULE:-verdi}"  # ex.: verdi/U-2023.03-SP2

if command -v module >/dev/null 2>&1; then
  module load "$VCS_MODULE" "$VERDI_MODULE"
else
  echo "[env.sh] 'module' not found - vcs/verdi"
fi

if [ -n "${BASH_SOURCE:-}" ]; then _f="${BASH_SOURCE[0]}"; else _f="${(%):-%x}"; fi
export UVM_AES_ROOT="$(cd "$(dirname "$_f")" && pwd)"
unset _f

command -v vcs   >/dev/null && echo "[env.sh] vcs:   $(command -v vcs)"   || echo "[env.sh] ERRO: vcs nto found"
command -v verdi >/dev/null && echo "[env.sh] verdi: $(command -v verdi)" || echo "[env.sh] ERRO: verdi nto found"
