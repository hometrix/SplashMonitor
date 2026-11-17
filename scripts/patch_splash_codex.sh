#!/bin/bash
set -euo pipefail

# ============================================================================
# patch_splash_codex.sh — Parche de Compatibilidad de Splash con OpenAI Codex
# ============================================================================
# Evita los errores comunes en /v1/responses:
# 1. HTTP 400: "only message, reasoning, function_call... input items are supported"
# 2. Fatal compaction error: "remote compaction v2 expected exactly one compaction output item"
# Compatible con Splash 1.6.0, 1.7.0+ (server/dialects/responses.py) y 1.5.x (server/api_shapes.py)
# ============================================================================

SPLASH_BIN="$(which splash 2>/dev/null || echo "/opt/homebrew/bin/splash")"

if [ ! -f "$SPLASH_BIN" ]; then
    echo "❌ No se encontró el binario de Splash en el sistema." >&2
    exit 1
fi

REAL_BIN="$(readlink -f "$SPLASH_BIN" 2>/dev/null || echo "$SPLASH_BIN")"
SPLASH_DIR="$(cd "$(dirname "$REAL_BIN")/.." && pwd)"

TARGET_FILE=""
IS_MODULAR_DIALECT=false

if [ -f "$SPLASH_DIR/libexec/server/dialects/responses.py" ]; then
    TARGET_FILE="$SPLASH_DIR/libexec/server/dialects/responses.py"
    IS_MODULAR_DIALECT=true
elif [ -f "$SPLASH_DIR/libexec/server/api_shapes.py" ]; then
    TARGET_FILE="$SPLASH_DIR/libexec/server/api_shapes.py"
    IS_MODULAR_DIALECT=false
else
    # Buscar en Cellar
    TARGET_FILE=$(find /opt/homebrew/Cellar/splash -name "responses.py" 2>/dev/null | grep "dialects/responses.py" | sort -V | tail -n 1 || true)
    if [ -n "$TARGET_FILE" ] && [ -f "$TARGET_FILE" ]; then
        IS_MODULAR_DIALECT=true
    else
        TARGET_FILE=$(find /opt/homebrew/Cellar/splash -name "api_shapes.py" 2>/dev/null | sort -V | tail -n 1 || true)
        IS_MODULAR_DIALECT=false
    fi
fi

if [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ]; then
    echo "❌ No se pudo localizar 'responses.py' ni 'api_shapes.py' en la instalación de Splash." >&2
    exit 1
fi

echo "🔍 Archivo objetivo: $TARGET_FILE (Dialecto modular: $IS_MODULAR_DIALECT)"

# Modo Restauración
if [ "${1:-}" = "--restore" ]; then
    if [ -f "$TARGET_FILE.orig" ]; then
        cp "$TARGET_FILE.orig" "$TARGET_FILE"
        echo "✅ Restaurado archivo original desde $TARGET_FILE.orig"
        exit 0
    else
        echo "⚠️ No se encontró respaldo $TARGET_FILE.orig para restaurar." >&2
        exit 1
    fi
fi

# Verificar si ya está parcheado
if grep -q "Tolerant fallback for agentic harness input items" "$TARGET_FILE"; then
    echo "✅ El parche de compatibilidad con Codex ya está activo en Splash."
    exit 0
fi

# Crear respaldo
if [ ! -f "$TARGET_FILE.orig" ]; then
    cp "$TARGET_FILE" "$TARGET_FILE.orig"
    echo "📦 Respaldo creado en: $TARGET_FILE.orig"
fi

# Aplicar parche mediante Python
python3 - << EOF
import sys

path = "$TARGET_FILE"
is_modular = "$IS_MODULAR_DIALECT".lower() == "true"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

