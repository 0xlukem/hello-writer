#!/usr/bin/env bash

set -e

# ============================================================
# CONFIGURATION
# ============================================================

if [ -n "${NO_COLOR:-}" ]; then
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    BOLD=""
    DIM=""
    NC=""
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
fi

OK_MARK="[OK]"
WARN_MARK="[WARN]"
ERR_MARK="[ERR]"

CONFIG_FILE="config/content-engine.yml"
AGENTS_DIR=".opencode/agents"
MEMORY_DIR=".opencode/agents/memory"
TEMPLATES_DIR="templates"
OUTPUT_DIR="output"
VOICE_FILE="$MEMORY_DIR/digital-twin.memory.md"

DEFAULT_ORCHESTRATOR="opencode-go/kimi-k2.6"
DEFAULT_WRITER="opencode-go/deepseek-v4-pro"
DEFAULT_FAST="opencode-go/deepseek-v4-flash"
DEFAULT_IMAGE="openai/gpt-5.5"
DEFAULT_SETUP_ORCHESTRATOR="opencode-go/kimi-k2.6"
DEFAULT_LINKEDIN_ENABLED="n"
DEFAULT_X_ENABLED="n"
DEFAULT_REEL_ENABLED="n"
DEFAULT_IMAGES_ENABLED="y"
DEFAULT_STYLEGUIDE="null"

RUN_MODE="full"
DRY_RUN="false"
SETUP_ACTION="new"
AVAILABLE_MODELS=""
MODEL_DISCOVERY_STATUS="not_run"
VOICE_ACTION="create"
VOICE_BUILDER_MODE="full"
TOTAL_STEPS=8
VOICE_TOTAL_STEPS=9
STYLEGUIDE_SOURCE=""
STEP_ENV=1
STEP_EXISTING=2
STEP_MODELS=3
STEP_FEATURES=4
STEP_VOICE=5
STEP_STYLEGUIDE=6
STEP_CONFIRM=7
STEP_GENERATE=8
STEP_RENDER=2
STEP_VALIDATE=2

SAMPLE_PATHS=()
SAMPLE_ANALYSIS="None recorded yet"
AI_ANALYSIS="None recorded yet"
CALIBRATION_NOTES="None recorded yet"

# ============================================================
# TERMINAL UI
# ============================================================

mode_label() {
    case "$RUN_MODE" in
        quick) echo "Quick setup" ;;
        voice) echo "Voice only" ;;
        technical) echo "Technical setup" ;;
        render-only) echo "Render only" ;;
        validate-only) echo "Validate only" ;;
        *) echo "Full setup" ;;
    esac
}

configure_steps() {
    case "$RUN_MODE" in
        quick)
            TOTAL_STEPS=5
            STEP_ENV=1
            STEP_EXISTING=2
            STEP_VOICE=3
            STEP_CONFIRM=4
            STEP_GENERATE=5
            ;;
        voice)
            TOTAL_STEPS=4
            STEP_ENV=1
            STEP_VOICE=2
            STEP_CONFIRM=3
            STEP_GENERATE=4
            ;;
        technical)
            TOTAL_STEPS=7
            STEP_ENV=1
            STEP_EXISTING=2
            STEP_MODELS=3
            STEP_FEATURES=4
            STEP_STYLEGUIDE=5
            STEP_CONFIRM=6
            STEP_GENERATE=7
            ;;
        render-only)
            TOTAL_STEPS=3
            STEP_ENV=1
            STEP_RENDER=2
            STEP_VALIDATE=3
            ;;
        validate-only)
            TOTAL_STEPS=2
            STEP_ENV=1
            STEP_VALIDATE=2
            ;;
        *)
            TOTAL_STEPS=8
            STEP_ENV=1
            STEP_EXISTING=2
            STEP_MODELS=3
            STEP_FEATURES=4
            STEP_VOICE=5
            STEP_STYLEGUIDE=6
            STEP_CONFIRM=7
            STEP_GENERATE=8
            ;;
    esac
}

print_header() {
    echo ""
    printf "%b\n" "${BOLD}${CYAN}============================================================${NC}"
    printf "%b\n" "${BOLD}${CYAN}  hello-writer Setup Wizard${NC}"
    printf "%b\n" "${CYAN}  Guided installer for reusable content engines${NC}"
    printf "%b\n" "${DIM}  Mode: $(mode_label) | Dry run: $DRY_RUN${NC}"
    printf "%b\n" "${BOLD}${CYAN}============================================================${NC}"
    echo ""
}

print_step() {
    printf "%b\n" "${BLUE}${BOLD}Step $1/$2${NC} ${BOLD}$3${NC}"
}

print_substep() {
    printf "%b\n" "${CYAN}Voice $1/$2${NC} ${BOLD}$3${NC}"
}

print_success() {
    printf "%b\n" "${GREEN}${OK_MARK}${NC} $1"
}

print_warning() {
    printf "%b\n" "${YELLOW}${WARN_MARK}${NC} $1" >&2
}

print_error() {
    printf "%b\n" "${RED}${ERR_MARK}${NC} $1" >&2
}

print_hint() {
    printf "%b\n" "${DIM}$1${NC}" >&2
}

print_section() {
    printf "%b\n" "${CYAN}$1${NC}"
}

print_write_ready() {
    local label="$1"
    local target="$2"

    if [ "$DRY_RUN" = "true" ]; then
        print_warning "DRY RUN verified plan for $label: $target"
    else
        print_success "$label ready: $target"
    fi
}

prompt_help() {
    print_hint "Commands: help shows this hint, skip accepts the default or leaves blank, back returns to the previous voice section when supported, quit exits."
}

ask_text() {
    local prompt="$1"
    local default="${2:-}"
    local answer

    while true; do
        if [ -n "$default" ]; then
            printf "%b" "${BOLD}$prompt${NC} ${DIM}[$default]${NC}: " >&2
        else
            printf "%b" "${BOLD}$prompt${NC}: " >&2
        fi

        if ! IFS= read -r answer; then
            answer="$default"
        fi

        case "$answer" in
            help)
                prompt_help
                continue
                ;;
            quit)
                print_warning "Setup cancelled by user."
                exit 0
                ;;
            skip)
                echo "$default"
                return 0
                ;;
            back)
                echo "__BACK__"
                return 0
                ;;
        esac

        if [ -z "$answer" ]; then
            answer="$default"
        fi

        echo "$answer"
        return 0
    done
}

ask() {
    ask_text "$1" "${2:-}"
}

ask_required() {
    local prompt="$1"
    local default="${2:-}"
    local answer

    while true; do
        answer=$(ask_text "$prompt" "$default")
        if [ "$answer" = "__BACK__" ]; then
            echo "$answer"
            return 0
        fi
        if [ -n "$answer" ]; then
            echo "$answer"
            return 0
        fi
        print_warning "This answer is required. Type 'skip' only where optional."
    done
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    default=$(to_yn_default "$default" "$default")

    while true; do
        response=$(ask_text "$prompt (y/n)" "$default")
        case "$response" in
            __BACK__) echo "__BACK__"; return 0 ;;
            y|Y|yes|YES|true|TRUE) echo "true"; return 0 ;;
            n|N|no|NO|false|FALSE) echo "false"; return 0 ;;
            *) print_warning "Please answer y or n." ;;
        esac
    done
}

ask_choice() {
    local prompt="$1"
    local default="$2"
    local valid="$3"
    local answer

    while true; do
        answer=$(ask_text "$prompt" "$default")
        if [ "$answer" = "__BACK__" ]; then
            echo "$answer"
            return 0
        fi
        if printf "%s\n" "$valid" | grep -Fxq "$answer"; then
            echo "$answer"
            return 0
        fi
        print_warning "Choose one of: $(printf "%s" "$valid" | tr '\n' ' ')"
    done
}

ask_multiline() {
    local prompt="$1"
    local line
    local body=""

    printf "%b\n" "${BOLD}$prompt${NC}" >&2
    print_hint "Finish with a single '.' line. Type 'skip' as the first line to leave blank."

    while true; do
        if ! IFS= read -r line; then
            break
        fi
        case "$line" in
            ".") break ;;
            "skip")
                if [ -z "$body" ]; then
                    echo ""
                    return 0
                fi
                ;;
            "quit")
                print_warning "Setup cancelled by user."
                exit 0
                ;;
            "help")
                prompt_help
                continue
                ;;
        esac
        if [ -z "$body" ]; then
            body="$line"
        else
            body="$body
$line"
        fi
    done

    echo "$body"
}

ask_file_path() {
    local prompt="$1"
    local answer
    answer=$(ask_text "$prompt" "")
    if [ "$answer" = "__BACK__" ]; then
        echo "$answer"
        return 0
    fi
    echo "$answer"
}

usage() {
    cat << EOF
hello-writer setup

Usage:
  ./setup.sh                    Run the full interactive setup wizard
  ./install.sh                  Alias for ./setup.sh
  ./setup.sh --quick            Defaults + short voice interview + render
  ./setup.sh --voice            Rebuild only $VOICE_FILE
  ./setup.sh --technical        Models/platforms/styleguide/render, preserving voice by default
  ./setup.sh --dry-run [mode]   Preview writes without changing files
  ./setup.sh --render-only      Re-render .opencode/agents from existing config
  ./setup.sh --validate-only    Validate generated config, agents, memories, output metadata, and models when available
  ./setup.sh --help             Show this help

Prompt commands:
  help, back, skip, quit

Color:
  Set NO_COLOR=1 to disable terminal colors.
EOF
}

