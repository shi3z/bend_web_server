#!/bin/bash
set -e

export PATH="$HOME/.bend/bin:$PATH"

if ! command -v bend &> /dev/null; then
    if [ -f "$HOME/.bend/bin/bend" ]; then
        BEND_BIN="$HOME/.bend/bin/bend"
    else
        echo "Bend not found. Installing Bend from https://bend-lang.com/install.sh..."
        curl -fsSL https://bend-lang.com/install.sh | sh
        BEND_BIN="$HOME/.bend/bin/bend"
    fi
else
    BEND_BIN="bend"
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Starting Bend Web Server on http://127.0.0.1:8080 ..."
exec "$BEND_BIN" "$DIR/server.bend"