if is_modular:
    # 1. Fallback tolerante en normalize_input
    target_norm = '''        else:
            raise APIError(
                400,
                "only message, reasoning, function_call, function_call_output, "
                "custom_tool_call and custom_tool_call_output input items are "
                "supported",
            )'''
    
    repl_norm = '''        else:
            # Tolerant fallback for agentic harness input items
            # (e.g. commandExecution, mcpToolCall, contextCompaction, item_reference)
            call_id = item.get("call_id") or item.get("id")
            output = item.get("output")
            content = item.get("content")
            if call_id and output is not None:
                output = output.get("content") if isinstance(output, dict) else output
                flush()
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": str(call_id),
                        "content": _content(output),
                    }
                )
            elif content is not None:
                flush()
                extracted = (
                    _text(content)
                    if not isinstance(content, str)
                    else content
                )
                if extracted:
                    messages.append(
                        {
                            "role": "user",
                            "content": extracted,
                        }
                    )'''
    
    if target_norm in content:
        content = content.replace(target_norm, repl_norm, 1)
    else:
        print("⚠️ No se encontró el bloque de validación estricta de normalize_input.")
        sys.exit(1)

    # 2. Registrar prefijo 'compaction': 'cmp'
    target_prefixes = '''_ITEM_PREFIXES = {
    "reasoning": "rs",
    "text": "msg",
    "tool": "fc",
    "custom": "ctc",
}'''
    repl_prefixes = '''_ITEM_PREFIXES = {
    "reasoning": "rs",
    "text": "msg",
    "tool": "fc",
    "custom": "ctc",
    "compaction": "cmp",
}'''
    if target_prefixes in content:
        content = content.replace(target_prefixes, repl_prefixes, 1)

    # 3. Detectar compaction en prepare
    target_prep = '''        job.retained_input = conversation.items
        return job, conversation'''
    repl_prep = '''        job.retained_input = conversation.items
        instructions = (body.get("instructions") or "").lower()
        job.is_compaction = (
            "compact" in instructions
            or "compaction" in instructions
        )
        return job, conversation'''
    if target_prep in content:
        content = content.replace(target_prep, repl_prep, 1)

    # 4. Formatear salida única de compactación
    target_out = '''def output_items(job, blocks):
    return [output_item(job, block, index) for index, block in enumerate(blocks)]'''
    repl_out = '''def output_items(job, blocks):
    if getattr(job, "is_compaction", False):
        full_text = "".join(b.text for b in blocks if getattr(b, "text", None))
        return [
            {
                "id": output_item_id(job, "compaction", 0),
                "type": "compaction",
                "status": "completed",
                "summary": [{"type": "summary_text", "text": full_text}],
                "content": [{"type": "output_text", "text": full_text, "annotations": []}],
                "encrypted_content": None,
            }
        ]
    return [output_item(job, block, index) for index, block in enumerate(blocks)]'''
    if target_out in content:
        content = content.replace(target_out, repl_out, 1)

else:
    # Versión monolítica legacy (Splash 1.5.x)
    target_norm = '''        else:
            raise APIError(
                400,
                "only message, reasoning, function_call, function_call_output, "
                "custom_tool_call and custom_tool_call_output input items are "
                "supported",
            )'''
    repl_norm = '''        else:
            # Tolerant fallback for agentic harness input items
            call_id = item.get("call_id") or item.get("id")
            output = item.get("output")
            content = item.get("content")
            if call_id and output is not None:
                output = output.get("content") if isinstance(output, dict) else output
                flush()
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": str(call_id),
                        "content": _responses_content(output),
                    }
                )
            elif content is not None:
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
                            "content": extracted,
                        }
                    )'''
    if target_norm in content:
        content = content.replace(target_norm, repl_norm, 1)
    else:
        print("⚠️ No se encontró el bloque esperado en api_shapes.py legacy.")
        sys.exit(1)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Parche aplicado con éxito.")
EOF

python3 -m py_compile "$TARGET_FILE"
echo "🎉 Compatibilidad con Codex activada correctamente en Splash."