# ============================================================
# LOW-LEVEL HELPERS
# ============================================================

to_yn_default() {
    case "$1" in
        true|TRUE|yes|YES|y|Y) echo "y" ;;
        false|FALSE|no|NO|n|N) echo "n" ;;
        *) echo "$2" ;;
    esac
}

safe_value() {
    if [ -n "${1:-}" ]; then
        printf "%s" "$1"
    else
        printf "Not provided"
    fi
}

safe_none() {
    if [ -n "${1:-}" ]; then
        printf "%s" "$1"
    else
        printf "None recorded yet"
    fi
}

ensure_dir() {
    local dir="$1"
    if [ "$DRY_RUN" = "true" ]; then
        print_warning "DRY RUN would create directory: $dir"
        return 0
    fi
    mkdir -p "$dir"
}

write_text_file() {
    local target="$1"
    local content="$2"

    if [ "$DRY_RUN" = "true" ]; then
        print_warning "DRY RUN would write: $target"
        return 0
    fi

    mkdir -p "$(dirname "$target")"
    printf "%s\n" "$content" > "$target"
}

copy_file() {
    local source="$1"
    local target="$2"

    if [ "$DRY_RUN" = "true" ]; then
        print_warning "DRY RUN would copy: $source -> $target"
        return 0
    fi

    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
}

sed_in_place() {
    local expression="$1"
    local target="$2"

    if sed --version >/dev/null 2>&1; then
        sed -i "$expression" "$target"
    else
        sed -i '' "$expression" "$target"
    fi
}

backup_file() {
    local target="$1"
    if [ ! -f "$target" ]; then
        return 0
    fi

    local backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
    if [ "$DRY_RUN" = "true" ]; then
        print_warning "DRY RUN would create backup: $backup"
        return 0
    fi

    cp "$target" "$backup"
    print_success "Backup created: $backup"
}

will_write_voice_profile() {
    [ "$VOICE_ACTION" != "preserve" ] && {
        [ "$RUN_MODE" = "full" ] || [ "$RUN_MODE" = "quick" ] || [ "$RUN_MODE" = "voice" ]
    }
}

read_config_value() {
    local section="$1"
    local key="$2"

    if [ ! -f "$CONFIG_FILE" ]; then
        return 0
    fi

    awk -v section="$section" -v key="$key" '
        $0 ~ "^" section ":" { in_section=1; next }
        in_section && $0 ~ "^[^[:space:]]" { in_section=0 }
        in_section {
            pattern="^[[:space:]]*" key ":[[:space:]]*"
            if ($0 ~ pattern) {
                sub(pattern, "", $0)
                gsub(/^"/, "", $0)
                gsub(/"$/, "", $0)
                print $0
                exit
            }
        }
    ' "$CONFIG_FILE"
}

load_existing_config_defaults() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 0
    fi

    local value

    value=$(read_config_value "models" "orchestrator"); [ -n "$value" ] && DEFAULT_ORCHESTRATOR="$value"
    value=$(read_config_value "models" "researcher"); [ -n "$value" ] && DEFAULT_RESEARCHER="$value"
    value=$(read_config_value "models" "seo_expert"); [ -n "$value" ] && DEFAULT_SEO_EXPERT="$value"
    value=$(read_config_value "models" "digital_twin"); [ -n "$value" ] && DEFAULT_DIGITAL_TWIN="$value"
    value=$(read_config_value "models" "blog_writer"); [ -n "$value" ] && DEFAULT_BLOG_WRITER="$value"
    value=$(read_config_value "models" "editor"); [ -n "$value" ] && DEFAULT_EDITOR="$value"
    value=$(read_config_value "models" "image_creator"); [ -n "$value" ] && DEFAULT_IMAGE_CREATOR="$value"
    value=$(read_config_value "models" "repurposer"); [ -n "$value" ] && DEFAULT_REPURPOSER="$value"
    value=$(read_config_value "models" "linkedin_writer"); [ -n "$value" ] && DEFAULT_LINKEDIN_WRITER="$value"
    value=$(read_config_value "models" "x_thread_writer"); [ -n "$value" ] && DEFAULT_X_THREAD_WRITER="$value"
    value=$(read_config_value "models" "reel_script_writer"); [ -n "$value" ] && DEFAULT_REEL_SCRIPT_WRITER="$value"
    value=$(read_config_value "models" "editor_light"); [ -n "$value" ] && DEFAULT_EDITOR_LIGHT="$value"
    value=$(read_config_value "models" "report_writer"); [ -n "$value" ] && DEFAULT_REPORT_WRITER="$value"
    value=$(read_config_value "models" "feedback_architect"); [ -n "$value" ] && DEFAULT_FEEDBACK_ARCHITECT="$value"
    value=$(read_config_value "models" "history_logger"); [ -n "$value" ] && DEFAULT_HISTORY_LOGGER="$value"
    value=$(read_config_value "models" "setup_orchestrator"); [ -n "$value" ] && DEFAULT_SETUP_ORCHESTRATOR="$value"

    DEFAULT_RESEARCHER="${DEFAULT_RESEARCHER:-$DEFAULT_WRITER}"
    DEFAULT_SEO_EXPERT="${DEFAULT_SEO_EXPERT:-$DEFAULT_WRITER}"
    DEFAULT_DIGITAL_TWIN="${DEFAULT_DIGITAL_TWIN:-$DEFAULT_WRITER}"
    DEFAULT_BLOG_WRITER="${DEFAULT_BLOG_WRITER:-$DEFAULT_WRITER}"
    DEFAULT_EDITOR="${DEFAULT_EDITOR:-$DEFAULT_WRITER}"
    DEFAULT_IMAGE_CREATOR="${DEFAULT_IMAGE_CREATOR:-$DEFAULT_IMAGE}"
    DEFAULT_REPURPOSER="${DEFAULT_REPURPOSER:-$DEFAULT_ORCHESTRATOR}"
    DEFAULT_LINKEDIN_WRITER="${DEFAULT_LINKEDIN_WRITER:-$DEFAULT_FAST}"
    DEFAULT_X_THREAD_WRITER="${DEFAULT_X_THREAD_WRITER:-$DEFAULT_FAST}"
    DEFAULT_REEL_SCRIPT_WRITER="${DEFAULT_REEL_SCRIPT_WRITER:-$DEFAULT_FAST}"
    DEFAULT_EDITOR_LIGHT="${DEFAULT_EDITOR_LIGHT:-$DEFAULT_FAST}"
    DEFAULT_REPORT_WRITER="${DEFAULT_REPORT_WRITER:-$DEFAULT_WRITER}"
    DEFAULT_FEEDBACK_ARCHITECT="${DEFAULT_FEEDBACK_ARCHITECT:-$DEFAULT_ORCHESTRATOR}"
    DEFAULT_HISTORY_LOGGER="${DEFAULT_HISTORY_LOGGER:-$DEFAULT_FAST}"

    value=$(read_config_value "platforms" "linkedin"); DEFAULT_LINKEDIN_ENABLED=$(to_yn_default "$value" "$DEFAULT_LINKEDIN_ENABLED")
    value=$(read_config_value "platforms" "x"); DEFAULT_X_ENABLED=$(to_yn_default "$value" "$DEFAULT_X_ENABLED")
    value=$(read_config_value "platforms" "reel"); DEFAULT_REEL_ENABLED=$(to_yn_default "$value" "$DEFAULT_REEL_ENABLED")
    value=$(read_config_value "features" "images"); DEFAULT_IMAGES_ENABLED=$(to_yn_default "$value" "$DEFAULT_IMAGES_ENABLED")
    value=$(read_config_value "features" "styleguide"); [ -n "$value" ] && DEFAULT_STYLEGUIDE="$value"
}

assign_model_vars_from_defaults() {
    ORCHESTRATOR_MODEL="$DEFAULT_ORCHESTRATOR"
    RESEARCHER_MODEL="${DEFAULT_RESEARCHER:-$DEFAULT_WRITER}"
    SEO_EXPERT_MODEL="${DEFAULT_SEO_EXPERT:-$DEFAULT_WRITER}"
    DIGITAL_TWIN_MODEL="${DEFAULT_DIGITAL_TWIN:-$DEFAULT_WRITER}"
    BLOG_WRITER_MODEL="${DEFAULT_BLOG_WRITER:-$DEFAULT_WRITER}"
    EDITOR_MODEL="${DEFAULT_EDITOR:-$DEFAULT_WRITER}"
    IMAGE_CREATOR_MODEL="${DEFAULT_IMAGE_CREATOR:-$DEFAULT_IMAGE}"
    REPURPOSER_MODEL="${DEFAULT_REPURPOSER:-$DEFAULT_ORCHESTRATOR}"
    LINKEDIN_WRITER_MODEL="${DEFAULT_LINKEDIN_WRITER:-$DEFAULT_FAST}"
    X_THREAD_WRITER_MODEL="${DEFAULT_X_THREAD_WRITER:-$DEFAULT_FAST}"
    REEL_SCRIPT_WRITER_MODEL="${DEFAULT_REEL_SCRIPT_WRITER:-$DEFAULT_FAST}"
    EDITOR_LIGHT_MODEL="${DEFAULT_EDITOR_LIGHT:-$DEFAULT_FAST}"
    REPORT_WRITER_MODEL="${DEFAULT_REPORT_WRITER:-$DEFAULT_WRITER}"
    FEEDBACK_ARCHITECT_MODEL="${DEFAULT_FEEDBACK_ARCHITECT:-$DEFAULT_ORCHESTRATOR}"
    HISTORY_LOGGER_MODEL="${DEFAULT_HISTORY_LOGGER:-$DEFAULT_FAST}"
    SETUP_ORCHESTRATOR_MODEL="$DEFAULT_SETUP_ORCHESTRATOR"

    BLOG_ENABLED="true"
    LINKEDIN_ENABLED=$([ "$DEFAULT_LINKEDIN_ENABLED" = "y" ] && echo "true" || echo "false")
    X_ENABLED=$([ "$DEFAULT_X_ENABLED" = "y" ] && echo "true" || echo "false")
    REEL_ENABLED=$([ "$DEFAULT_REEL_ENABLED" = "y" ] && echo "true" || echo "false")
    IMAGES_ENABLED=$([ "$DEFAULT_IMAGES_ENABLED" = "y" ] && echo "true" || echo "false")
    STYLEGUIDE="$DEFAULT_STYLEGUIDE"
}

# ============================================================
# SETUP STEPS
# ============================================================

check_environment() {
    local required="${1:-required}"
    print_step "$STEP_ENV" "$TOTAL_STEPS" "Environment check"

    if ! command -v opencode >/dev/null 2>&1; then
        if [ "$required" = "optional" ]; then
            print_warning "opencode CLI not found. Voice setup can continue; AI sample analysis will be unavailable."
            echo ""
            return 0
        fi
        print_error "opencode CLI not found."
        echo ""
        echo "Install opencode first:"
        echo "  npm install -g @opencode-ai/cli"
        echo ""
        echo "Docs: https://opencode.ai/docs/installation"
        exit 1
    fi

    print_success "opencode CLI found: $(opencode --version)"

    if AVAILABLE_MODELS=$(opencode models 2>/dev/null); then
        MODEL_DISCOVERY_STATUS="verified"
    else
        AVAILABLE_MODELS=""
        MODEL_DISCOVERY_STATUS="unverified"
    fi

    if [ -z "$AVAILABLE_MODELS" ]; then
        print_warning "Model availability could not be verified; setup will continue, but run 'opencode models' manually if generation later fails."
    else
        print_success "Found $(echo "$AVAILABLE_MODELS" | wc -l | xargs) available models"
    fi

    echo ""
}

check_existing_config() {
    print_step "$STEP_EXISTING" "$TOTAL_STEPS" "Existing setup"

    if [ ! -f "$CONFIG_FILE" ]; then
        SETUP_ACTION="new"
        print_success "No existing config found. Starting fresh."
        echo ""
        return 0
    fi

    print_warning "Existing configuration found at $CONFIG_FILE"
    echo ""
    echo "Choose how to proceed:"
    echo "  1) Update (keep current values as defaults)"
    echo "  2) Overwrite (start fresh)"
    echo "  3) Cancel"
    echo ""

    local choice
    choice=$(ask_choice "Choose an option" "1" "$(printf "1\n2\n3\n")")

    case "$choice" in
        1) SETUP_ACTION="update" ;;
        2) SETUP_ACTION="overwrite" ;;
        *) SETUP_ACTION="cancel" ;;
    esac

    echo ""
}

