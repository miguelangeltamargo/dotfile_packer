#!/bin/bash

# ============================================
# Dotfile Management Script for Mac
# ============================================
# This script helps you backup and restore your
# development environment configurations between Macs
#
# Features:
# - Only backs up CUSTOM configs (not entire frameworks)
# - Creates backup in CURRENT DIRECTORY where you run the command
# - Uses standard macOS config locations
#
# Usage:
#   cd ~/wherever/you/want
#   bash /path/to/manage_dotfiles.sh
#   (Backup will be created at ~/wherever/you/want/dotfiles_backup)
# ============================================

# --- Configuration ---
# Get the current working directory (where the command is run from)
SCRIPT_DIR="$(pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles_backup"

# Obsidian Vault candidate locations (relative to $HOME)
OBSIDIAN_VAULT_LOCATIONS=(
  "Documents/Obsidian Vault"
  "Library/Mobile Documents/com~apple~CloudDocs/Notes/Obsidian Vault"
)
OBSIDIAN_CONFIG_BACKUP_DIR="$DOTFILES_DIR/obsidian_config"
OBSIDIAN_VAULT_SOURCE_FILE="$DOTFILES_DIR/obsidian_vault_location.txt"

# List of files and directories to manage
# These are CUSTOM configs only - frameworks should be installed fresh
CONFIG_ITEMS=(
  # Neovim configuration (custom configs only)
  ".config/nvim/init.lua"
  ".config/nvim/lua"
  ".config/nvim/lazy-lock.json"

  # Ghostty terminal configurations (check both possible locations)
  "Library/Application Support/com.mitchellh.ghostty/config"
  ".config/ghostty/config"

  # Shell configurations (custom configs only)
  ".zshrc"
  ".zprofile"
  ".zshenv"
  ".bashrc"
  ".bash_profile"

  # Oh My Zsh - ONLY custom themes and .zsh files (NOT plugins - they often have .git)
  # Your .zshrc already lists which plugins to install
  ".oh-my-zsh/custom/themes"
  ".oh-my-zsh/custom/*.zsh"
  # Note: If you have truly custom plugins (ones YOU wrote), add them manually:
  # ".oh-my-zsh/custom/plugins/my-custom-plugin"

  # Common Oh My Zsh plugin config files
  ".p10k.zsh" # Powerlevel10k theme config
  ".fzf.zsh"  # FZF config
  ".fzf.bash" # FZF for bash

  # Tmux configuration (custom config only)
  ".tmux.conf"

  # Git configuration (custom config only)
  ".gitconfig"
  ".gitignore_global"

  # Optional: Add other custom configs as needed
  # ".config/alacritty/alacritty.yml"
  # ".vimrc"
  # ".config/starship.toml"
  # ".ssh/config" (be careful with SSH keys!)
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------------------

# Function to print colored output
print_message() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Function to clean up .git directories from backup
cleanup_git_dirs() {
  print_message "$YELLOW" "\n🧹 Cleaning up .git directories from backup..."

  local git_count=0

  # Find and remove all .git directories in the backup
  while IFS= read -r -d '' git_dir; do
    rm -rf "$git_dir"
    print_message "$GREEN" "✓ Removed: ${git_dir#$DOTFILES_DIR/}"
    ((git_count++))
  done < <(find "$DOTFILES_DIR" -name ".git" -type d -print0 2>/dev/null)

  if [ $git_count -eq 0 ]; then
    print_message "$GREEN" "✓ No .git directories found - backup is clean!"
  else
    print_message "$GREEN" "✓ Removed $git_count .git directories"
  fi
}

# Function to wipe/delete the entire backup folder
wipe_backup() {
  print_message "$BLUE" "\n=== Wipe Backup Folder ==="
  print_message "$YELLOW" "This will DELETE the entire backup folder at:"
  print_message "$RED" "$DOTFILES_DIR"
  echo ""

  if [ ! -d "$DOTFILES_DIR" ]; then
    print_message "$YELLOW" "No backup folder found. Nothing to delete."
    return
  fi

  # Show what's in the backup
  print_message "$YELLOW" "Current backup contains:"
  du -sh "$DOTFILES_DIR" 2>/dev/null
  echo ""

  # Double confirmation
  print_message "$RED" "⚠️  WARNING: This action cannot be undone!"
  read -p "Are you absolutely sure you want to delete the backup? [yes/NO]: " confirm1

  if [[ ! $confirm1 == "yes" ]]; then
    print_message "$YELLOW" "Wipe cancelled. Backup preserved."
    return
  fi

  read -p "Type 'DELETE' to confirm: " confirm2

  if [[ $confirm2 == "DELETE" ]]; then
    print_message "$YELLOW" "\nDeleting backup folder..."
    rm -rf "$DOTFILES_DIR"
    print_message "$GREEN" "✓ Backup folder deleted successfully!"
    print_message "$BLUE" "\nYou can now create a fresh backup."
  else
    print_message "$YELLOW" "Wipe cancelled. Backup preserved."
  fi
}

# Function to backup Obsidian .obsidian config folder from within the vault
backup_obsidian_config() {
  print_message "$BLUE" "\n=== Backing Up Obsidian Configuration ==="

  local found_vault_path=""

  for rel_path in "${OBSIDIAN_VAULT_LOCATIONS[@]}"; do
    local candidate="$HOME/$rel_path"
    if [ -d "$candidate" ]; then
      found_vault_path="$candidate"
      print_message "$GREEN" "✓ Found Obsidian Vault at: $candidate"
      break
    else
      print_message "$YELLOW" "⊘ Not found at: $candidate"
    fi
  done

  if [ -z "$found_vault_path" ]; then
    print_message "$YELLOW" "⊘ Obsidian Vault not found in any known location, skipping."
    return
  fi

  local obsidian_config_source="$found_vault_path/.obsidian"
  if [ ! -d "$obsidian_config_source" ]; then
    print_message "$YELLOW" "⊘ .obsidian config folder not found in vault, skipping."
    return
  fi

  mkdir -p "$OBSIDIAN_CONFIG_BACKUP_DIR"

  print_message "$YELLOW" "Backing up .obsidian config from: $obsidian_config_source"
  if rsync -av --progress "$obsidian_config_source/" "$OBSIDIAN_CONFIG_BACKUP_DIR/" >/dev/null 2>&1; then
    # Save the vault location so restore knows where it came from
    echo "$found_vault_path" > "$OBSIDIAN_VAULT_SOURCE_FILE"
    print_message "$GREEN" "✓ Obsidian config backed up successfully"
    print_message "$BLUE" "  From: $obsidian_config_source"
  else
    print_message "$RED" "✗ Failed to backup Obsidian config"
  fi
  echo ""
}

# Function to restore Obsidian .obsidian config folder to the chosen vault
restore_obsidian_config() {
  print_message "$BLUE" "\n=== Restoring Obsidian Configuration ==="

  if [ ! -d "$OBSIDIAN_CONFIG_BACKUP_DIR" ]; then
    print_message "$YELLOW" "⊘ No Obsidian config backup found, skipping."
    return
  fi

  # Show the original source if recorded
  if [ -f "$OBSIDIAN_VAULT_SOURCE_FILE" ]; then
    local original_source
    original_source=$(cat "$OBSIDIAN_VAULT_SOURCE_FILE")
    print_message "$YELLOW" "Original vault location: $original_source"
  fi

  echo ""
  print_message "$GREEN" "Which vault would you like to restore the Obsidian config to?"
  local i=1
  for rel_path in "${OBSIDIAN_VAULT_LOCATIONS[@]}"; do
    echo "  [$i] $HOME/$rel_path"
    ((i++))
  done
  echo "  [S] Skip - do not restore Obsidian config"
  echo ""
  read -p "Enter your choice [1-${#OBSIDIAN_VAULT_LOCATIONS[@]}/S]: " config_choice

  if [[ "$config_choice" =~ ^[Ss]$ ]]; then
    print_message "$YELLOW" "Skipping Obsidian config restore."
    return
  fi

  local idx=$((config_choice - 1))
  if [[ "$config_choice" =~ ^[0-9]+$ ]] && [ "$idx" -ge 0 ] && [ "$idx" -lt "${#OBSIDIAN_VAULT_LOCATIONS[@]}" ]; then
    local restore_vault_path="$HOME/${OBSIDIAN_VAULT_LOCATIONS[$idx]}"
  else
    print_message "$RED" "Invalid choice. Skipping Obsidian config restore."
    return
  fi

  local restore_dest="$restore_vault_path/.obsidian"

  if [ ! -d "$restore_vault_path" ]; then
    print_message "$RED" "✗ Vault not found at: $restore_vault_path"
    return
  fi

  print_message "$YELLOW" "Restoring Obsidian config to: $restore_dest"
  mkdir -p "$restore_dest"

  if rsync -av --progress "$OBSIDIAN_CONFIG_BACKUP_DIR/" "$restore_dest/" >/dev/null 2>&1; then
    print_message "$GREEN" "✓ Obsidian config restored successfully to: $restore_dest"
  else
    print_message "$RED" "✗ Failed to restore Obsidian config"
  fi
  echo ""
}

# Function to backup files FROM home to the dotfiles directory
backup_dotfiles() {
  print_message "$BLUE" "\n=== Starting Backup Process ==="
  print_message "$YELLOW" "Script location: $SCRIPT_DIR"
  print_message "$YELLOW" "Backing up dotfiles to: $DOTFILES_DIR\n"

  # Create backup directory if it doesn't exist
  mkdir -p "$DOTFILES_DIR"

  local backup_count=0
  local skip_count=0

  for item in "${CONFIG_ITEMS[@]}"; do
    # Use absolute path from HOME
    source="$HOME/$item"
    destination="$DOTFILES_DIR/$item"

    if [ -e "$source" ]; then
      # Ensure destination directory exists
      mkdir -p "$(dirname "$destination")"

      # Use rsync for efficient and recursive copying
      print_message "$YELLOW" "Backing up: $item"

      # Check if source is a directory or file
      if [ -d "$source" ]; then
        # For directories, sync the contents
        if rsync -av --progress "$source/" "$destination/" >/dev/null 2>&1; then
          print_message "$GREEN" "✓ Successfully backed up: $item"
          ((backup_count++))
        else
          print_message "$RED" "✗ Failed to backup: $item"
        fi
      else
        # For files, copy the file itself
        if rsync -av --progress "$source" "$destination" >/dev/null 2>&1; then
          print_message "$GREEN" "✓ Successfully backed up: $item"
          ((backup_count++))
        else
          print_message "$RED" "✗ Failed to backup: $item"
        fi
      fi
    else
      print_message "$YELLOW" "⊘ Source not found, skipping: $item"
      ((skip_count++))
    fi
    echo ""
  done

  # Backup Obsidian config
  backup_obsidian_config

  # Clean up .git directories from backup
  cleanup_git_dirs

  print_message "$GREEN" "\n=== Backup Complete ==="
  print_message "$GREEN" "✓ Successfully backed up: $backup_count items"
  print_message "$YELLOW" "⊘ Skipped (not found): $skip_count items"
  print_message "$BLUE" "\nBackup location: $DOTFILES_DIR"
  print_message "$BLUE" "\n📦 To transfer to a new Mac:"
  echo "  1. Copy the 'dotfiles_backup' folder from this directory"
  echo "  2. On the new Mac, place it anywhere you want"
  echo "  3. cd into that directory and run this script with Restore"
  echo "  4. Install base frameworks first (oh-my-zsh, neovim, etc.)"
}

# Function to restore files FROM the dotfiles directory back to home
restore_dotfiles() {
  print_message "$BLUE" "\n=== Starting Restore Process ==="
  print_message "$YELLOW" "Script location: $SCRIPT_DIR"
  print_message "$YELLOW" "Restoring dotfiles from: $DOTFILES_DIR\n"

  # Check if backup directory exists
  if [ ! -d "$DOTFILES_DIR" ]; then
    print_message "$RED" "✗ Error: Backup directory not found at $DOTFILES_DIR"
    print_message "$YELLOW" "Please ensure 'dotfiles_backup' folder exists in your current directory."
    print_message "$YELLOW" "Current directory: $SCRIPT_DIR"
    exit 1
  fi

  local restore_count=0
  local skip_count=0

  # Ask for confirmation before restoring
  print_message "$YELLOW" "⚠ Warning: This will overwrite existing configuration files."
  read -p "Do you want to continue? [y/N]: " confirm

  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    print_message "$YELLOW" "Restore cancelled."
    exit 0
  fi

  echo ""

  for item in "${CONFIG_ITEMS[@]}"; do
    # Use absolute paths
    source="$DOTFILES_DIR/$item"
    destination="$HOME/$item"

    if [ -e "$source" ]; then
      # Ensure the parent directory in the home folder exists
      mkdir -p "$(dirname "$destination")"

      # Use rsync to restore files
      print_message "$YELLOW" "Restoring: $item"

      # Check if source is a directory or file
      if [ -d "$source" ]; then
        # For directories, sync the contents
        if rsync -av --progress "$source/" "$destination/" >/dev/null 2>&1; then
          print_message "$GREEN" "✓ Successfully restored: $item"
          ((restore_count++))
        else
          print_message "$RED" "✗ Failed to restore: $item"
        fi
      else
        # For files, copy to the parent directory
        if rsync -av --progress "$source" "$destination" >/dev/null 2>&1; then
          print_message "$GREEN" "✓ Successfully restored: $item"
          ((restore_count++))
        else
          print_message "$RED" "✗ Failed to restore: $item"
        fi
      fi
    else
      print_message "$YELLOW" "⊘ Backup file not found, skipping: $item"
      ((skip_count++))
    fi
    echo ""
  done

  # Restore Obsidian config
  restore_obsidian_config

  print_message "$GREEN" "\n=== Restore Complete ==="
  print_message "$GREEN" "✓ Successfully restored: $restore_count items"
  print_message "$YELLOW" "⊘ Skipped (not found in backup): $skip_count items"

  print_message "$BLUE" "\n📋 Next Steps:"
  echo "  1. Restart your terminal or run: source ~/.zshrc"
  echo "  2. If oh-my-zsh is not installed yet, run:"
  echo "     sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
  echo "  3. Open Neovim - plugins will auto-install on first launch"
  echo "  4. Verify Ghostty config is loaded"
}

# Function to display configuration summary
show_config() {
  print_message "$BLUE" "\n=== Current Configuration ==="
  print_message "$YELLOW" "Current Directory: $SCRIPT_DIR"
  print_message "$YELLOW" "Backup Will Be Saved To: $DOTFILES_DIR"
  print_message "$YELLOW" "User Home: $HOME"
  print_message "$YELLOW" "\nItems to be managed (CUSTOM configs only):"

  local found=0
  local missing=0

  for item in "${CONFIG_ITEMS[@]}"; do
    local full_path="$HOME/$item"
    if [ -e "$full_path" ]; then
      echo "  ✓ $item"
      ((found++))
    else
      echo "  ⊘ $item (not found)"
      ((missing++))
    fi
  done

  # Check for Obsidian config
  print_message "$YELLOW" "\nObsidian Configuration:"
  local obsidian_found=0
  for rel_path in "${OBSIDIAN_VAULT_LOCATIONS[@]}"; do
    local vault_path="$HOME/$rel_path"
    local obsidian_config="$vault_path/.obsidian"
    if [ -d "$obsidian_config" ]; then
      echo "  ✓ $rel_path/.obsidian"
      ((obsidian_found++))
      ((found++))
    else
      echo "  ⊘ $rel_path/.obsidian (not found)"
      ((missing++))
    fi
  done

  echo ""
  print_message "$GREEN" "Found: $found items"
  print_message "$YELLOW" "Missing: $missing items"
  echo ""
}

# Main script logic
clear
print_message "$BLUE" "╔════════════════════════════════════════╗"
print_message "$BLUE" "║   Dotfile Management Script for Mac   ║"
print_message "$BLUE" "╚════════════════════════════════════════╝"

echo ""
echo "This script backs up ONLY custom configs (not entire frameworks)."
echo "Backup will be saved in your CURRENT DIRECTORY."
echo ""
print_message "$YELLOW" "Current directory: $SCRIPT_DIR"
print_message "$YELLOW" "Backup location: $DOTFILES_DIR"
echo ""

# Main menu
while true; do
  print_message "$GREEN" "Select an action:"
  echo "  [B] Backup - Copy configs to backup folder"
  echo "  [R] Restore - Copy configs from backup folder to system"
  echo "  [C] Clean - Delete the entire backup folder (fresh start)"
  echo "  [S] Show - Display current configuration"
  echo "  [Q] Quit"
  echo ""
  read -p "Enter your choice [B/R/C/S/Q]: " choice

  case "$choice" in
  [Bb]*)
    backup_dotfiles
    break
    ;;
  [Rr]*)
    restore_dotfiles
    break
    ;;
  [Cc]*)
    wipe_backup
    ;;
  [Ss]*)
    show_config
    ;;
  [Qq]*)
    print_message "$YELLOW" "Exiting..."
    exit 0
    ;;
  *)
    print_message "$RED" "Invalid choice. Please enter B, R, C, S, or Q."
    echo ""
    ;;
  esac
done

print_message "$GREEN" "\n✨ All done!"
