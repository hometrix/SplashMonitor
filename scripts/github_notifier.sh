#!/usr/bin/env bash
# ==============================================================================
# github_notifier.sh — Monitor de Notificaciones de GitHub para macOS
# Splash Monitor • JMGREP Developers (Joan Gregorio Pérez)
#
# Comprueba nuevos eventos (PRs, Issues, Comentarios, Estrellas, Forks)
# y notificaciones en GitHub para hometrix/SplashMonitor, enviando
# alertas nativas al Centro de Notificaciones de macOS.
# ==============================================================================

set -euo pipefail

REPO="hometrix/SplashMonitor"
STATE_DIR="${HOME}/.splash_monitor_notifier"
LAST_EVENT_FILE="${STATE_DIR}/last_event_id"
PLIST_PATH="${HOME}/Library/LaunchAgents/com.hometrix.splashmonitor.notifier.plist"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

mkdir -p "${STATE_DIR}"

send_notification() {
    local title="$1"
    local subtitle="$2"
    local message="$3"
    local sound="${4:-default}"

    # Escapar comillas dobles para AppleScript
    title="${title//\"/\\\"}"
    subtitle="${subtitle//\"/\\\"}"
    message="${message//\"/\\\"}"

    osascript -e "display notification \"${message}\" with title \"${title}\" subtitle \"${subtitle}\" sound name \"${sound}\""
}

check_gh_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: gh (GitHub CLI) no está instalado o no está en PATH." >&2
        exit 1
    fi
    if ! gh auth status >/dev/null 2>&1; then
        echo "Error: gh no está autenticado. Ejecuta 'gh auth login'." >&2
        exit 1
    fi
}

check_events() {
    check_gh_cli

    # Obtener eventos del repositorio
    local events_json
    events_json="$(gh api "repos/${REPO}/events" --paginate=false 2>/dev/null || echo "[]")"

    if [[ -z "${events_json}" || "${events_json}" == "[]" ]]; then
        return 0
    fi

    local current_user
    current_user="$(gh api user --jq '.login' 2>/dev/null || echo "hometrix")"

    # Si es la primera vez que se ejecuta, guardar el ID del último evento y emitir confirmación
    if [[ ! -f "${LAST_EVENT_FILE}" ]]; then
        local first_id
        first_id="$(echo "${events_json}" | jq -r '.[0].id // empty')"
        if [[ -n "${first_id}" ]]; then
            echo "${first_id}" > "${LAST_EVENT_FILE}"
        fi
        send_notification "GitHub • SplashMonitor" "Monitor de Notificaciones Activo" "Escuchando nuevos eventos de ${REPO}..."
        echo "Monitor inicializado con último evento ID: ${first_id:-ninguno}"
        return 0
    fi

    local last_seen_id
    last_seen_id="$(cat "${LAST_EVENT_FILE}")"

    local new_latest_id=""
    new_latest_id="$(echo "${events_json}" | jq -r '.[0].id // empty')"

    if [[ -n "${new_latest_id}" && "${new_latest_id}" != "${last_seen_id}" ]]; then
        # Procesar eventos en orden cronológico (los más antiguos primero)
        local count
        count="$(echo "${events_json}" | jq --arg last "${last_seen_id}" '[.[] | select(.id == $last)] | length')"
        
        # Extraer solo eventos posteriores al último visto
        local new_events
        new_events="$(echo "${events_json}" | jq --arg last "${last_seen_id}" '
            [ .[] | take_while(.id != $last) ] | reverse
        ')"

        echo "${new_events}" | jq -c '.[]' | while read -r event; do
            local event_type actor action
            event_type="$(echo "${event}" | jq -r '.type')"
            actor="$(echo "${event}" | jq -r '.actor.login')"

            # Ignorar acciones generadas por el propio usuario para evitar eco
            if [[ "${actor}" == "${current_user}" ]]; then
                continue
            fi

            case "${event_type}" in
                "PullRequestEvent")
                    action="$(echo "${event}" | jq -r '.payload.action')"
                    local pr_title
                    pr_title="$(echo "${event}" | jq -r '.payload.pull_request.title')"
                    send_notification "GitHub • SplashMonitor" "🔀 Pull Request (${action})" "@${actor}: ${pr_title}" "Hero"
                    ;;
                "IssuesEvent")
                    action="$(echo "${event}" | jq -r '.payload.action')"
                    local issue_title
                    issue_title="$(echo "${event}" | jq -r '.payload.issue.title')"
                    send_notification "GitHub • SplashMonitor" "🐛 Nuevo Issue (${action})" "@${actor}: ${issue_title}" "Hero"
                    ;;
                "IssueCommentEvent")
                    action="$(echo "${event}" | jq -r '.payload.action')"
                    local issue_number comment_body
                    issue_number="$(echo "${event}" | jq -r '.payload.issue.number')"
                    comment_body="$(echo "${event}" | jq -r '.payload.comment.body' | head -n 1)"
                    send_notification "GitHub • SplashMonitor" "💬 Comentario en #${issue_number}" "@${actor}: ${comment_body}"
                    ;;
                "WatchEvent")
                    send_notification "GitHub • SplashMonitor" "⭐ Nueva Estrella" "¡@${actor} ha marcado SplashMonitor con una estrella!" "Glass"
                    ;;
                "ForkEvent")
                    send_notification "GitHub • SplashMonitor" "🍴 Nuevo Fork" "¡@${actor} ha hecho un fork de SplashMonitor!" "Glass"
                    ;;
                "ReleaseEvent")
                    local release_name
                    release_name="$(echo "${event}" | jq -r '.payload.release.name // .payload.release.tag_name')"
                    send_notification "GitHub • SplashMonitor" "🚀 Nueva Release" "${release_name} publicada por @${actor}"
                    ;;
            esac
        done

        # Actualizar el último ID procesado
        echo "${new_latest_id}" > "${LAST_EVENT_FILE}"
    fi

    # Comprobar además notificaciones directas (menciones, asignaciones)
    local unread_notifs
    unread_notifs="$(gh api notifications 2>/dev/null || echo "[]")"
    if [[ "${unread_notifs}" != "[]" ]]; then
        echo "${unread_notifs}" | jq -c '.[]' | while read -r notif; do
            local notif_repo notif_title notif_reason notif_id
            notif_id="$(echo "${notif}" | jq -r '.id')"
            notif_repo="$(echo "${notif}" | jq -r '.repository.full_name')"
            notif_title="$(echo "${notif}" | jq -r '.subject.title')"
            notif_reason="$(echo "${notif}" | jq -r '.reason')"

            local notified_file="${STATE_DIR}/notif_${notif_id}"
            if [[ ! -f "${notified_file}" ]]; then
                touch "${notified_file}"
                send_notification "GitHub • ${notif_repo}" "🔔 Notificación (${notif_reason})" "${notif_title}"
            fi
        done
    fi
}

