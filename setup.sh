#!/usr/bin/env bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Paths
CONFIG_FILE="config/content-engine.yml"
AGENTS_DIR=".opencode/agents"
MEMORY_DIR=".opencode/agents/memory"
TEMPLATES_DIR="templates"
OUTPUT_DIR="output"

# Default models
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

# Detected models
AVAILABLE_MODELS=""
SETUP_ACTION="new"
RUN_MODE="full"

# ============================================================
# UTILITIES
# ============================================================

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}================================================${NC}"
    echo -e "${BOLD}${CYAN}  hello-writer Setup Wizard${NC}"
    echo -e "${BOLD}${CYAN}================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}[Step $1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

ask() {
    local prompt="$1"
    local default="$2"
    if [ -n "$default" ]; then
        read -rp "$(echo -e "${BOLD}$prompt${NC} [$default]: ")" answer
        if [ -z "$answer" ]; then
            answer="$default"
        fi
    else
        read -rp "$(echo -e "${BOLD}$prompt${NC}: ")" answer
    fi
    echo "$answer"
}

ask_yes_no() {
    local prompt="$1"
    local default="$2"
    while true; do
        local response
        response=$(ask "$prompt (y/n)" "$default")
        case "$response" in
            [Yy]* ) echo "true"; return ;;
            [Nn]* ) echo "false"; return ;;
            * ) echo -e "${YELLOW}Please answer y or n.${NC}" >&2 ;;
        esac
    done
}

usage() {
    cat << EOF
hello-writer setup

Usage:
  ./setup.sh                 Run the full interactive setup wizard
  ./setup.sh --render-only   Re-render .opencode/agents from existing config
  ./setup.sh --validate-only Validate generated config, agents, and memories
  ./setup.sh --help          Show this help
EOF
}

to_yn_default() {
    case "$1" in
        true|TRUE|yes|YES|y|Y) echo "y" ;;
        false|FALSE|no|NO|n|N) echo "n" ;;
        *) echo "$2" ;;
    esac
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

    LINKEDIN_ENABLED=$([ "$DEFAULT_LINKEDIN_ENABLED" = "y" ] && echo "true" || echo "false")
    X_ENABLED=$([ "$DEFAULT_X_ENABLED" = "y" ] && echo "true" || echo "false")
    REEL_ENABLED=$([ "$DEFAULT_REEL_ENABLED" = "y" ] && echo "true" || echo "false")
    IMAGES_ENABLED=$([ "$DEFAULT_IMAGES_ENABLED" = "y" ] && echo "true" || echo "false")
    STYLEGUIDE="$DEFAULT_STYLEGUIDE"
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

# ============================================================
# STEP 1: ENVIRONMENT CHECK
# ============================================================

check_environment() {
    print_step "1" "Checking environment..."
    
    if ! command -v opencode &> /dev/null; then
        print_error "opencode CLI not found."
        echo ""
        echo "Please install opencode first:"
        echo "  npm install -g @opencode-ai/cli"
        echo ""
        echo "Or visit: https://opencode.ai/docs/installation"
        exit 1
    fi
    
    print_success "opencode CLI found: $(opencode --version)"
    
    # Get available models
    AVAILABLE_MODELS=$(opencode models 2>/dev/null || true)
    if [ -z "$AVAILABLE_MODELS" ]; then
        print_warning "Could not fetch available models. Will validate manually later."
    else
        print_success "Found $(echo "$AVAILABLE_MODELS" | wc -l | xargs) available models"
    fi
    
    echo ""
}

# ============================================================
# STEP 2: DETECT EXISTING CONFIG
# ============================================================

check_existing_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        SETUP_ACTION="new"
        return 0
    fi
    
    echo -e "${YELLOW}Existing configuration found at $CONFIG_FILE${NC}"
    echo ""
    echo "What would you like to do?"
    echo "  1) Update (keep current values as defaults)"
    echo "  2) Overwrite (start fresh)"
    echo "  3) Cancel"
    echo ""
    
    local choice
    choice=$(ask "Choose an option" "1")
    
    case "$choice" in
        1)
            SETUP_ACTION="update"
            ;;
        2)
            SETUP_ACTION="overwrite"
            ;;
        *)
            SETUP_ACTION="cancel"
            ;;
    esac
}

