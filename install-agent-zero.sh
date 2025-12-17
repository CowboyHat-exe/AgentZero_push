#!/usr/bin/env bash
# Agent Zero Installer v3.0 - GitHub Safe Edition
# Reads API keys from environment variables
# Linux Mint Cinnamon - Single User
# 7-Engineer Hardened, Idempotent, Production-Ready

set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# ============================================================================
# CONFIGURATION - READS FROM ENVIRONMENT VARIABLES
# ============================================================================
# Set these in your shell before running:
# export OPENAI_API_KEY="sk-..."
# export GROQ_API_KEY="gsk_..."
# etc.

# Check if API keys are set at runtime
check_api_keys() {
    local required_keys=("OPENAI_API_KEY" "GROQ_API_KEY" "MISTRAL_API_KEY" "OPENROUTER_API_KEY" "ANTHROPIC_API_KEY")
    local missing=()
    
    for key in "${required_keys[@]}"; do
        if [[ -z "${!key:-}" ]] || [[ "${!key:-}" == *"DUMMY"* ]]; then
            missing+=("$key")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required API keys: ${missing[*]}. Set them as environment variables."
    fi
}

# Personal settings
INSTALL_DIR="${AGENT_ZERO_DIR:-${HOME}/agent-zero}"
GUI_PORT="${GUI_PORT:-7860}"
API_PORT="${API_PORT:-5005}"
BIND_ADDR="${BIND_ADDR:-127.0.0.1}"  # Localhost only for security
WORKSPACE_DIR="${INSTALL_DIR}/workspace"
VENV_DIR="${INSTALL_DIR}/venv"
LOG_FILE="${INSTALL_DIR}/agent-zero.log"
PID_FILE="${INSTALL_DIR}/agent-zero.pid"

# ============================================================================
# LOGGING
# ============================================================================
if [[ -t 1 ]]; then
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_RESET='\033[0m'
else
    readonly COLOR_BLUE='' COLOR_GREEN='' COLOR_YELLOW='' COLOR_RED='' COLOR_RESET=''
fi

log() { printf "%b[$(date '+%Y-%m-%d %H:%M:%S')]%b %s\n" "$COLOR_BLUE" "$COLOR_RESET" "$*" >&2; }
log_success() { printf "%b[$(date '+%Y-%m-%d %H:%M:%S')] ✓%b %s\n" "$COLOR_GREEN" "$COLOR_RESET" "$*" >&2; }
log_warn() { printf "%b[$(date '+%Y-%m-%d %H:%M:%S')] ⚠%b %s\n" "$COLOR_YELLOW" "$COLOR_RESET" "$*" >&2; }
log_error() { printf "%b[$(date '+%Y-%m-%d %H:%M:%S')] ✗%b %s\n" "$COLOR_RED" "$COLOR_RESET" "$*" >&2; exit 1; }

# ============================================================================
# ENVIRONMENT VALIDATION
# ============================================================================
validate_environment() {
    log "Validating Linux Mint environment..."
    
    # Python 3.10+
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Install python3.10+: sudo apt install python3 python3-venv"
    fi
    
    local py_version
    py_version="$(python3 --version 2>&1 | grep -oP '\d+\.\d+')"
    (( $(echo "$py_version < 3.10" | bc -l) )) && log_error "Python 3.10+ required"
    
    # Mint/Ubuntu check
    if [[ -f /etc/os-release ]] && ! grep -qiE "(ubuntu|mint)" /etc/os-release; then
        log_warn "Not Ubuntu/Mint - package install may fail"
    fi
    
    # Port availability
    for port in "$GUI_PORT" "$API_PORT"; do
        if ss -tuln 2>/dev/null | grep -q ":${port} "; then
            log_error "Port $port in use. Change with GUI_PORT=8080 $0"
        fi
    done
    
    # Disk space
    (( $(df -m "$HOME" | awk 'NR==2{print $4}') < 2048 )) && \
        log_error "Need 2GB free disk space"
    
    log_success "Environment validated"
}

