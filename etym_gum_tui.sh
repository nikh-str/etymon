#!/usr/bin/env bash
# Etymology Lookup TUI using Gum
# Requires: gum (https://github.com/charmbracelet/gum)
# Install: brew install gum (macOS) or go install github.com/charmbracelet/gum@latest

set -e

# Colors and styling
HEADER_COLOR="#FF6B9D"
ACCENT_COLOR="#C792EA"
SUCCESS_COLOR="#C3E88D"
ERROR_COLOR="#F07178"
#TODO: add fuzzy search

# Check if gum is installed
if ! command -v gum &> /dev/null; then
    echo "Error: gum is not installed"
    echo "Install it with: brew install gum"
    echo "Or visit: https://github.com/charmbracelet/gum"
    exit 1
fi

# Check if etymonline binary exists
if ! command -v etymonline &> /dev/null && [ ! -f "./target/release/etymonline" ] && [ ! -f "./target/debug/etymonline" ]; then
    gum style --foreground "$ERROR_COLOR" --bold "Error: etymonline binary not found"
    echo "Please build it first with: cargo build --release"
    exit 1
fi

# Determine which binary to use
if command -v etymonline &> /dev/null; then
    ETYM_BIN="etymonline"
elif [ -f "./target/release/etymonline" ]; then
    ETYM_BIN="./target/release/etymonline"
else
    ETYM_BIN="./target/debug/etymonline"
fi

# Get current terminal width
get_term_width() {
    if command -v tput > /dev/null 2>&1 && [ -n "$TERM" ]; then
        tput cols 2>/dev/null || echo 60
    else
        echo 60
    fi
}
TERM_WIDTH=$(get_term_width)
MAX_WIDTH=$((TERM_WIDTH > 60 ? 80 : TERM_WIDTH < 40 ? 40 : TERM_WIDTH))


# Display welcome banner
clear
gum style \
    --foreground "$HEADER_COLOR" \
    --border-foreground "$ACCENT_COLOR" \
    --border double \
    --align center \
    --width $MAX_WIDTH \
    --margin "1 2" \
    --padding "2 4" \
    "📚 Etymology Lookup" \
    "" \
    "Discover the origins and history of words" \
    "powered by EtymOnline.com"

