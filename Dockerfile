FROM codercom/code-server:latest

USER root

# Layer 1: System Dependencies (Consolidated and locked down)
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini \
    curl \
    ca-certificates \
    argon2 \
    openssl \
    git \
    nodejs \
    npm \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Layer 2: Asset Stripping Patch
# code-server injects login text dynamically or minifies it. 
# This targets both the raw HTML containers and the distribution JS bundles safely.
RUN find /usr/lib/code-server -type f \( -name "*.html" -o -name "*.js" \) -exec sed -i \
    -e 's/Please log in below\.//gI' \
    -e 's/Password was set from//gI' {} \;

# Layer 3: Environment Configuration
ENV EXTENSIONS_GALLERY='{"serviceUrl":"https://marketplace.visualstudio.com/_apis/public/gallery","itemUrl":"https://marketplace.visualstudio.com/items"}' \
    DISABLE_TELEMETRY=true

# Layer 4: Directory Preparation
RUN mkdir -p /home/coder/project /home/coder/.local/share/code-server

# Layer 5: Inline Script Injection with explicit ownership enforcement
COPY --chown=1000:1000 <<-'EOF' /usr/local/bin/entrypoint.sh
	#!/bin/bash
	if [ -f /home/coder/.hash ]; then
	    export HASHED_PASSWORD=$(tr -d '[:space:]' < /home/coder/.hash)
	fi
	exec "$@"
EOF

COPY --chown=1000:1000 <<-'EOF' /usr/local/bin/gen_hash.sh
	#!/bin/bash
	echo "=== Password Hash Generator (J4ck3LSyN) ==="
	echo -n "Enter your password: "
	read -rs PASSWORD
	echo
	if [ -z "$PASSWORD" ]; then
	    PASSWORD=$(openssl rand -hex 8)
	    echo "Generated random password: $PASSWORD"
	fi
	echo "Generating Argon2 hash..."
	HASH=$(printf '%s' "$PASSWORD" | argon2 "$(openssl rand -hex 16)" -e -id -k 4096 -t 3 -p 1 | tr -d '[:space:]')
	
	if [ $? -ne 0 ] || [ -z "$HASH" ]; then
	    echo "[-] Hash computation failed."
	    exit 1
	fi

	HASH_FILE="/home/coder/.hash"
	if [ -d "$HASH_FILE" ]; then
	    echo "[!] Error: $HASH_FILE is a directory."
	    exit 1
	fi

	# Target write evaluation directly
	if echo "$HASH" > "$HASH_FILE" 2>/dev/null; then
	    echo "[+] Hash successfully saved to $HASH_FILE"
	else
	    echo "[-] Error: Write permission denied to $HASH_FILE."
	    echo "    Verify host file ownership and ensure the container volume is not read-only during generation."
	    exit 1
	fi
EOF

COPY --chown=1000:1000 <<-'EOF' /usr/local/bin/ext
	#!/bin/bash
	if [[ "$1" == "install" ]]; then
	    shift
	    /usr/bin/code-server --install-extension "$@"
	else
	    /usr/bin/code-server "$@"
	fi
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/gen_hash.sh /usr/local/bin/ext \
    && chown -R 1000:1000 /home/coder

# Layer 6: Extension Baking (Executed as non-root to preserve plugin permissions)
USER 1000:1000
ARG EXTENSIONS="ms-python.python ms-python.vscode-pylance"
RUN for ext in $EXTENSIONS; do \
        echo "[-] Installing: $ext" && \
        code-server --install-extension "$ext" || echo "[!] Extension $ext failed to install, skipping..."; \
    done

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["code-server", "--bind-addr", "0.0.0.0:8080", "--auth", "password", "--disable-telemetry", "--app-name", "Docker-Code-Server", "/home/coder/project"]