assign_models() {
    print_step "$STEP_MODELS" "$TOTAL_STEPS" "Model assignment"
    echo ""
    echo "Choose model assignment mode:"
    echo "  1) Smart defaults (recommended)"
    echo "  2) Custom per agent"
    echo ""

    local mode
    mode=$(ask_choice "Select mode" "1" "$(printf "1\n2\n")")

    if [ "$mode" = "2" ]; then
        assign_models_custom
    else
        assign_models_defaults
    fi
}

assign_models_defaults() {
    echo ""
    print_section "Using smart defaults:"
    echo "  Orchestrator:     $DEFAULT_ORCHESTRATOR"
    echo "  Writer agents:    ${DEFAULT_BLOG_WRITER:-$DEFAULT_WRITER}"
    echo "  Fast agents:      ${DEFAULT_EDITOR_LIGHT:-$DEFAULT_FAST}"
    echo "  Image creator:    ${DEFAULT_IMAGE_CREATOR:-$DEFAULT_IMAGE}"
    echo ""

    assign_model_vars_from_defaults
}

assign_models_custom() {
    echo ""
    print_section "Assign a model for each agent."
    print_hint "Use exact model ids from opencode models when available."
    echo ""

    if [ -n "$AVAILABLE_MODELS" ]; then
        echo "Available models:"
        echo "$AVAILABLE_MODELS" | head -20
        if [ "$(echo "$AVAILABLE_MODELS" | wc -l | xargs)" -gt 20 ]; then
            echo "... ($(echo "$AVAILABLE_MODELS" | wc -l | xargs) total)"
        fi
        echo ""
    fi

    ORCHESTRATOR_MODEL=$(ask_required "Orchestrator model" "$DEFAULT_ORCHESTRATOR")
    RESEARCHER_MODEL=$(ask_required "Researcher model" "${DEFAULT_RESEARCHER:-$DEFAULT_WRITER}")
    SEO_EXPERT_MODEL=$(ask_required "SEO Expert model" "${DEFAULT_SEO_EXPERT:-$DEFAULT_WRITER}")
    DIGITAL_TWIN_MODEL=$(ask_required "Digital Twin model" "${DEFAULT_DIGITAL_TWIN:-$DEFAULT_WRITER}")
    BLOG_WRITER_MODEL=$(ask_required "Blog Writer model" "${DEFAULT_BLOG_WRITER:-$DEFAULT_WRITER}")
    EDITOR_MODEL=$(ask_required "Editor model" "${DEFAULT_EDITOR:-$DEFAULT_WRITER}")
    IMAGE_CREATOR_MODEL=$(ask_required "Image Creator model" "${DEFAULT_IMAGE_CREATOR:-$DEFAULT_IMAGE}")
    REPURPOSER_MODEL=$(ask_required "Repurposer model" "${DEFAULT_REPURPOSER:-$DEFAULT_ORCHESTRATOR}")
    LINKEDIN_WRITER_MODEL=$(ask_required "LinkedIn Writer model" "${DEFAULT_LINKEDIN_WRITER:-$DEFAULT_FAST}")
    X_THREAD_WRITER_MODEL=$(ask_required "X Thread Writer model" "${DEFAULT_X_THREAD_WRITER:-$DEFAULT_FAST}")
    REEL_SCRIPT_WRITER_MODEL=$(ask_required "Reel Script Writer model" "${DEFAULT_REEL_SCRIPT_WRITER:-$DEFAULT_FAST}")
    EDITOR_LIGHT_MODEL=$(ask_required "Editor Light model" "${DEFAULT_EDITOR_LIGHT:-$DEFAULT_FAST}")
    REPORT_WRITER_MODEL=$(ask_required "Report Writer model" "${DEFAULT_REPORT_WRITER:-$DEFAULT_WRITER}")
    FEEDBACK_ARCHITECT_MODEL=$(ask_required "Feedback Architect model" "${DEFAULT_FEEDBACK_ARCHITECT:-$DEFAULT_ORCHESTRATOR}")
    HISTORY_LOGGER_MODEL=$(ask_required "History Logger model" "${DEFAULT_HISTORY_LOGGER:-$DEFAULT_FAST}")
    SETUP_ORCHESTRATOR_MODEL=$(ask_required "Setup Orchestrator model" "$DEFAULT_SETUP_ORCHESTRATOR")

    BLOG_ENABLED="true"
}

select_platforms_features() {
    print_step "$STEP_FEATURES" "$TOTAL_STEPS" "Platforms and features"
    echo ""
    echo "Blog is always enabled. Select additional output channels:"
    echo ""

    BLOG_ENABLED="true"
    LINKEDIN_ENABLED=$(ask_yes_no "Enable LinkedIn posts?" "$DEFAULT_LINKEDIN_ENABLED")
    X_ENABLED=$(ask_yes_no "Enable X/Twitter threads?" "$DEFAULT_X_ENABLED")
    REEL_ENABLED=$(ask_yes_no "Enable Reel scripts?" "$DEFAULT_REEL_ENABLED")
    echo ""
    IMAGES_ENABLED=$(ask_yes_no "Enable AI image generation for blog posts?" "$DEFAULT_IMAGES_ENABLED")
    echo ""
}

# ============================================================
# VOICE BUILDER
# ============================================================