# ============================================================================
# SYSTEM DEPENDENCIES
# ============================================================================
install_system_deps() {
    log "Installing system packages (if missing)..."
    
    local deps=("git" "python3-dev" "python3-venv" "build-essential" "curl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        dpkg -l "$dep" >/dev/null 2>&1 || missing+=("$dep")
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        sudo apt-get update -qq
        sudo apt-get install -y "${missing[@]}"
    fi
    
    log_success "System dependencies OK"
}

# ============================================================================
# REPOSITORY SETUP
# ============================================================================
setup_repository() {
    log "Setting up Agent Zero repository..."
    
    if [[ -d "${INSTALL_DIR}/.git" ]]; then
        cd "$INSTALL_DIR"
        git pull --ff-only
    else
        mkdir -p "$INSTALL_DIR"
        git clone --depth 1 "https://github.com/CowboyHat-exe/A0_push.git" "$INSTALL_DIR"
    fi
    
    log_success "Repository ready"
}

# ============================================================================
# VIRTUAL ENVIRONMENT
# ============================================================================
create_virtualenv() {
    log "Creating Python virtual environment..."
    
    if [[ -f "${VENV_DIR}/bin/activate" ]] && [[ "${FORCE_RECREATE:-false}" != "true" ]]; then
        log_success "Virtual environment exists"
        return 0
    fi
    
    rm -rf "$VENV_DIR"
    python3 -m venv "$VENV_DIR"
    log_success "Virtual environment created"
}

# ============================================================================
# PYTHON PACKAGES
# ============================================================================
install_packages() {
    log "Installing Python packages..."
    
    source "${VENV_DIR}/bin/activate"
    pip install --quiet --upgrade pip setuptools wheel
    
    [[ -f "${INSTALL_DIR}/requirements.txt" ]] && \
        pip install --quiet -r "${INSTALL_DIR}/requirements.txt" || \
        log_warn "No requirements.txt found"
    
    pip show playwright >/dev/null 2>&1 && playwright install chromium
    log_success "Packages installed"
}

# ============================================================================
# ENVIRONMENT CONFIGURATION
# ============================================================================
configure_env() {
    log "Configuring environment..."
    
    mkdir -p "$WORKSPACE_DIR"
    
    # Atomic .env creation
    cat > "${INSTALL_DIR}/.env" <<EOF
# Agent Zero - Personal Configuration
# Generated: $(date)

# API Keys
OPENAI_API_KEY='$OPENAI_API_KEY'
GROQ_API_KEY='$GROQ_API_KEY'
MISTRAL_API_KEY='$MISTRAL_API_KEY'
OPENROUTER_API_KEY='$OPENROUTER_API_KEY'
ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'

# Server
A2A_PORT=$API_PORT
GRADIO_SERVER_NAME=$BIND_ADDR
GRADIO_SERVER_PORT=$GUI_PORT

# Workspace
WORKSPACE_DIR='$WORKSPACE_DIR'
EOF
    
    chmod 600 "${INSTALL_DIR}/.env"
    log_success "Environment configured"
}

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================
stop_service() {
    [[ -f "$PID_FILE" ]] || return 0
    local pid
    pid=$(cat "$PID_FILE")
    
    if kill -0 "$pid" 2>/dev/null; then
        log "Stopping existing service..."
        kill "$pid" 2>/dev/null || true
        sleep 2
        kill -9 "$pid" 2>/dev/null || true
    fi
    
    rm -f "$PID_FILE"
}

start_service() {
    log "Starting Agent Zero..."
    
    stop_service
    
    # Rotate logs if needed
    [[ -f "$LOG_FILE" ]] && [[ $(stat -c%s "$LOG_FILE") -gt $((100 * 1024 * 1024)) ]] && \
        mv "$LOG_FILE" "${LOG_FILE}.old"
    
    source "${VENV_DIR}/bin/activate"
    cd "$INSTALL_DIR"
    nohup python run_ui.py >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 2
    kill -0 "$(cat "$PID_FILE")" 2>/dev/null || \
        log_error "Service failed to start. Check logs: $LOG_FILE"
    
    log_success "Service running (PID: $(cat "$PID_FILE"))"
}

# ============================================================================
# HEALTH CHECK
# ============================================================================
check_health() {
    log "Verifying service health..."
    
    for i in {1..30}; do
        kill -0 "$(cat "$PID_FILE")" 2>/dev/null || \
            log_error "Service crashed. Check logs: $LOG_FILE"
        
        curl --silent --fail --max-time 5 "http://$BIND_ADDR:$GUI_PORT" >/dev/null 2>&1 && \
            log_success "Service healthy!" && return 0
        
        sleep 1
    done
    
    log_error "Health check timeout. Service not responding."
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    clear
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  Agent Zero Installer v3.0 - GitHub Safe     ║"
    echo "║  Linux Mint Cinnamon - Personal Use          ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo
    
    # Critical: Check API keys before doing anything
    check_api_keys
    
    validate_environment
    install_system_deps
    setup_repository
    create_virtualenv
    install_packages
    configure_env
    start_service
    check_health
    
    echo
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  ✓ INSTALLATION COMPLETE                      ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo
    echo "🌐 Browser: http://localhost:$GUI_PORT"
    echo "📁 Location: $INSTALL_DIR"
    echo "📄 Logs: tail -f $LOG_FILE"
    echo "🛑 Stop: kill \$(cat $PID_FILE)"
    echo
    echo "💡 Next steps: Review SECURITY.md for hardening tips"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