# ============================================================
# STEP 3: MODEL ASSIGNMENT
# ============================================================

assign_models() {
    print_step "3" "Model Assignment"
    echo ""
    echo "Choose model assignment mode:"
    echo "  1) Smart defaults (Recommended)"
    echo "  2) Custom per agent"
    echo ""
    
    local mode
    mode=$(ask "Select mode" "1")
    
    if [ "$mode" = "2" ]; then
        assign_models_custom
    else
        assign_models_defaults
    fi
}

assign_models_defaults() {
    echo ""
    echo -e "${CYAN}Using smart defaults:${NC}"
    echo "  Orchestrator:     $DEFAULT_ORCHESTRATOR"
    echo "  Writer agents:    ${DEFAULT_BLOG_WRITER:-$DEFAULT_WRITER}"
    echo "  Fast agents:      ${DEFAULT_EDITOR_LIGHT:-$DEFAULT_FAST}"
    echo "  Image creator:    ${DEFAULT_IMAGE_CREATOR:-$DEFAULT_IMAGE}"
    echo ""

    assign_model_vars_from_defaults
}

assign_models_custom() {
    echo ""
    echo -e "${CYAN}Assign a model for each agent:${NC}"
    echo "(Available models will be shown if opencode is configured)"
    echo ""
    
    if [ -n "$AVAILABLE_MODELS" ]; then
        echo -e "${YELLOW}Available models:${NC}"
        echo "$AVAILABLE_MODELS" | head -20
        if [ "$(echo "$AVAILABLE_MODELS" | wc -l | xargs)" -gt 20 ]; then
            echo "... ($(echo "$AVAILABLE_MODELS" | wc -l | xargs) total)"
        fi
        echo ""
    fi
    
    ORCHESTRATOR_MODEL=$(ask "Orchestrator model" "$DEFAULT_ORCHESTRATOR")
    RESEARCHER_MODEL=$(ask "Researcher model" "${DEFAULT_RESEARCHER:-$DEFAULT_WRITER}")
    SEO_EXPERT_MODEL=$(ask "SEO Expert model" "${DEFAULT_SEO_EXPERT:-$DEFAULT_WRITER}")
    DIGITAL_TWIN_MODEL=$(ask "Digital Twin model" "${DEFAULT_DIGITAL_TWIN:-$DEFAULT_WRITER}")
    BLOG_WRITER_MODEL=$(ask "Blog Writer model" "${DEFAULT_BLOG_WRITER:-$DEFAULT_WRITER}")
    EDITOR_MODEL=$(ask "Editor model" "${DEFAULT_EDITOR:-$DEFAULT_WRITER}")
    IMAGE_CREATOR_MODEL=$(ask "Image Creator model" "${DEFAULT_IMAGE_CREATOR:-$DEFAULT_IMAGE}")
    REPURPOSER_MODEL=$(ask "Repurposer model" "${DEFAULT_REPURPOSER:-$DEFAULT_ORCHESTRATOR}")
    LINKEDIN_WRITER_MODEL=$(ask "LinkedIn Writer model" "${DEFAULT_LINKEDIN_WRITER:-$DEFAULT_FAST}")
    X_THREAD_WRITER_MODEL=$(ask "X Thread Writer model" "${DEFAULT_X_THREAD_WRITER:-$DEFAULT_FAST}")
    REEL_SCRIPT_WRITER_MODEL=$(ask "Reel Script Writer model" "${DEFAULT_REEL_SCRIPT_WRITER:-$DEFAULT_FAST}")
    EDITOR_LIGHT_MODEL=$(ask "Editor Light model" "${DEFAULT_EDITOR_LIGHT:-$DEFAULT_FAST}")
    REPORT_WRITER_MODEL=$(ask "Report Writer model" "${DEFAULT_REPORT_WRITER:-$DEFAULT_WRITER}")
    FEEDBACK_ARCHITECT_MODEL=$(ask "Feedback Architect model" "${DEFAULT_FEEDBACK_ARCHITECT:-$DEFAULT_ORCHESTRATOR}")
    HISTORY_LOGGER_MODEL=$(ask "History Logger model" "${DEFAULT_HISTORY_LOGGER:-$DEFAULT_FAST}")
    SETUP_ORCHESTRATOR_MODEL=$(ask "Setup Orchestrator model" "$DEFAULT_SETUP_ORCHESTRATOR")
}