set_voice_defaults() {
    BRAND_NAME="${BRAND_NAME:-Not provided}"
    BRAND_HANDLE="${BRAND_HANDLE:-Not provided}"
    BRAND_ROLE="${BRAND_ROLE:-Not provided}"
    BRAND_PROMISE="${BRAND_PROMISE:-Not provided}"
    BRAND_CATEGORY="${BRAND_CATEGORY:-Not provided}"
    AUDIENCE_PRIMARY="${AUDIENCE_PRIMARY:-Not provided}"
    AUDIENCE_LEVEL="${AUDIENCE_LEVEL:-Not provided}"
    AUDIENCE_PAINS="${AUDIENCE_PAINS:-Not provided}"
    READING_CONTEXT="${READING_CONTEXT:-Not provided}"
    POSITION_DEFENDS="${POSITION_DEFENDS:-Not provided}"
    POSITION_REJECTS="${POSITION_REJECTS:-Not provided}"
    CORE_TOPICS="${CORE_TOPICS:-Not provided}"
    VOICE_BOUNDARIES="${VOICE_BOUNDARIES:-Not provided}"
    SLIDER_CASUAL_FORMAL="${SLIDER_CASUAL_FORMAL:-3 - balanced}"
    SLIDER_TECHNICAL_NARRATIVE="${SLIDER_TECHNICAL_NARRATIVE:-3 - balanced}"
    SLIDER_DIRECT_EXPLANATORY="${SLIDER_DIRECT_EXPLANATORY:-3 - balanced}"
    SLIDER_WARM_CRITICAL="${SLIDER_WARM_CRITICAL:-3 - balanced}"
    SLIDER_SIMPLE_SOPHISTICATED="${SLIDER_SIMPLE_SOPHISTICATED:-3 - balanced}"
    SENTENCE_STYLE="${SENTENCE_STYLE:-Not provided}"
    PARAGRAPH_STYLE="${PARAGRAPH_STYLE:-Not provided}"
    BULLET_STYLE="${BULLET_STYLE:-Not provided}"
    HOOK_STYLE="${HOOK_STYLE:-Not provided}"
    CTA_STYLE="${CTA_STYLE:-Not provided}"
    HUMOR_STYLE="${HUMOR_STYLE:-Not provided}"
    METAPHOR_STYLE="${METAPHOR_STYLE:-Not provided}"
    PRIMARY_LANGUAGE="${PRIMARY_LANGUAGE:-Not provided}"
    BLOG_RULES="${BLOG_RULES:-Not provided}"
    LINKEDIN_RULES="${LINKEDIN_RULES:-Not provided}"
    X_RULES="${X_RULES:-Not provided}"
    REEL_RULES="${REEL_RULES:-Not provided}"
    FORBIDDEN_WORDS="${FORBIDDEN_WORDS:-None recorded yet}"
    FORBIDDEN_TONE="${FORBIDDEN_TONE:-None recorded yet}"
    FORBIDDEN_CLAIMS="${FORBIDDEN_CLAIMS:-None recorded yet}"
    DO_LIST="${DO_LIST:-Use the Brand Snapshot, Audience, Positioning, and Writing Mechanics as source of truth.}"
    DONT_LIST="${DONT_LIST:-Do not use forbidden language, unsupported claims, or a voice that conflicts with the calibration preview.}"
}

voice_section_completed() {
    local value="$1"
    [ "$value" != "__BACK__" ]
}

ask_slider() {
    local label="$1"
    local left="$2"
    local right="$3"
    echo "  1 = $left"
    echo "  3 = balanced"
    echo "  5 = $right"
    local answer
    answer=$(ask_choice "$label" "3" "$(printf "1\n2\n3\n4\n5\n")")
    case "$answer" in
        1) echo "1 - strongly $left" ;;
        2) echo "2 - somewhat $left" ;;
        3) echo "3 - balanced" ;;
        4) echo "4 - somewhat $right" ;;
        5) echo "5 - strongly $right" ;;
        *) echo "$answer" ;;
    esac
}

run_persona_wizard() {
    print_step "$STEP_VOICE" "$TOTAL_STEPS" "Voice Builder"
    echo ""
    print_section "This creates the Digital Twin memory that writers use to reproduce the user's voice."
    print_hint "The builder saves structured voice rules, not a hardcoded persona."
    echo ""

    if [ "$SETUP_ACTION" = "update" ] && [ -f "$VOICE_FILE" ]; then
        local keep_existing
        keep_existing=$(ask_yes_no "Keep existing Digital Twin memory?" "y")
        if [ "$keep_existing" = "true" ]; then
            VOICE_ACTION="preserve"
            print_success "Keeping existing voice memory at $VOICE_FILE"
            echo ""
            return 0
        fi
    fi

    VOICE_BUILDER_MODE="full"
    run_voice_builder
}

run_quick_voice_builder() {
    print_step "$STEP_VOICE" "$TOTAL_STEPS" "Quick Voice Builder"
    echo ""
    print_hint "Quick mode asks only the minimum needed to create a usable first voice profile."

    VOICE_BUILDER_MODE="quick"
    BRAND_NAME=$(ask_text "Brand/person name" "")
    BRAND_HANDLE=$(ask_text "Handle or public identifier" "$BRAND_NAME")
    BRAND_ROLE=$(ask_text "Role or one-line bio" "")
    BRAND_PROMISE=$(ask_text "Promise to the audience" "")
    BRAND_CATEGORY=$(ask_text "Category or niche" "")
    AUDIENCE_PRIMARY=$(ask_text "Primary audience" "")
    POSITION_DEFENDS=$(ask_text "One idea this voice strongly defends" "")
    POSITION_REJECTS=$(ask_text "One thing this voice refuses or avoids" "")
    PRIMARY_LANGUAGE=$(ask_text "Primary language (en/es/mixed)" "mixed")
    HOOK_STYLE=$(ask_text "Typical hook style" "Direct, specific, no hype")
    CTA_STYLE=$(ask_text "Typical CTA style" "Soft question or useful next step")
    FORBIDDEN_WORDS=$(ask_text "Forbidden words or cliches" "None recorded yet")

    local sample
    sample=$(ask_file_path "Optional writing sample path")
    if [ -n "$sample" ] && [ "$sample" != "__BACK__" ]; then
        if [ -f "$sample" ]; then
            SAMPLE_PATHS+=("$sample")
            analyze_samples
            maybe_run_ai_sample_analysis
        else
            print_warning "Sample file not found: $sample"
        fi
    fi

    set_voice_defaults
    print_voice_preview
    local confirmed
    confirmed=$(ask_yes_no "Save this quick voice profile?" "y")
    if [ "$confirmed" != "true" ]; then
        CALIBRATION_NOTES=$(ask_multiline "Add calibration notes before saving")
    fi
}