install_daemon() {
    check_gh_cli
    local gh_path
    gh_path="$(command -v gh)"
    local jq_path
    jq_path="$(command -v jq)"
    local path_env
    path_env="$(dirname "${gh_path}"):$(dirname "${jq_path}"):/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    cat <<EOF > "${PLIST_PATH}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.hometrix.splashmonitor.notifier</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_PATH}</string>
        <string>--once</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${path_env}</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
    <key>StartInterval</key>
    <integer>180</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${STATE_DIR}/notifier.log</string>
    <key>StandardErrorPath</key>
    <string>${STATE_DIR}/notifier_err.log</string>
</dict>
</plist>
EOF

    # Cargar agente en launchd
    launchctl unload "${PLIST_PATH}" 2>/dev/null || true
    launchctl load "${PLIST_PATH}"

    echo "✅ Servicio en segundo plano instalado correctamente en macOS."
    echo "Frecuencia: Cada 3 minutos (180 segundos)."
    echo "Logs: ${STATE_DIR}/notifier.log"
    send_notification "Splash Monitor" "Notificaciones de GitHub Activadas" "Recibirás alertas nativas de PRs, Issues, comentarios y estrellas cada 3 min."
}

uninstall_daemon() {
    if [[ -f "${PLIST_PATH}" ]]; then
        launchctl unload "${PLIST_PATH}" 2>/dev/null || true
        rm -f "${PLIST_PATH}"
        echo "✅ Servicio en segundo plano desinstalado."
    else
        echo "El servicio no estaba instalado."
    fi
}

status_daemon() {
    echo "=== Estado del Monitor de Notificaciones de GitHub ==="
    echo "Repositorio: ${REPO}"
    echo "Archivo de estado: ${STATE_DIR}"
    if [[ -f "${LAST_EVENT_FILE}" ]]; then
        echo "Último evento registrado: $(cat "${LAST_EVENT_FILE}")"
    else
        echo "Último evento registrado: Ninguno aún"
    fi

    if launchctl list | grep -q "com.hometrix.splashmonitor.notifier"; then
        echo "Servicio launchd: ACTIVO (corriendo en segundo plano)"
    else
        echo "Servicio launchd: INACTIVO"
    fi
}

# --- Manejo de Argumentos ---
case "${1:-}" in
    --install)
        install_daemon
        ;;
    --uninstall)
        uninstall_daemon
        ;;
    --status)
        status_daemon
        ;;
    --test)
        send_notification "GitHub • SplashMonitor" "Prueba de Notificación" "Este es un mensaje de prueba del monitor nativo." "Glass"
        echo "Notificación de prueba enviada al Centro de Notificaciones."
        ;;
    --once|"")
        check_events
        ;;
    *)
        echo "Uso: $0 [--install | --uninstall | --status | --test | --once]"
        exit 1
        ;;
esac