# ============================================================
# STEP 4: PLATFORM SELECTION
# ============================================================

select_platforms() {
    print_step "4" "Platform Selection"
    echo ""
    echo "Blog is always enabled. Select additional platforms:"
    echo ""
    
    BLOG_ENABLED="true"
    LINKEDIN_ENABLED=$(ask_yes_no "Enable LinkedIn posts?" "$DEFAULT_LINKEDIN_ENABLED")
    X_ENABLED=$(ask_yes_no "Enable X/Twitter threads?" "$DEFAULT_X_ENABLED")
    REEL_ENABLED=$(ask_yes_no "Enable Reel scripts?" "$DEFAULT_REEL_ENABLED")
    
    echo ""
}

# ============================================================
# STEP 5: IMAGE GENERATION
# ============================================================

select_images() {
    print_step "5" "Image Generation"
    echo ""
    
    IMAGES_ENABLED=$(ask_yes_no "Enable AI image generation for blog posts?" "$DEFAULT_IMAGES_ENABLED")
    
    echo ""
}

# ============================================================
# STEP 6: DIGITAL TWIN PERSONA WIZARD
# ============================================================

run_persona_wizard() {
    print_step "6" "Digital Twin Persona Wizard (15 questions)"
    echo ""
    echo -e "${CYAN}This creates your voice profile. Writers will use it to sound like you.${NC}"
    echo ""

    if [ "$SETUP_ACTION" = "update" ] && [ -f "$MEMORY_DIR/digital-twin.memory.md" ]; then
        local keep_existing
        keep_existing=$(ask_yes_no "Keep existing Digital Twin profile?" "y")
        if [ "$keep_existing" = "true" ]; then
            print_success "Keeping existing persona at $MEMORY_DIR/digital-twin.memory.md"
            echo ""
            return
        fi
    fi
    
    local use_demo
    use_demo=$(ask_yes_no "Start with the demo persona (Alex Rivera) and customize?" "n")
    
    if [ "$use_demo" = "true" ]; then
        cp "$TEMPLATES_DIR/demo/digital-twin-demo.md" "$MEMORY_DIR/digital-twin.memory.md"
        echo ""
        echo -e "${GREEN}Demo persona copied. You can edit it later at:${NC}"
        echo "  $MEMORY_DIR/digital-twin.memory.md"
        echo ""
        
        local customize
        customize=$(ask_yes_no "Would you like to customize the demo persona now?" "n")
        
        if [ "$customize" = "true" ]; then
            ask_persona_questions
        fi
    else
        ask_persona_questions
    fi
}