run_voice_builder() {
    local section=1
    local answer

    while [ "$section" -le "$VOICE_TOTAL_STEPS" ]; do
        case "$section" in
            1)
                print_substep "1" "$VOICE_TOTAL_STEPS" "Brand Snapshot"
                BRAND_NAME=$(ask_text "Name, brand, or public identity" "${BRAND_NAME:-}")
                BRAND_HANDLE=$(ask_text "Handle or short identifier" "${BRAND_HANDLE:-$BRAND_NAME}")
                BRAND_ROLE=$(ask_text "Role or one-line bio" "${BRAND_ROLE:-}")
                BRAND_PROMISE=$(ask_text "Promise to the audience" "${BRAND_PROMISE:-}")
                BRAND_CATEGORY=$(ask_text "Category or niche" "${BRAND_CATEGORY:-}")
                answer="$BRAND_CATEGORY"
                ;;
            2)
                print_substep "2" "$VOICE_TOTAL_STEPS" "Audience"
                AUDIENCE_PRIMARY=$(ask_text "Primary audience" "${AUDIENCE_PRIMARY:-}")
                echo "Audience technical level:"
                echo "  1) Beginner"
                echo "  2) Intermediate"
                echo "  3) Advanced"
                echo "  4) Mixed"
                answer=$(ask_choice "Choose level" "${AUDIENCE_LEVEL_CHOICE:-4}" "$(printf "1\n2\n3\n4\n")")
                case "$answer" in
                    1) AUDIENCE_LEVEL="Beginner" ;;
                    2) AUDIENCE_LEVEL="Intermediate" ;;
                    3) AUDIENCE_LEVEL="Advanced" ;;
                    4) AUDIENCE_LEVEL="Mixed" ;;
                    __BACK__) AUDIENCE_LEVEL="__BACK__" ;;
                esac
                AUDIENCE_PAINS=$(ask_text "Audience pains or tensions" "${AUDIENCE_PAINS:-}")
                READING_CONTEXT=$(ask_text "Where/when they read this content" "${READING_CONTEXT:-}")
                answer="$READING_CONTEXT"
                ;;
            3)
                print_substep "3" "$VOICE_TOTAL_STEPS" "Positioning"
                POSITION_DEFENDS=$(ask_text "What does this voice defend?" "${POSITION_DEFENDS:-}")
                POSITION_REJECTS=$(ask_text "What does this voice reject?" "${POSITION_REJECTS:-}")
                CORE_TOPICS=$(ask_text "Strong recurring topics" "${CORE_TOPICS:-}")
                VOICE_BOUNDARIES=$(ask_text "Boundaries or topics to avoid" "${VOICE_BOUNDARIES:-}")
                answer="$VOICE_BOUNDARIES"
                ;;
            4)
                print_substep "4" "$VOICE_TOTAL_STEPS" "Tone Sliders"
                SLIDER_CASUAL_FORMAL=$(ask_slider "Casual vs formal" "casual" "formal")
                SLIDER_TECHNICAL_NARRATIVE=$(ask_slider "Technical vs narrative" "technical" "narrative")
                SLIDER_DIRECT_EXPLANATORY=$(ask_slider "Direct vs explanatory" "direct" "explanatory")
                SLIDER_WARM_CRITICAL=$(ask_slider "Warm vs critical" "warm" "critical")
                SLIDER_SIMPLE_SOPHISTICATED=$(ask_slider "Simple vs sophisticated" "simple" "sophisticated")
                answer="$SLIDER_SIMPLE_SOPHISTICATED"
                ;;
            5)
                print_substep "5" "$VOICE_TOTAL_STEPS" "Writing Mechanics"
                SENTENCE_STYLE=$(ask_text "Sentence style" "${SENTENCE_STYLE:-}")
                PARAGRAPH_STYLE=$(ask_text "Paragraph style" "${PARAGRAPH_STYLE:-}")
                BULLET_STYLE=$(ask_text "Bullet/list style" "${BULLET_STYLE:-}")
                HOOK_STYLE=$(ask_text "Hook style" "${HOOK_STYLE:-}")
                CTA_STYLE=$(ask_text "CTA style" "${CTA_STYLE:-}")
                HUMOR_STYLE=$(ask_text "Humor style" "${HUMOR_STYLE:-}")
                METAPHOR_STYLE=$(ask_text "Metaphors or analogies" "${METAPHOR_STYLE:-}")
                PRIMARY_LANGUAGE=$(ask_text "Primary language (en/es/mixed)" "${PRIMARY_LANGUAGE:-mixed}")
                answer="$PRIMARY_LANGUAGE"
                ;;
            6)
                print_substep "6" "$VOICE_TOTAL_STEPS" "Platform Rules"
                BLOG_RULES=$(ask_text "Blog rules" "${BLOG_RULES:-}")
                LINKEDIN_RULES=$(ask_text "LinkedIn rules" "${LINKEDIN_RULES:-}")
                X_RULES=$(ask_text "X/Twitter rules" "${X_RULES:-}")
                REEL_RULES=$(ask_text "Reel script rules" "${REEL_RULES:-}")
                answer="$REEL_RULES"
                ;;
            7)
                print_substep "7" "$VOICE_TOTAL_STEPS" "Forbidden Patterns"
                FORBIDDEN_WORDS=$(ask_text "Forbidden words, phrases, or cliches" "${FORBIDDEN_WORDS:-}")
                FORBIDDEN_TONE=$(ask_text "Forbidden tone patterns" "${FORBIDDEN_TONE:-}")
                FORBIDDEN_CLAIMS=$(ask_text "Exaggerations or unsupported claims to avoid" "${FORBIDDEN_CLAIMS:-}")
                answer="$FORBIDDEN_CLAIMS"
                ;;
            8)
                print_substep "8" "$VOICE_TOTAL_STEPS" "Writing Samples"
                if collect_samples; then
                    answer="samples"
                else
                    answer="__BACK__"
                fi
                ;;
            9)
                print_substep "9" "$VOICE_TOTAL_STEPS" "Preview and Calibration"
                set_voice_defaults
                print_voice_preview
                local confirmed
                confirmed=$(ask_yes_no "Does this voice summary look right?" "y")
                if [ "$confirmed" = "__BACK__" ]; then
                    answer="__BACK__"
                elif [ "$confirmed" = "true" ]; then
                    answer="confirmed"
                else
                    CALIBRATION_NOTES=$(ask_multiline "What should be adjusted?")
                    answer="confirmed"
                fi
                ;;
        esac

        if [ "$answer" = "__BACK__" ]; then
            if [ "$section" -gt 1 ]; then
                section=$((section - 1))
            else
                print_warning "Already at the first voice section."
            fi
        else
            section=$((section + 1))
        fi
        echo ""
    done
}

collect_samples() {
    SAMPLE_PATHS=()
    local i
    local path

    for i in 1 2 3; do
        path=$(ask_file_path "Writing sample path #$i (optional)")
        if [ "$path" = "__BACK__" ]; then
            return 1
        fi
        if [ -z "$path" ]; then
            continue
        fi
        if [ -f "$path" ]; then
            SAMPLE_PATHS+=("$path")
            print_success "Queued sample: $path"
        else
            print_warning "Sample file not found: $path"
        fi
    done

    analyze_samples
    maybe_run_ai_sample_analysis
}

count_token_matches() {
    local file="$1"
    local pattern="$2"
    tr '[:upper:]' '[:lower:]' < "$file" | tr -cs '[:alpha:]' '\n' | grep -E "$pattern" | wc -l | xargs || true
}

detect_language() {
    local file="$1"
    local spanish
    local english

    spanish=$(count_token_matches "$file" '^(el|la|los|las|que|de|y|en|un|una|para|por|con|como|pero|porque|esto|esta|este|vos|tu)$')
    english=$(count_token_matches "$file" '^(the|and|you|of|to|in|is|for|with|that|this|it|we|i|but|because|your)$')

    if [ "$spanish" -gt 5 ] && [ "$english" -gt 5 ]; then
        echo "mixed"
    elif [ "$spanish" -gt "$english" ]; then
        echo "es"
    elif [ "$english" -gt "$spanish" ]; then
        echo "en"
    else
        echo "mixed"
    fi
}

top_words() {
    local file="$1"
    tr '[:upper:]' '[:lower:]' < "$file" \
        | tr -cs '[:alpha:]' '\n' \
        | grep -E '.{4,}' \
        | grep -Ev '^(this|that|with|from|your|have|will|just|para|como|pero|porque|esta|este|esto|todo|todos|toda|tambien|cuando|donde|their|there|then|than|they|them|what|when|where|como|cada|solo|sobre)$' \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -10 \
        | awk '{print "- " $2 " (" $1 ")"}' || true
}

first_non_empty_line() {
    awk 'NF { print; exit }' "$1"
}

analyze_samples() {
    if [ "${#SAMPLE_PATHS[@]}" -eq 0 ]; then
        SAMPLE_ANALYSIS="None recorded yet"
        return 0
    fi

    local analysis=""
    local sample
    for sample in "${SAMPLE_PATHS[@]}"; do
        local words lines paragraphs avg_line avg_paragraph questions bullets first_person second_person language hook repeated
        words=$(wc -w < "$sample" | xargs)
        lines=$(wc -l < "$sample" | xargs)
        paragraphs=$(awk 'BEGIN{p=0; inpara=0} NF{if(!inpara){p++; inpara=1}} !NF{inpara=0} END{print p+0}' "$sample")
        avg_line=$(awk 'NF{w+=NF; l++} END{if(l>0) printf "%.1f", w/l; else print "0"}' "$sample")
        avg_paragraph=$(awk 'BEGIN{p=0; w=0; inpara=0} NF{w+=NF; if(!inpara){p++; inpara=1}} !NF{inpara=0} END{if(p>0) printf "%.1f", w/p; else print "0"}' "$sample")
        questions=$(grep -o '?' "$sample" 2>/dev/null | wc -l | xargs || true)
        bullets=$(grep -E '^[[:space:]]*(-|\*|[0-9]+\.)' "$sample" 2>/dev/null | wc -l | xargs || true)
        first_person=$(count_token_matches "$sample" '^(i|me|my|mine|we|our|ours|yo|me|mi|mis|nosotros|nuestro|nuestra)$')
        second_person=$(count_token_matches "$sample" '^(you|your|yours|tu|tus|vos|usted|ustedes)$')
        language=$(detect_language "$sample")
        hook=$(first_non_empty_line "$sample")
        repeated=$(top_words "$sample")

        analysis="${analysis}### $(basename "$sample")
- Path: $sample
- Detected language: $language
- Words: $words
- Lines: $lines
- Paragraphs: $paragraphs
- Average words per non-empty line: $avg_line
- Average words per paragraph: $avg_paragraph
- Questions: $questions
- Bullet/list lines: $bullets
- First-person markers: $first_person
- Second-person markers: $second_person
- Sample hook: $(safe_value "$hook")
- Top repeated words:
${repeated:-  - None recorded yet}

"
    done

    SAMPLE_ANALYSIS="$analysis"
}

maybe_run_ai_sample_analysis() {
    if [ "${#SAMPLE_PATHS[@]}" -eq 0 ]; then
        return 0
    fi

    if ! command -v opencode >/dev/null 2>&1; then
        AI_ANALYSIS="None recorded yet"
        return 0
    fi

    local use_ai
    use_ai=$(ask_yes_no "Run optional AI-assisted sample analysis with opencode?" "n")
    if [ "$use_ai" != "true" ]; then
        AI_ANALYSIS="None recorded yet"
        return 0
    fi

    if ! opencode run --help >/dev/null 2>&1; then
        print_warning "opencode non-interactive run mode is unavailable. Continuing with local analysis."
        AI_ANALYSIS="None recorded yet"
        return 0
    fi

    local prompt="Analyze these writing samples for reusable voice, tone, rhythm, structure, forbidden patterns, and platform guidance. Return concise Markdown. Files: ${SAMPLE_PATHS[*]}"
    local output
    output=$(printf "%s\n" "$prompt" | opencode run 2>/dev/null || true)
    if [ -n "$output" ]; then
        AI_ANALYSIS="$output"
        print_success "AI-assisted analysis captured."
    else
        print_warning "AI-assisted analysis failed or returned empty output. Continuing with local analysis."
        AI_ANALYSIS="None recorded yet"
    fi
}

