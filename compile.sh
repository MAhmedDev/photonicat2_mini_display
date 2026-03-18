#!/bin/bash
# Compile for Debian ARM64, then build the local host binary and tests

set -e

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}PhotoniCat2 Display Build Script${NC}"
echo "======================================"

# Function to check if command exists
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "  ✓ ${GREEN}$1 found${NC}"
        return 0
    else
        echo -e "  ✗ ${RED}$1 not found${NC}"
        return 1
    fi
}

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "  ✓ ${GREEN}$1 exists${NC}"
        return 0
    else
        echo -e "  ✗ ${RED}$1 not found${NC}"
        return 1
    fi
}

# Function to check if directory exists
check_directory() {
    if [ -d "$1" ]; then
        echo -e "  ✓ ${GREEN}$1 exists${NC}"
        return 0
    else
        echo -e "  ✗ ${RED}$1 not found${NC}"
        return 1
    fi
}

echo -e "\n${YELLOW}1. Checking host system...${NC}"

# Detect host architecture
HOST_ARCH=$(uname -m)
echo "Host architecture: $HOST_ARCH"

# Check if we're on x86_64 (required for cross-compilation)
if [ "$HOST_ARCH" != "x86_64" ]; then
    echo -e "${YELLOW}Warning: This script is optimized for x86_64 hosts doing cross-compilation.${NC}"
    echo -e "${YELLOW}You're on $HOST_ARCH - compilation may work but paths might need adjustment.${NC}"
fi

echo -e "\n${YELLOW}2. Checking required tools...${NC}"

# Check basic tools
missing_tools=0

if ! check_command "go"; then
    echo -e "${RED}Go is required for compilation.${NC}"
    echo -e "Install with: ${BLUE}wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz && sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz${NC}"
    echo -e "Then add to PATH: ${BLUE}export PATH=\$PATH:/usr/local/go/bin${NC}"
    missing_tools=1
else
    go_version=$(go version 2>/dev/null || echo "unknown")
    echo "    Go version: $go_version"
fi

if ! check_command "git"; then
    echo -e "${RED}Git is required for version information.${NC}"
    echo -e "Install with: ${BLUE}sudo apt install git${NC}"
    missing_tools=1
fi

# Check build tools for the current host
if [ "$HOST_ARCH" = "x86_64" ]; then
    echo -e "\n${YELLOW}3. Checking cross-compilation tools...${NC}"

    if ! check_command "aarch64-linux-gnu-gcc"; then
        echo -e "${RED}aarch64-linux-gnu-gcc is required for Debian ARM64 builds.${NC}"
        echo -e "Install with: ${BLUE}sudo apt install gcc-aarch64-linux-gnu${NC}"
        missing_tools=1
    fi
else
    echo -e "\n${YELLOW}3. Native compilation mode (aarch64 host)${NC}"

    if ! check_command "gcc"; then
        echo -e "${RED}gcc is required for native compilation.${NC}"
        echo -e "Install with: ${BLUE}sudo apt install gcc${NC}"
        missing_tools=1
    fi
fi

if ! check_command "pkg-config"; then
    echo -e "${YELLOW}pkg-config recommended for build process.${NC}"
    echo -e "Install with: ${BLUE}sudo apt install pkg-config${NC}"
fi

echo -e "\n${YELLOW}4. Checking project files...${NC}"

# Check required project files
if ! check_file "go.mod"; then
    echo -e "${RED}go.mod not found. Make sure you're in the project root directory.${NC}"
    missing_tools=1
fi

if ! check_file "main.go"; then
    echo -e "${RED}main.go not found. Make sure you're in the project root directory.${NC}"
    missing_tools=1
fi

if ! check_file "config.json"; then
    echo -e "${YELLOW}config.json not found. Build will continue but packaging may fail.${NC}"
fi

if ! check_directory "assets"; then
    echo -e "${YELLOW}assets directory not found. Build will continue but packaging may fail.${NC}"
fi

# Summary
echo -e "\n${YELLOW}5. Pre-build summary${NC}"

if [ $missing_tools -eq 1 ]; then
    echo -e "${RED}❌ Missing required tools or dependencies.${NC}"
    echo -e "\n${YELLOW}Quick install for Ubuntu/Debian x86_64:${NC}"
    echo -e "${BLUE}sudo apt update${NC}"
    echo -e "${BLUE}sudo apt install git gcc-aarch64-linux-gnu pkg-config${NC}"
    echo -e "\n${YELLOW}Quick install for Ubuntu/Debian aarch64:${NC}"
    echo -e "${BLUE}sudo apt update${NC}"
    echo -e "${BLUE}sudo apt install git gcc pkg-config${NC}"
    echo -e "\n${YELLOW}For Go installation:${NC}"
    echo -e "${BLUE}wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz${NC}"
    echo -e "${BLUE}sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz${NC}"
    echo -e "${BLUE}export PATH=\$PATH:/usr/local/go/bin${NC}"
    echo ""
    exit 1
else
    echo -e "${GREEN}✅ All prerequisites satisfied!${NC}"
    echo -e "Proceeding with build...\n"
fi

# Get git version information
GIT_VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")
echo "Building version: $GIT_VERSION"
echo "Host architecture: $HOST_ARCH"

if [ "$HOST_ARCH" = "x86_64" ]; then
    echo "→ Cross-compiling Debian ARM64 binary"
    BUILD_ENV="GOOS=linux GOARCH=arm64 CGO_ENABLED=1"
    DEBIAN_CC="aarch64-linux-gnu-gcc"
else
    echo "→ Native compile on aarch64"
    BUILD_ENV="GOOS=linux GOARCH=arm64 CGO_ENABLED=1"
    DEBIAN_CC="gcc"
fi

echo -e "\n${YELLOW}6. Building Debian ARM64 binary...${NC}"
echo "Compiling for Debian (aarch64)..."
env $BUILD_ENV CC=$DEBIAN_CC go build -o pcat2_mini_display_debian .
if [ $? -eq 0 ]; then
    echo -e "  ✓ ${GREEN}Debian build succeeded${NC}"
else
    echo -e "  ✗ ${RED}Debian build failed${NC}"
    exit 1
fi

# Build for the local host system last
echo -e "\n${YELLOW}7. Building for host system...${NC}"
echo "Compiling for host ($HOST_ARCH)..."
go build -o photonicat2_mini_display .
if [ $? -eq 0 ]; then
    echo -e "  ✓ ${GREEN}Host build succeeded${NC}"
else
    echo -e "  ✗ ${RED}Host build failed${NC}"
    exit 1
fi

echo -e "\n${GREEN}✅ Build process completed!${NC}"
echo -e "\nBuilt binaries:"
existing_binaries=()
for binary in photonicat2_mini_display pcat2_mini_display_debian; do
    if [ -e "$binary" ]; then
        existing_binaries+=("$binary")
    fi
done
if [ ${#existing_binaries[@]} -gt 0 ]; then
    ls -la "${existing_binaries[@]}"
else
    echo "  No binaries found"
fi
echo -e "\n${BLUE}Usage:${NC}"
echo -e "  Run tests: ${YELLOW}./run_tests.sh${NC}"
echo -e "  Run app:   ${YELLOW}./photonicat2_mini_display${NC}"
echo -e "\n${BLUE}For Debian deployment:${NC}"
echo -e "  Debian install binary: ${YELLOW}pcat2_mini_display_debian${NC}"

exit 0