# Main loop
while true; do
    # Choose mode
    MODE=$(gum choose \
        --header "What would you like to do?" \
        --header.foreground "$ACCENT_COLOR" \
        --cursor.foreground "$SUCCESS_COLOR" \
        "🔍 Look up a word" \
        "📜 Browse history" \
        "❓ Random word" \
        "🚪 Exit")

    case "$MODE" in
        "🔍 Look up a word")
            # Get word input
            WORD=$(gum input \
                --placeholder "Enter a word (e.g., viking, etymology, computer)..." \
                --prompt "→ " \
                --prompt.foreground "$ACCENT_COLOR" \
                --width 60)
            
            if [ -z "$WORD" ]; then
                gum style --foreground "$ERROR_COLOR" "No word entered. Please try again."
                sleep 2
                continue
            fi

            # Show spinner while fetching
            gum spin --spinner dot \
                --title "Fetching etymology for '$WORD'..." \
                --title.foreground "$ACCENT_COLOR" \
                -- sleep 0.5

            # Fetch etymology
            TEMP_FILE=$(mktemp)
            if $ETYM_BIN "$WORD" > "$TEMP_FILE" 2>&1; then
                clear
                
                # Display the result with nice formatting
                gum style \
                    --foreground "$SUCCESS_COLOR" \
                    --bold \
                    --border rounded \
                    --width "$MAX_WIDTH" \
                    --border-foreground "$ACCENT_COLOR" \
                    --padding "1 1" \
                    --margin "1 1" \
                    "✓ Found etymology for: $WORD"
                
                # Display the etymology content
                gum style \
                    --border rounded \
                    --border-foreground "$HEADER_COLOR" \
                    --width "$MAX_WIDTH" \
                    --padding "2 3" \
                    --margin "1 0" \
                    "$(cat "$TEMP_FILE")"
                
                # Save to history
                echo "$(date '+%Y-%m-%d %H:%M:%S') - $WORD" >> ~/.etym_history 2>/dev/null || true
                
                # Options after viewing
                echo ""
                ACTION=$(gum choose \
                    --header "Options:" \
                    --cursor.foreground "$SUCCESS_COLOR" \
                    "↩️  Back to menu" \
                    "🔍 Look up another word" \
                    "🚪 Exit")
                
                case "$ACTION" in
                    "🔍 Look up another word")
                        continue
                        ;;
                    "🚪 Exit")
                        rm -f "$TEMP_FILE"
                        gum style --foreground "$SUCCESS_COLOR" "Thanks for using Etymology Lookup! 👋"
                        exit 0
                        ;;
                    *)
                        clear
                        ;;
                esac
            else
                clear
                gum style \
                    --foreground "$ERROR_COLOR" \
                    --bold \
                    --border rounded \
                    --border-foreground "$ERROR_COLOR" \
                    --padding "1 2" \
                    --margin "1 0" \
                    "✗ Error: Could not find etymology for '$WORD'"
                
                gum style \
                    --foreground 240 \
                    --margin "0 2" \
                    "$(cat "$TEMP_FILE" 2>/dev/null || echo 'Network error or word not found')"
                
                echo ""
                gum confirm "Try another word?" && continue || clear
            fi
            
            rm -f "$TEMP_FILE"
            ;;

        "📜 Browse history")
            if [ -f ~/.etym_history ]; then
                clear
                gum style \
                    --foreground "$HEADER_COLOR" \
                    --bold \
                    --margin "1 0" \
                    "📜 Recent Lookups"
                
                # Show last 20 entries
                HISTORY=$(tail -20 ~/.etym_history | tac)
                
                if [ -z "$HISTORY" ]; then
                    gum style --foreground 240 "No history yet. Look up some words!"
                else
                    SELECTED=$(echo "$HISTORY" | gum filter \
                        --placeholder "Search history..." \
                        --prompt "→ " \
                        --prompt.foreground "$ACCENT_COLOR")
                    
                    if [ -n "$SELECTED" ]; then
                        # Extract word from history line (format: "YYYY-MM-DD HH:MM:SS - word")
                        HISTORY_WORD=$(echo "$SELECTED" | awk -F' - ' '{print $2}')
                        
                        gum spin --spinner dot \
                            --title "Fetching etymology for '$HISTORY_WORD'..." \
                            -- sleep 0.5
                        
                        TEMP_FILE=$(mktemp)
                        if $ETYM_BIN "$HISTORY_WORD" > "$TEMP_FILE" 2>&1; then
                            clear
                            gum style \
                                --border rounded \
                                --border-foreground "$HEADER_COLOR" \
                                --padding "2 3" \
                                --margin "1 0" \
                                "$(cat "$TEMP_FILE")"
                            
                            echo ""
                            gum input --placeholder "Press Enter to continue..."
                        fi
                        rm -f "$TEMP_FILE"
                    fi
                fi
                
                echo ""
                gum input --placeholder "Press Enter to continue..."
                clear
            else
                gum style --foreground 240 "No history yet. Look up some words!"
                sleep 2
                clear
            fi
            ;;

        "❓ Random word")
            # List of interesting words to randomly select
            RANDOM_WORDS=(
                "serendipity" "etymology" "nostalgia" "ephemeral" "melancholy"
                "wanderlust" "petrichor" "solitude" "euphoria" "resilience"
                "viking" "algorithm" "robot" "quarantine" "salary"
                "panic" "enthusiasm" "music" "philosophy" "democracy"
            )
            
            RANDOM_WORD=${RANDOM_WORDS[$RANDOM % ${#RANDOM_WORDS[@]}]}
            
            gum style \
                --foreground "$ACCENT_COLOR" \
                --italic \
                "🎲 Random word: $RANDOM_WORD"
            
            gum spin --spinner dot \
                --title "Fetching etymology..." \
                -- sleep 0.5
            
            TEMP_FILE=$(mktemp)
            if $ETYM_BIN "$RANDOM_WORD" > "$TEMP_FILE" 2>&1; then
                clear
                gum style \
                    --border rounded \
                    --border-foreground "$HEADER_COLOR" \
                    --padding "2 3" \
                    --margin "1 0" \
                    "$(cat "$TEMP_FILE")"
                
                echo "$(date '+%Y-%m-%d %H:%M:%S') - $RANDOM_WORD" >> ~/.etym_history 2>/dev/null || true
                
                echo ""
                gum input --placeholder "Press Enter to continue..."
            fi
            rm -f "$TEMP_FILE"
            clear
            ;;

        "🚪 Exit")
            clear
            gum style \
                --foreground "$SUCCESS_COLOR" \
                --bold \
                --align center \
                "Thanks for using Etymology Lookup! 👋"
            echo ""
            exit 0
            ;;
    esac
done