print_voice_preview() {
    echo ""
    print_section "Voice preview"
    echo "  Brand:       $(safe_value "${BRAND_NAME:-}") ($(safe_value "${BRAND_HANDLE:-}"))"
    echo "  Role:        $(safe_value "${BRAND_ROLE:-}")"
    echo "  Promise:     $(safe_value "${BRAND_PROMISE:-}")"
    echo "  Audience:    $(safe_value "${AUDIENCE_PRIMARY:-}")"
    echo "  Defends:     $(safe_value "${POSITION_DEFENDS:-}")"
    echo "  Rejects:     $(safe_value "${POSITION_REJECTS:-}")"
    echo "  Language:    $(safe_value "${PRIMARY_LANGUAGE:-}")"
    echo "  Hook style:  $(safe_value "${HOOK_STYLE:-}")"
    echo "  CTA style:   $(safe_value "${CTA_STYLE:-}")"
    echo "  Forbidden:   $(safe_none "${FORBIDDEN_WORDS:-}")"
    echo ""
}

maybe_backup_voice_profile() {
    if [ "$VOICE_ACTION" = "preserve" ]; then
        return 0
    fi
    if [ ! -f "$VOICE_FILE" ]; then
        return 0
    fi

    local create_backup
    create_backup=$(ask_yes_no "Create backup before overwriting $VOICE_FILE?" "y")
    if [ "$create_backup" = "true" ]; then
        backup_file "$VOICE_FILE"
    fi
}

write_voice_profile() {
    if [ "$VOICE_ACTION" = "preserve" ]; then
        print_success "Voice memory preserved."
        return 0
    fi

    set_voice_defaults
    maybe_backup_voice_profile

    local content
    content=$(cat << EOF
# Digital Twin Voice Memory

## Brand Snapshot
- Name: $(safe_value "$BRAND_NAME")
- Handle: $(safe_value "$BRAND_HANDLE")
- Role: $(safe_value "$BRAND_ROLE")
- Promise: $(safe_value "$BRAND_PROMISE")
- Category: $(safe_value "$BRAND_CATEGORY")
- Builder mode: $VOICE_BUILDER_MODE

## Audience
- Primary audience: $(safe_value "$AUDIENCE_PRIMARY")
- Technical level: $(safe_value "$AUDIENCE_LEVEL")
- Pain points: $(safe_value "$AUDIENCE_PAINS")
- Reading context: $(safe_value "$READING_CONTEXT")

## Positioning
- Defends: $(safe_value "$POSITION_DEFENDS")
- Rejects: $(safe_value "$POSITION_REJECTS")
- Strong topics: $(safe_value "$CORE_TOPICS")
- Boundaries: $(safe_value "$VOICE_BOUNDARIES")

## Voice Principles
- Lead with the promise and audience context before style.
- Preserve the stated positions even when changing platform or format.
- Prefer concrete claims, useful specificity, and direct language.
- Avoid generic AI phrasing, corporate filler, and unsupported hype.

## Tone Sliders
- Casual/Formal: $(safe_value "$SLIDER_CASUAL_FORMAL")
- Technical/Narrative: $(safe_value "$SLIDER_TECHNICAL_NARRATIVE")
- Direct/Explanatory: $(safe_value "$SLIDER_DIRECT_EXPLANATORY")
- Warm/Critical: $(safe_value "$SLIDER_WARM_CRITICAL")
- Simple/Sophisticated: $(safe_value "$SLIDER_SIMPLE_SOPHISTICATED")

## Writing Mechanics
- Sentence style: $(safe_value "$SENTENCE_STYLE")
- Paragraph style: $(safe_value "$PARAGRAPH_STYLE")
- Bullet style: $(safe_value "$BULLET_STYLE")
- Hook style: $(safe_value "$HOOK_STYLE")
- CTA style: $(safe_value "$CTA_STYLE")
- Humor style: $(safe_value "$HUMOR_STYLE")
- Metaphor style: $(safe_value "$METAPHOR_STYLE")
- Primary language: $(safe_value "$PRIMARY_LANGUAGE")

## Platform Rules
### Blog
$(safe_value "$BLOG_RULES")

### LinkedIn
$(safe_value "$LINKEDIN_RULES")

### X / Twitter
$(safe_value "$X_RULES")

### Reel
$(safe_value "$REEL_RULES")

## Do / Don't
### Do
$(safe_value "$DO_LIST")

### Don't
$(safe_value "$DONT_LIST")

## Forbidden Language
- Words or phrases: $(safe_none "$FORBIDDEN_WORDS")
- Tone patterns: $(safe_none "$FORBIDDEN_TONE")
- Exaggerations or claims: $(safe_none "$FORBIDDEN_CLAIMS")

## Sample Analysis
### Local analysis
$(safe_none "$SAMPLE_ANALYSIS")

### AI-assisted analysis
$(safe_none "$AI_ANALYSIS")

## Calibration Preview
- Brand: $(safe_value "$BRAND_NAME") ($(safe_value "$BRAND_HANDLE"))
- Audience: $(safe_value "$AUDIENCE_PRIMARY")
- Defends: $(safe_value "$POSITION_DEFENDS")
- Rejects: $(safe_value "$POSITION_REJECTS")
- Hook style: $(safe_value "$HOOK_STYLE")
- CTA style: $(safe_value "$CTA_STYLE")
- Calibration notes: $(safe_none "$CALIBRATION_NOTES")

## Evolution Log
- $(date +%Y-%m-%d): Voice profile created or refreshed via setup.sh ($VOICE_BUILDER_MODE mode).

## Voice Drift Detection
- Compare future drafts against Brand Snapshot, Positioning, Tone Sliders, Writing Mechanics, Forbidden Language, and Calibration Preview.
- Flag drift when content uses forbidden language, changes the audience, contradicts positioning, or adopts a tone outside the sliders.
- Update this memory only after explicit user approval.
EOF
)

    write_text_file "$VOICE_FILE" "$content"
    print_write_ready "Voice memory" "$VOICE_FILE"
}

# ============================================================
# STYLEGUIDE, WRITE PLAN, GENERATION
# ============================================================

select_styleguide() {
    print_step "$STEP_STYLEGUIDE" "$TOTAL_STEPS" "Styleguide"
    echo ""

    if [ "$SETUP_ACTION" = "update" ] && [ -f "$MEMORY_DIR/styleguide.md" ]; then
        local keep_existing
        keep_existing=$(ask_yes_no "Keep existing styleguide?" "y")
        if [ "$keep_existing" = "true" ]; then
            STYLEGUIDE="$DEFAULT_STYLEGUIDE"
            print_success "Keeping existing styleguide at $MEMORY_DIR/styleguide.md"
            echo ""
            return 0
        fi
    fi

    echo "Choose a styleguide:"
    echo "  1) Google for Developers (Full)"
    echo "  2) Google for Developers (Light)"
    echo "  3) Custom styleguide file"
    echo "  4) No styleguide, voice only"
    echo ""

    local choice
    choice=$(ask_choice "Select option" "4" "$(printf "1\n2\n3\n4\n")")

    case "$choice" in
        1)
            STYLEGUIDE="google-dev-full"
            STYLEGUIDE_SOURCE="$TEMPLATES_DIR/styleguide-google-dev-full.md"
            print_success "Google Dev styleguide (full) selected"
            ;;
        2)
            STYLEGUIDE="google-dev-light"
            STYLEGUIDE_SOURCE="$TEMPLATES_DIR/styleguide-google-dev-light.md"
            print_success "Google Dev styleguide (light) selected"
            ;;
        3)
            local custom_path
            custom_path=$(ask_file_path "Path to your styleguide file")
            if [ -f "$custom_path" ]; then
                STYLEGUIDE="custom"
                STYLEGUIDE_SOURCE="$custom_path"
                print_success "Custom styleguide selected"
            else
                print_warning "File not found: $custom_path"
                STYLEGUIDE="null"
            fi
            ;;
        *)
            STYLEGUIDE="null"
            print_success "No styleguide selected"
            ;;
    esac

    echo ""
}

write_styleguide() {
    if [ -z "$STYLEGUIDE_SOURCE" ]; then
        return 0
    fi

    copy_file "$STYLEGUIDE_SOURCE" "$MEMORY_DIR/styleguide.md"
    print_write_ready "Styleguide" "$MEMORY_DIR/styleguide.md"
}

