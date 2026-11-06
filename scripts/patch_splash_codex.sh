#!/bin/bash
set -euo pipefail

# ============================================================================
# patch_splash_codex.sh — Parche de Compatibilidad de Splash con OpenAI Codex
# ============================================================================
# Evita el error HTTP 400 en /v1/responses:
# "only message, reasoning, function_call, function_call_output, custom_tool_call and custom_tool_call_output input items are supported"
# Permite que Codex, ChatGPT Desktop y agentes ejecuten tareas de varios pasos
# sin abortar la ejecución a mitad de camino.
# ============================================================================

SPLASH_BIN="$(which splash 2>/dev/null || echo "/opt/homebrew/bin/splash")"

if [ ! -f "$SPLASH_BIN" ]; then
    echo "❌ No se encontró el binario de Splash en el sistema." >&2
    exit 1
fi

REAL_BIN="$(readlink -f "$SPLASH_BIN" 2>/dev/null || echo "$SPLASH_BIN")"
SPLASH_DIR="$(cd "$(dirname "$REAL_BIN")/.." && pwd)"
API_SHAPES="$SPLASH_DIR/libexec/server/api_shapes.py"

if [ ! -f "$API_SHAPES" ]; then
    # Intentar búsqueda en Cellar común
    API_SHAPES=$(find /opt/homebrew/Cellar/splash -name "api_shapes.py" 2>/dev/null | sort -V | tail -n 1 || true)
fi

if [ -z "$API_SHAPES" ] || [ ! -f "$API_SHAPES" ]; then
    echo "❌ No se pudo localizar 'api_shapes.py' en la instalación de Splash." >&2
    exit 1
fi

echo "🔍 Archivo objetivo: $API_SHAPES"

# Modo Restauración
if [ "${1:-}" = "--restore" ]; then
    if [ -f "$API_SHAPES.orig" ]; then
        cp "$API_SHAPES.orig" "$API_SHAPES"
        echo "✅ Restaurado archivo original desde $API_SHAPES.orig"
        exit 0
    else
        echo "⚠️ No se encontró respaldo $API_SHAPES.orig para restaurar." >&2
        exit 1
    fi
fi

# Verificar si ya está parcheado
if grep -q "Tolerant fallback for agentic harnesses" "$API_SHAPES"; then
    echo "✅ El parche de compatibilidad con Codex ya está activo en Splash."
    exit 0
fi

# Crear respaldo
if [ ! -f "$API_SHAPES.orig" ]; then
    cp "$API_SHAPES" "$API_SHAPES.orig"
    echo "📦 Respaldo creado en: $API_SHAPES.orig"
fi

# Aplicar parche mediante Python
python3 - << EOF
import sys

path = "$API_SHAPES"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

target = '''        elif kind in ("function_call_output", "custom_tool_call_output"):
            call_id, output = item.get("call_id"), item.get("output")
            if not isinstance(call_id, str) or not call_id:
                raise APIError(400, f"{kind} requires call_id")
            output = output.get("content") if isinstance(output, dict) else output
            flush()
            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": call_id,
                    "content": _responses_content(output),
                }
            )
        else:
            raise APIError(
                400,
                "only message, reasoning, function_call, function_call_output, "
                "custom_tool_call and custom_tool_call_output input items are "
                "supported",
            )'''

replacement = '''        elif kind in ("function_call_output", "custom_tool_call_output"):
            call_id = item.get("call_id") or item.get("id")
            output = item.get("output")
            if not call_id:
                call_id = "call_default"
            call_id = str(call_id)
            output = output.get("content") if isinstance(output, dict) else output
            flush()
            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": call_id,
                    "content": _responses_content(output),
                }
            )
        else:
            # Tolerant fallback for agentic harnesses (OpenAI Codex, ChatGPT Desktop, etc.)
            # Items such as commandExecution, mcpToolCall, contextCompaction, item_reference
            call_id = item.get("call_id") or item.get("id")
            content = (
                item.get("output")
                or item.get("content")
                or item.get("text")
                or item.get("result")
                or item.get("command")
            )
            if call_id and item.get("output") is not None:
                flush()
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": str(call_id),
                        "content": _responses_content(item.get("output")),
                    }
                )
            elif content:
                flush()
                extracted = (
                    _responses_text(content)
                    if not isinstance(content, str)
                    else content
                )
                if extracted:
                    messages.append(
                        {
                            "role": "user",
                            "content": f"[{kind}]: {extracted}",
                        }
                    )'''

if target in content:
    new_content = content.replace(target, replacement, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("✅ Parche aplicado con éxito.")
else:
    print("⚠️ El bloque esperado no coincidió exactamente (posible versión diferente).")
    sys.exit(1)
EOF

python3 -m py_compile "$API_SHAPES"
echo "🎉 Compatibilidad con Codex activada correctamente en Splash."