ask_persona_questions() {
    mkdir -p "$MEMORY_DIR"
    
    echo -e "${BOLD}Answer the following questions. Press Enter to skip.${NC}"
    echo ""
    
    local name handle background journey belief personality stance blog_tone social_tone metaphors forbidden audience cta_style language sample1 sample2
    
    name=$(ask "Q1. Your name / handle" "")
    handle="$name"
    background=$(ask "Q2. Your professional background" "")
    journey=$(ask "Q3. Your journey (1-2 sentences)" "")
    belief=$(ask "Q4. Core belief or catchphrase" "")
    personality=$(ask "Q5. Describe your personality (3 words)" "")
    stance=$(ask "Q6. Stance on hustle culture" "")
    blog_tone=$(ask "Q7. Blog tone (educational/storytelling/technical/etc)" "")
    social_tone=$(ask "Q8. Social media tone (professional/casual/contrarian/etc)" "")
    metaphors=$(ask "Q9. Metaphors you gravitate toward" "")
    forbidden=$(ask "Q10. Words/phrases you NEVER use" "")
    audience=$(ask "Q11. How you address your audience" "")
    cta_style=$(ask "Q12. Typical CTA style" "")
    language=$(ask "Q13. Primary language (en/es/mixed)" "en")
    sample1=$(ask "Q14. Writing sample file path #1" "")
    sample2=$(ask "Q15. Writing sample file path #2" "")
    
    echo ""
    echo -e "${CYAN}Generating persona profile...${NC}"
    
    # Build the persona file
    cat > "$MEMORY_DIR/digital-twin.memory.md" << EOF
# Digital Twin Profile

## Identity
- Name: ${name:-Not provided}
- Handle: ${handle:-Not provided}
- Background: ${background:-Not provided}
- Journey: ${journey:-Not provided}
- Core belief: ${belief:-Not provided}

## Voice Core (Universal - All Platforms)
- Personality: ${personality:-Not provided}
- Core values: ${stance:-Not provided}
- Metaphor preferences: ${metaphors:-Not provided}
- Primary language: ${language:-en}

## Opinions & Stances
- ${stance:-Not provided}

## Voice by Platform

### Blog
- Tone: ${blog_tone:-Educational}

### LinkedIn
- Tone: ${social_tone:-Professional}

### X / Twitter
- Tone: ${social_tone:-Punchy}

### Reel Script
- Tone: ${social_tone:-Energetic}

## Signature Phrases
- Forbidden: ${forbidden:-None specified}
- Audience address: ${audience:-Friendly}
- CTA style: ${cta_style:-Question}

## Writing Samples
EOF
    
    if [ -n "$sample1" ] && [ -f "$sample1" ]; then
        echo "" >> "$MEMORY_DIR/digital-twin.memory.md"
        echo "### Sample 1" >> "$MEMORY_DIR/digital-twin.memory.md"
        cat "$sample1" >> "$MEMORY_DIR/digital-twin.memory.md"
        print_success "Added sample 1 from $sample1"
    elif [ -n "$sample1" ]; then
        print_warning "Sample 1 file not found: $sample1"
    fi
    
    if [ -n "$sample2" ] && [ -f "$sample2" ]; then
        echo "" >> "$MEMORY_DIR/digital-twin.memory.md"
        echo "### Sample 2" >> "$MEMORY_DIR/digital-twin.memory.md"
        cat "$sample2" >> "$MEMORY_DIR/digital-twin.memory.md"
        print_success "Added sample 2 from $sample2"
    elif [ -n "$sample2" ]; then
        print_warning "Sample 2 file not found: $sample2"
    fi
    
    echo "" >> "$MEMORY_DIR/digital-twin.memory.md"
    echo "## Evolution Log" >> "$MEMORY_DIR/digital-twin.memory.md"
    echo "- $(date +%Y-%m-%d): Initial profile created via setup wizard" >> "$MEMORY_DIR/digital-twin.memory.md"
    
    print_success "Persona profile saved to $MEMORY_DIR/digital-twin.memory.md"
    echo ""
}

# ============================================================
# STEP 7: STYLEGUIDE SELECTION
# ============================================================

select_styleguide() {
    print_step "7" "Styleguide Selection"
    echo ""

    if [ "$SETUP_ACTION" = "update" ] && [ -f "$MEMORY_DIR/styleguide.md" ]; then
        local keep_existing
        keep_existing=$(ask_yes_no "Keep existing styleguide?" "y")
        if [ "$keep_existing" = "true" ]; then
            STYLEGUIDE="$DEFAULT_STYLEGUIDE"
            print_success "Keeping existing styleguide at $MEMORY_DIR/styleguide.md"
            echo ""
            return
        fi
    fi

    echo "Choose a styleguide:"
    echo "  1) Google for Developers (Full)"
    echo "  2) Google for Developers (Light)"
    echo "  3) I'll provide my own styleguide file"
    echo "  4) No styleguide, voice only"
    echo ""
    
    local choice
    choice=$(ask "Select option" "4")
    
    case "$choice" in
        1)
            cp "$TEMPLATES_DIR/styleguide-google-dev-full.md" "$MEMORY_DIR/styleguide.md"
            STYLEGUIDE="google-dev-full"
            print_success "Google Dev styleguide (full) copied"
            ;;
        2)
            cp "$TEMPLATES_DIR/styleguide-google-dev-light.md" "$MEMORY_DIR/styleguide.md"
            STYLEGUIDE="google-dev-light"
            print_success "Google Dev styleguide (light) copied"
            ;;
        3)
            local custom_path
            custom_path=$(ask "Path to your styleguide file" "")
            if [ -f "$custom_path" ]; then
                cp "$custom_path" "$MEMORY_DIR/styleguide.md"
                STYLEGUIDE="custom"
                print_success "Custom styleguide copied from $custom_path"
            else
                print_error "File not found: $custom_path"
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