show_write_plan() {
    print_step "$STEP_CONFIRM" "$TOTAL_STEPS" "Confirm writes"
    echo ""
    print_section "Files that may change:"

    if [ "$RUN_MODE" != "voice" ]; then
        echo "  Config:   $CONFIG_FILE"
        echo "  Agents:   $AGENTS_DIR/*.md"
        echo "  Memories: missing files from $TEMPLATES_DIR/memory/*-blank.md"
        echo "  Output:   $OUTPUT_DIR/ and .opencode/testing/checkpoint-transcripts/"
    fi

    if [ "$VOICE_ACTION" = "preserve" ] || [ "$RUN_MODE" = "technical" ]; then
        echo "  Voice:    preserved ($VOICE_FILE)"
    else
        echo "  Voice:    create/update $VOICE_FILE"
    fi

    if [ "${STYLEGUIDE:-null}" != "null" ]; then
        echo "  Style:    $MEMORY_DIR/styleguide.md"
    else
        echo "  Style:    none selected"
    fi

    echo ""
    print_section "Overwrite/preserve rules:"
    echo "  Existing agent definitions are re-rendered when render is enabled."
    echo "  Existing memory files are preserved unless they are the selected voice/styleguide target."
    echo "  In update mode, voice is preserved by default."
    echo "  Dry-run mode writes nothing."
    echo ""

    local proceed
    proceed=$(ask_yes_no "Proceed with this plan?" "y")
    if [ "$proceed" != "true" ]; then
        print_warning "Setup cancelled before writing files."
        exit 0
    fi
    echo ""
}

generate_config() {
    local content
    content=$(cat << EOF
version: "1.0.0"
project_name: "hello-writer"

models:
  orchestrator: "$ORCHESTRATOR_MODEL"
  researcher: "$RESEARCHER_MODEL"
  seo_expert: "$SEO_EXPERT_MODEL"
  digital_twin: "$DIGITAL_TWIN_MODEL"
  blog_writer: "$BLOG_WRITER_MODEL"
  editor: "$EDITOR_MODEL"
  image_creator: "$IMAGE_CREATOR_MODEL"
  repurposer: "$REPURPOSER_MODEL"
  linkedin_writer: "$LINKEDIN_WRITER_MODEL"
  x_thread_writer: "$X_THREAD_WRITER_MODEL"
  reel_script_writer: "$REEL_SCRIPT_WRITER_MODEL"
  editor_light: "$EDITOR_LIGHT_MODEL"
  report_writer: "$REPORT_WRITER_MODEL"
  feedback_architect: "$FEEDBACK_ARCHITECT_MODEL"
  history_logger: "$HISTORY_LOGGER_MODEL"
  setup_orchestrator: "$SETUP_ORCHESTRATOR_MODEL"

platforms:
  blog: true
  linkedin: $LINKEDIN_ENABLED
  x: $X_ENABLED
  reel: $REEL_ENABLED

features:
  digital_twin: true
  images: $IMAGES_ENABLED
  styleguide: "$STYLEGUIDE"

paths:
  output: "output/"
  config: "$CONFIG_FILE"
  agents: "$AGENTS_DIR/"
  memory: "$MEMORY_DIR/"
  templates: "$TEMPLATES_DIR/"
EOF
)

    write_text_file "$CONFIG_FILE" "$content"
    print_write_ready "Config" "$CONFIG_FILE"
}

render_agents() {
    print_section "Rendering agent definitions"
    ensure_dir "$AGENTS_DIR"

    shopt -s nullglob
    local templates=("$TEMPLATES_DIR/agents/"*.template)
    shopt -u nullglob

    if [ "${#templates[@]}" -eq 0 ]; then
        print_error "No agent templates found in $TEMPLATES_DIR/agents/"
        echo "This usually means templates/agents was not included in the repository."
        exit 1
    fi

    local template
    for template in "${templates[@]}"; do
        local basename
        local target
        basename=$(basename "$template" .template)
        target="$AGENTS_DIR/$basename"

        if [ "$DRY_RUN" = "true" ]; then
            print_warning "DRY RUN would render: $target"
            continue
        fi

        cp "$template" "$target"
        sed_in_place "s|{{ORCHESTRATOR_MODEL}}|$ORCHESTRATOR_MODEL|g" "$target"
        sed_in_place "s|{{RESEARCHER_MODEL}}|$RESEARCHER_MODEL|g" "$target"
        sed_in_place "s|{{SEO_EXPERT_MODEL}}|$SEO_EXPERT_MODEL|g" "$target"
        sed_in_place "s|{{DIGITAL_TWIN_MODEL}}|$DIGITAL_TWIN_MODEL|g" "$target"
        sed_in_place "s|{{BLOG_WRITER_MODEL}}|$BLOG_WRITER_MODEL|g" "$target"
        sed_in_place "s|{{EDITOR_MODEL}}|$EDITOR_MODEL|g" "$target"
        sed_in_place "s|{{IMAGE_CREATOR_MODEL}}|$IMAGE_CREATOR_MODEL|g" "$target"
        sed_in_place "s|{{REPURPOSER_MODEL}}|$REPURPOSER_MODEL|g" "$target"
        sed_in_place "s|{{LINKEDIN_WRITER_MODEL}}|$LINKEDIN_WRITER_MODEL|g" "$target"
        sed_in_place "s|{{X_THREAD_WRITER_MODEL}}|$X_THREAD_WRITER_MODEL|g" "$target"
        sed_in_place "s|{{REEL_SCRIPT_WRITER_MODEL}}|$REEL_SCRIPT_WRITER_MODEL|g" "$target"
        sed_in_place "s|{{EDITOR_LIGHT_MODEL}}|$EDITOR_LIGHT_MODEL|g" "$target"
        sed_in_place "s|{{REPORT_WRITER_MODEL}}|$REPORT_WRITER_MODEL|g" "$target"
        sed_in_place "s|{{FEEDBACK_ARCHITECT_MODEL}}|$FEEDBACK_ARCHITECT_MODEL|g" "$target"
        sed_in_place "s|{{HISTORY_LOGGER_MODEL}}|$HISTORY_LOGGER_MODEL|g" "$target"
        sed_in_place "s|{{SETUP_ORCHESTRATOR_MODEL}}|$SETUP_ORCHESTRATOR_MODEL|g" "$target"

        if grep -q '{{[A-Z0-9_]*}}' "$target"; then
            print_error "Unresolved placeholder in $target"
            exit 1
        fi

        print_success "Rendered $basename"
    done
}

generate_memories() {
    print_section "Generating missing memory files"
    ensure_dir "$MEMORY_DIR"

    shopt -s nullglob
    local memory_templates=("$TEMPLATES_DIR/memory/"*-blank.md)
    shopt -u nullglob

    local mem_template
    for mem_template in "${memory_templates[@]}"; do
        local basename
        local target
        basename=$(basename "$mem_template" -blank.md)
        target="$MEMORY_DIR/$basename.memory.md"

        if [ "$basename" = "digital-twin" ] && will_write_voice_profile; then
            print_warning "Skipping digital-twin blank memory; Voice Builder will create $VOICE_FILE"
            continue
        fi

        if [ -f "$target" ]; then
            print_warning "$basename.memory.md already exists, preserving"
        else
            copy_file "$mem_template" "$target"
            if [ "$DRY_RUN" = "true" ]; then
                print_warning "DRY RUN verified plan for memory: $target"
            else
                print_success "Created $basename.memory.md"
            fi
        fi
    done
}

create_output_dir() {
    ensure_dir "$OUTPUT_DIR"
    ensure_dir ".opencode/testing/checkpoint-transcripts"

    if [ ! -f "$OUTPUT_DIR/_meta.md" ]; then
        local content
        content=$(cat << EOF
# hello-writer Output Metadata

- Created: $(date +%Y-%m-%d)
- Purpose: Root metadata for generated content sessions.
- Session folders: Use output/YYYY-MM-DD_topic-slug/.
EOF
)
        write_text_file "$OUTPUT_DIR/_meta.md" "$content"
    fi

    if [ "$DRY_RUN" = "true" ]; then
        print_warning "DRY RUN verified output directory plan"
    else
        print_success "Output directory ready"
    fi
}

write_project_files() {
    print_step "$STEP_GENERATE" "$TOTAL_STEPS" "Generate and validate"

    if [ "$RUN_MODE" = "voice" ]; then
        write_voice_profile
        return 0
    fi

    generate_config
    render_agents
    generate_memories
    write_styleguide

    if [ "$RUN_MODE" != "technical" ]; then
        write_voice_profile
    else
        print_success "Technical mode preserved existing voice memory."
    fi

    create_output_dir
}

