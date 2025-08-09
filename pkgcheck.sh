#!/bin/bash

# Define the Packagefile path. Assuming it's in the same directory.
PACKAGE_FILE="Packagefile"

# Define the supported package types, their associated handler commands, and the check command.
# Format: "TYPE:HANDLER_COMMAND:PACKAGE_CHECK_COMMAND"
# PACKAGE_CHECK_COMMAND should use "$package" as a placeholder for the actual package name.
declare -a PACKAGE_TYPES_AND_COMMANDS=(
    "DPKG:dpkg:command -v \"\$package\"" # Changed to check if the command exists in PATH
    "FLATPAK:flatpak:flatpak info \"\$package\""
)

# Initialize an error flag
# A non-zero value will indicate that an error was found during checks
error_found=0

# Function to extract packages from a specific section of the Packagefile
# Arguments: $1 = section name (e.g., DPKG, FLATPAK)
extract_packages() {
    local section_name="$1"
    awk -v start_section="[${section_name}]" '
    BEGIN { in_section = 0 }
    /^\[.*\]/ { # Detect any section header
        if ($0 == start_section) {
            in_section = 1;
        } else {
            in_section = 0;
        }
        next; # Skip section header lines
    }
    in_section && !/^[[:space:]]*$/ && !/^[[:space:]]*#/ { # If in section, not blank, and not a comment
        print $1; # Print the first word (package name)
    }
    ' "$PACKAGE_FILE"
}

# General function to check packages for a given type
# Arguments:
# $1 = type_name (e.g., "DPKG", "FLATPAK")
# $2 = handler_command (e.g., "dpkg", "flatpak")
# $3 = package_check_command_template (e.g., "command -v \"\$package\"", "flatpak info \"\$package\"")
check_packages() {
    local type_name="$1"
    local handler_command="$2"
    local package_check_command_template="$3"

    echo "--- Checking ${type_name} Packages ---"

    # Extract packages for the current type into an array
    readarray -t packages_to_check < <(extract_packages "$type_name")

    if [[ ${#packages_to_check[@]} -eq 0 ]]; then
        # echo "No ${type_name} packages listed in $PACKAGE_FILE."
        return 0 # No packages, no error for this type
    fi

    # If there are packages, check if the handler command itself is available
    if ! command -v "$handler_command" &>/dev/null; then
        echo "  Error: '$handler_command' command not found. Ensure it is installed for managing ${type_name} packages." >&2
        error_found=1
        return 1 # Indicate error in this section, no need to check individual packages
    fi

    for package in "${packages_to_check[@]}"; do
        echo "Verifying ${type_name}: $package"
        # Construct the actual command by replacing "$package" placeholder
        # We use eval here because the command template contains shell variables to expand
        local actual_check_command="${package_check_command_template//\"\$package\"/\"$package\"}"

        # Execute the package check command
        if ! eval "$actual_check_command" &>/dev/null; then
            # Adjust error message based on type for better clarity
            if [[ "$type_name" == "DPKG" ]]; then
                echo "  Error: Required command '$package' not found in PATH." >&2
            else # For FLATPAK or any other type added later
                echo "  Error: ${type_name} package '$package' is not installed." >&2
            fi
            error_found=1
        else
            echo "  '$package' is installed."
        fi
    done
}


# --- Main Script Logic ---

# 1. If Packagefile isn't present, means no package dependencies; state that and return no error.
if [[ ! -f "$PACKAGE_FILE" ]]; then
    echo "Info: Packagefile '$PACKAGE_FILE' not found; no package dependencies listed."
    exit 0
fi

# Iterate through defined package types and call the general checking function
for type_info in "${PACKAGE_TYPES_AND_COMMANDS[@]}"; do
    # Split the string into type name, handler command, and package check command template
    IFS=':' read -r type_name handler_command package_check_command_template <<< "$type_info"

    # Call the general function to check packages for this type
    check_packages "$type_name" "$handler_command" "$package_check_command_template"
    echo "" # Blank line for separation between checks
done

# Return the internal error flag
if [[ "$error_found" -eq 1 ]]; then
    echo "pkgcheck.sh: Some required packages are missing. Install them before running application." >&2
    exit 1 # Indicate failure
else
    echo "pkgcheck.sh: All listed required packages are installed."
    exit 0 # Indicate success
fi

