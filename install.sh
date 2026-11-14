#!/bin/sh
set -e

REPO="ubiomni/cyctl"
INSTALL_DIR="/usr/local/bin"

detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "darwin" ;;
        *)       echo "unsupported"; exit 1 ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)             echo "unsupported"; exit 1 ;;
    esac
}

main() {
    OS=$(detect_os)
    ARCH=$(detect_arch)
    NAME="cyctl-${OS}-${ARCH}"

    if [ -n "$1" ]; then
        VERSION="$1"
    else
        VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    fi

    if [ -z "$VERSION" ]; then
        echo "Error: could not determine latest version"
        exit 1
    fi

    URL="https://github.com/${REPO}/releases/download/${VERSION}/${NAME}.tar.gz"

    echo "Downloading cyctl ${VERSION} for ${OS}/${ARCH}..."
    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT

    curl -fsSL "$URL" -o "$TMPDIR/${NAME}.tar.gz"
    tar xzf "$TMPDIR/${NAME}.tar.gz" -C "$TMPDIR"

    if [ -w "$INSTALL_DIR" ]; then
        mv "$TMPDIR/cyctl" "$INSTALL_DIR/cyctl"
    else
        echo "Installing to ${INSTALL_DIR} (requires sudo)..."
        sudo mv "$TMPDIR/cyctl" "$INSTALL_DIR/cyctl"
    fi

    chmod +x "$INSTALL_DIR/cyctl"
    echo "Installed cyctl ${VERSION} to ${INSTALL_DIR}/cyctl"
}

main "$@"