validate_setup() {
    if [ "$DRY_RUN" = "true" ] && [ "$RUN_MODE" != "validate-only" ]; then
        print_warning "DRY RUN skipping validation of generated files because no files were written."
        return 0
    fi

    print_section "Validating configuration"
    local errors=0

    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Config file not found"
        errors=$((errors + 1))
    fi

    local expected_agents=(
        "orchestrator.md" "researcher.md" "seo-expert.md" "digital-twin.md"
        "blog-writer.md" "editor.md" "image-creator.md" "repurposer.md"
        "linkedin-writer.md" "x-thread-writer.md" "reel-script-writer.md"
        "editor-light.md" "report-writer.md" "feedback-architect.md"
        "history-logger.md" "setup-orchestrator.md"
    )

    local agent
    for agent in "${expected_agents[@]}"; do
        if [ ! -f "$AGENTS_DIR/$agent" ]; then
            print_error "Missing agent: $agent"
            errors=$((errors + 1))
        elif grep -q '{{[A-Z0-9_]*}}' "$AGENTS_DIR/$agent"; then
            print_error "Unresolved placeholder in agent: $agent"
            errors=$((errors + 1))
        fi
    done

    local agent_count
    agent_count=$(find "$AGENTS_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | xargs)
    if [ "$agent_count" -ne "${#expected_agents[@]}" ]; then
        print_error "Expected ${#expected_agents[@]} agent files, found $agent_count"
        errors=$((errors + 1))
    fi

    local expected_memories=(
        "researcher.memory.md" "seo-expert.memory.md" "digital-twin.memory.md"
        "blog-writer.memory.md" "editor.memory.md" "feedback-architect.memory.md"
        "history-logger.memory.md" "image-creator.memory.md"
        "linkedin-writer.memory.md" "x-thread-writer.memory.md"
        "reel-script-writer.memory.md"
    )

    local memory
    for memory in "${expected_memories[@]}"; do
        if [ ! -f "$MEMORY_DIR/$memory" ]; then
            print_error "Missing memory file: $memory"
            errors=$((errors + 1))
        fi
    done

    local memory_count
    memory_count=$(find "$MEMORY_DIR" -maxdepth 1 -name '*.memory.md' 2>/dev/null | wc -l | xargs)
    if [ "$memory_count" -ne "${#expected_memories[@]}" ]; then
        print_error "Expected ${#expected_memories[@]} memory files, found $memory_count"
        errors=$((errors + 1))
    fi

    if [ ! -f "$OUTPUT_DIR/_meta.md" ]; then
        print_error "Output metadata not found: $OUTPUT_DIR/_meta.md"
        errors=$((errors + 1))
    fi

    if [ -n "$AVAILABLE_MODELS" ]; then
        local models_to_check=(
            "$ORCHESTRATOR_MODEL" "$RESEARCHER_MODEL" "$SEO_EXPERT_MODEL"
            "$DIGITAL_TWIN_MODEL" "$BLOG_WRITER_MODEL" "$EDITOR_MODEL"
            "$IMAGE_CREATOR_MODEL" "$REPURPOSER_MODEL" "$LINKEDIN_WRITER_MODEL"
            "$X_THREAD_WRITER_MODEL" "$REEL_SCRIPT_WRITER_MODEL"
            "$EDITOR_LIGHT_MODEL" "$REPORT_WRITER_MODEL"
            "$FEEDBACK_ARCHITECT_MODEL" "$HISTORY_LOGGER_MODEL"
            "$SETUP_ORCHESTRATOR_MODEL"
        )

        local model
        for model in "${models_to_check[@]}"; do
            if ! echo "$AVAILABLE_MODELS" | grep -Fxq "$model"; then
                print_warning "Model may not be valid: $model"
            fi
        done
    else
        print_warning "Model availability not verified; file validation passed but model ids were not checked."
    fi

    if [ "$errors" -eq 0 ]; then
        print_success "All validations passed"
    else
        print_error "$errors validation error(s) found"
        exit 1
    fi
}

print_summary() {
    local title="${1:-Setup Complete}"
    local agent_count="0"

    if [ -d "$AGENTS_DIR" ]; then
        agent_count=$(find "$AGENTS_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | xargs)
    fi

    echo ""
    printf "%b\n" "${BOLD}${GREEN}============================================================${NC}"
    printf "%b\n" "${BOLD}${GREEN}  $title${NC}"
    printf "%b\n" "${BOLD}${GREEN}============================================================${NC}"
    echo ""
    printf "%-16s %s\n" "Mode" "$(mode_label)"
    printf "%-16s %s\n" "Dry run" "$DRY_RUN"
    printf "%-16s %s\n" "Config" "$CONFIG_FILE"
    printf "%-16s %s (%s agents)\n" "Agents" "$AGENTS_DIR/" "$agent_count"
    printf "%-16s %s\n" "Memory" "$MEMORY_DIR/"
    printf "%-16s %s\n" "Output" "$OUTPUT_DIR/"
    echo ""
    printf "%-16s %s\n" "Blog" "true"
    printf "%-16s %s\n" "LinkedIn" "${LINKEDIN_ENABLED:-false}"
    printf "%-16s %s\n" "X" "${X_ENABLED:-false}"
    printf "%-16s %s\n" "Reels" "${REEL_ENABLED:-false}"
    printf "%-16s %s\n" "Images" "${IMAGES_ENABLED:-false}"
    printf "%-16s %s\n" "Styleguide" "${STYLEGUIDE:-null}"
    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        printf "%b\n" "${YELLOW}${WARN_MARK}${NC} Dry run complete. No files were changed."
    fi
    echo ""
    echo "Next steps:"
    echo "  1. Review voice memory: $VOICE_FILE"
    echo "  2. Run: opencode"
    echo "  3. Ask: Run the content engine workflow to write a blog about [your topic]"
    echo ""
}

# ============================================================
# MODE RUNNERS
# ============================================================

run_render_only() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "$CONFIG_FILE not found. Run ./setup.sh first."
        exit 1
    fi

    load_existing_config_defaults
    assign_model_vars_from_defaults
    print_step "$STEP_RENDER" "$TOTAL_STEPS" "Render generated files"
    render_agents
    generate_memories
    create_output_dir
    print_step "$STEP_VALIDATE" "$TOTAL_STEPS" "Validate setup"
    validate_setup
    print_summary "Render Complete"
}

run_validate_only() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "$CONFIG_FILE not found. Run ./setup.sh first."
        exit 1
    fi

    load_existing_config_defaults
    assign_model_vars_from_defaults
    print_step "$STEP_VALIDATE" "$TOTAL_STEPS" "Validate setup"
    validate_setup
    print_summary "Validation Complete"
}

run_full_setup() {
    check_environment "required"
    check_existing_config

    if [ "$SETUP_ACTION" = "cancel" ]; then
        print_warning "Setup cancelled."
        exit 0
    fi

    if [ "$SETUP_ACTION" = "update" ]; then
        load_existing_config_defaults
    fi

    assign_models
    select_platforms_features
    run_persona_wizard
    select_styleguide
    show_write_plan
    write_project_files
    validate_setup
    print_summary "Setup Complete"
}

run_quick_setup() {
    check_environment "required"
    print_step "$STEP_EXISTING" "$TOTAL_STEPS" "Existing setup defaults"
    if [ -f "$CONFIG_FILE" ]; then
        SETUP_ACTION="update"
        load_existing_config_defaults
        print_warning "Existing config found. Quick mode will reuse it as defaults."
    else
        SETUP_ACTION="new"
        print_success "No existing config found. Quick mode will use defaults."
    fi
    echo ""

    assign_model_vars_from_defaults
    run_quick_voice_builder
    show_write_plan
    write_project_files
    validate_setup
    print_summary "Quick Setup Complete"
}

run_voice_only() {
    check_environment "optional"
    if [ -f "$CONFIG_FILE" ]; then
        SETUP_ACTION="update"
        load_existing_config_defaults
        assign_model_vars_from_defaults
    else
        assign_model_vars_from_defaults
    fi

    VOICE_BUILDER_MODE="voice-only"
    print_step "$STEP_VOICE" "$TOTAL_STEPS" "Voice Builder"
    run_voice_builder
    show_write_plan
    write_project_files

    local render_now
    render_now=$(ask_yes_no "Render agents now using existing config/defaults?" "n")
    if [ "$render_now" = "true" ]; then
        if [ ! -f "$CONFIG_FILE" ]; then
            print_warning "No config exists yet, so render was skipped."
        else
            render_agents
            generate_memories
            validate_setup
        fi
    fi

    print_summary "Voice Setup Complete"
}

run_technical_setup() {
    check_environment "required"
    check_existing_config

    if [ "$SETUP_ACTION" = "cancel" ]; then
        print_warning "Setup cancelled."
        exit 0
    fi

    if [ "$SETUP_ACTION" = "update" ]; then
        load_existing_config_defaults
    fi

    VOICE_ACTION="preserve"
    assign_models
    select_platforms_features
    select_styleguide
    show_write_plan
    write_project_files
    validate_setup
    print_summary "Technical Setup Complete"
}

parse_args() {
    local primary_set="false"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --help|-h)
                usage
                exit 0
                ;;
            --quick)
                if [ "$primary_set" = "true" ]; then print_error "Only one setup mode can be selected."; exit 1; fi
                RUN_MODE="quick"
                primary_set="true"
                ;;
            --voice)
                if [ "$primary_set" = "true" ]; then print_error "Only one setup mode can be selected."; exit 1; fi
                RUN_MODE="voice"
                primary_set="true"
                ;;
            --technical)
                if [ "$primary_set" = "true" ]; then print_error "Only one setup mode can be selected."; exit 1; fi
                RUN_MODE="technical"
                primary_set="true"
                ;;
            --render-only)
                if [ "$primary_set" = "true" ]; then print_error "Only one setup mode can be selected."; exit 1; fi
                RUN_MODE="render-only"
                primary_set="true"
                ;;
            --validate-only)
                if [ "$primary_set" = "true" ]; then print_error "Only one setup mode can be selected."; exit 1; fi
                RUN_MODE="validate-only"
                primary_set="true"
                ;;
            --dry-run)
                DRY_RUN="true"
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"
    configure_steps
    print_header

    case "$RUN_MODE" in
        render-only)
            check_environment "required"
            run_render_only
            ;;
        validate-only)
            check_environment "required"
            run_validate_only
            ;;
        quick)
            run_quick_setup
            ;;
        voice)
            run_voice_only
            ;;
        technical)
            run_technical_setup
            ;;
        *)
            run_full_setup
            ;;
    esac
}

main "$@"