# ============================================================
# STEP 8: GENERATE CONFIG
# ============================================================

generate_config() {
    print_step "8" "Generating configuration..."
    
    mkdir -p config
    
    cat > "$CONFIG_FILE" << EOF
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
    
    print_success "Config written to $CONFIG_FILE"
    echo ""
}

# ============================================================
# STEP 9: RENDER AGENT TEMPLATES
# ============================================================

render_agents() {
    print_step "9" "Rendering agent definitions..."
    
    mkdir -p "$AGENTS_DIR"
    
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
        basename=$(basename "$template" .template)
        local target="$AGENTS_DIR/$basename"
        
        cp "$template" "$target"
        
        # Replace placeholders
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
    
    echo ""
}

# ============================================================
# STEP 10: GENERATE BLANK MEMORIES
# ============================================================

generate_memories() {
    print_step "10" "Generating blank memory files..."
    
    mkdir -p "$MEMORY_DIR"
    
    local mem_template
    for mem_template in "$TEMPLATES_DIR/memory/"*-blank.md; do
        local basename
        basename=$(basename "$mem_template" -blank.md)
        local target="$MEMORY_DIR/$basename.memory.md"
        
        if [ ! -f "$target" ]; then
            cp "$mem_template" "$target"
            print_success "Created $basename.memory.md"
        else
            print_warning "$basename.memory.md already exists, skipping"
        fi
    done
    
    echo ""
}

# ============================================================
# STEP 11: VALIDATION
# ============================================================

validate_setup() {
    print_step "11" "Validating configuration..."
    
    local errors=0
    
    # Validate config exists
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Config file not found"
        errors=$((errors + 1))
    fi
    
    # Validate all agents rendered
    local expected_agents=(
        "orchestrator.md" "researcher.md" "seo-expert.md" "digital-twin.md"
        "blog-writer.md" "editor.md" "image-creator.md" "repurposer.md"
        "linkedin-writer.md" "x-thread-writer.md" "reel-script-writer.md"
        "editor-light.md" "report-writer.md" "feedback-architect.md"
        "history-logger.md" "setup-orchestrator.md"
    )
    
    for agent in "${expected_agents[@]}"; do
        if [ ! -f "$AGENTS_DIR/$agent" ]; then
            print_error "Missing agent: $agent"
            errors=$((errors + 1))
        elif grep -q '{{[A-Z0-9_]*}}' "$AGENTS_DIR/$agent"; then
            print_error "Unresolved placeholder in agent: $agent"
            errors=$((errors + 1))
        fi
    done

    local expected_memories=(
        "researcher.memory.md" "seo-expert.memory.md" "digital-twin.memory.md"
        "blog-writer.memory.md" "editor.memory.md" "feedback-architect.memory.md"
        "history-logger.memory.md" "image-creator.memory.md"
        "linkedin-writer.memory.md" "x-thread-writer.memory.md"
        "reel-script-writer.memory.md"
    )

    for memory in "${expected_memories[@]}"; do
        if [ ! -f "$MEMORY_DIR/$memory" ]; then
            print_error "Missing memory file: $memory"
            errors=$((errors + 1))
        fi
    done
    
    # Validate models if we can
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
        
        for model in "${models_to_check[@]}"; do
            if ! echo "$AVAILABLE_MODELS" | grep -Fxq "$model"; then
                print_warning "Model may not be valid: $model"
            fi
        done
    fi
    
    if [ "$errors" -eq 0 ]; then
        print_success "All validations passed"
    else
        print_error "$errors validation error(s) found"
        exit 1
    fi
    
    echo ""
}

# ============================================================
# STEP 12: CREATE OUTPUT DIR
# ============================================================

create_output_dir() {
    print_step "12" "Creating output directory..."
    mkdir -p "$OUTPUT_DIR"
    mkdir -p ".opencode/testing/checkpoint-transcripts"
    if [ ! -f "$OUTPUT_DIR/_meta.md" ]; then
        cat > "$OUTPUT_DIR/_meta.md" << EOF
# hello-writer Output Metadata

- Created: $(date +%Y-%m-%d)
- Purpose: Root metadata for generated content sessions.
- Session folders: Use output/YYYY-MM-DD_topic-slug/.
EOF
    fi
    print_success "Output directory ready"
    echo ""
}

# ============================================================
# STEP 13: SUMMARY
# ============================================================

print_summary() {
    local title="${1:-Setup Complete!}"
    echo -e "${BOLD}${GREEN}================================================${NC}"
    echo -e "${BOLD}${GREEN}  $title${NC}"
    echo -e "${BOLD}${GREEN}================================================${NC}"
    echo ""
    echo -e "${BOLD}Configuration:${NC}"
    echo "  Config file:    $CONFIG_FILE"
    echo "  Agents:         $AGENTS_DIR/ ($(ls "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | xargs) agents)"
    echo "  Memory:         $MEMORY_DIR/"
    echo "  Output:         $OUTPUT_DIR/"
    echo ""
    echo -e "${BOLD}Platforms enabled:${NC}"
    echo "  Blog:      yes (always)"
    echo "  LinkedIn:  $LINKEDIN_ENABLED"
    echo "  X:         $X_ENABLED"
    echo "  Reels:     $REEL_ENABLED"
    echo ""
    echo -e "${BOLD}Features:${NC}"
    echo "  Images:    $IMAGES_ENABLED"
    echo "  Styleguide: $STYLEGUIDE"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Review your persona: $MEMORY_DIR/digital-twin.memory.md"
    echo "  2. Run the workflow:"
    echo -e "     ${CYAN}opencode${NC}"
    echo -e "     Then ask: ${CYAN}Run the content engine workflow to write a blog about [your topic]${NC}"
    echo ""
    echo -e "${BOLD}To reconfigure:${NC}"
    echo -e "  ${CYAN}./setup.sh${NC}"
    echo ""
}

# ============================================================
# MAIN
# ============================================================

main() {
    case "${1:-}" in
        --help|-h)
            usage
            exit 0
            ;;
        --render-only)
            RUN_MODE="render-only"
            ;;
        --validate-only)
            RUN_MODE="validate-only"
            ;;
        "")
            RUN_MODE="full"
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac

    print_header
    
    # Step 1: Environment check
    check_environment

    if [ "$RUN_MODE" = "render-only" ] || [ "$RUN_MODE" = "validate-only" ]; then
        if [ ! -f "$CONFIG_FILE" ]; then
            print_error "$CONFIG_FILE not found. Run ./setup.sh first."
            exit 1
        fi

        load_existing_config_defaults
        assign_model_vars_from_defaults

        if [ "$RUN_MODE" = "render-only" ]; then
            render_agents
            generate_memories
            create_output_dir
        fi

        validate_setup
        if [ "$RUN_MODE" = "render-only" ]; then
            print_summary "Render Complete!"
        else
            print_summary "Validation Complete!"
        fi
        exit 0
    fi
    
    # Step 2: Check existing config
    check_existing_config
    
    if [ "$SETUP_ACTION" = "cancel" ]; then
        echo -e "${YELLOW}Setup cancelled.${NC}"
        exit 0
    fi

    if [ "$SETUP_ACTION" = "update" ]; then
        load_existing_config_defaults
    fi
    
    # Step 3: Model assignment
    assign_models
    
    # Step 4: Platform selection
    select_platforms
    
    # Step 5: Image generation
    select_images
    
    # Step 6: Digital twin wizard
    run_persona_wizard
    
    # Step 7: Styleguide
    select_styleguide
    
    # Step 8: Generate config
    generate_config
    
    # Step 9: Render agents
    render_agents
    
    # Step 10: Generate memories
    generate_memories
    
    # Step 11: Validation
    validate_setup
    
    # Step 12: Create output dir
    create_output_dir
    
    # Step 13: Summary
    print_summary
}

main "$@"
