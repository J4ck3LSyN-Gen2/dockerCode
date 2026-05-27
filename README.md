# Docker-Code

- **Author:** _J4ck3LSyN_
- **Version:** 0.5.0

---

A hardened, containerized development environment based on VS Code (code-server), designed to provide a "Zero Trust" extension sandbox without sacrificing developer velocity.

## The Philosophy: Capability Without Compromise

Modern IDE extensions often require broad permissions to provide powerful features—refactoring, linting, and AI-assisted coding. However, granting third-party extensions unrestricted access to a host machine poses a significant security risk. 

This project was born from the need to solve the **Sandbox Paradox**: How do we ensure that IDE extensions are strictly isolated from the host system while still providing them with the resources (CPU, Memory, Network) and AI integrations ( Ollama) necessary for world-class engineering?

### Key Architectural Pillars

> _NOTE:_ Gemini functionality will be a lateral feature in the far future...

1.  **Hardened Isolation**: The environment runs with a `read-only` root filesystem. Temporary directories and caches are mounted as volatile `tmpfs` volumes, ensuring that extension-level persistence is strictly controlled and minimal.
2.  **Least Privilege**: We utilize `cap_drop: [ALL]` and `no-new-privileges: true` to ensure that even if a process is compromised within the container, it cannot escalate privileges or affect the host.
3.  **AI-First Workflow**: Seamlessly bridges local LLMs (via Ollama) and cloud-based intelligence (via Gemini CLI Companion) through a dedicated inter-process bridge.
4.  **Ephemeral yet Persistent**: While the system remains hardened, your work is saved via focused volume mounts for projects and VS Code configurations, allowing for a "disposable" environment that retains your intellectual property.

## Technical Specification

> _NOTE:_ AI implementation is still very much in the testing phase.

*   **Base**: code-server (VS Code in the browser)
*   **Security Layer**: Docker-native hardening (non-root user `1000:1000`, ulimits, security options).
*   **AI Integration**: 
    *   **Ollama**: Host-gateway access for local model inference.
*   **Resource Management**: Strictly defined `tmpfs` quotas for `.cache` and `pip` to prevent container bloat.

## Getting Started

### Installation

1. **Git the Repo**
    ```bash
    git clone https://github.com/J4ck3LSyN-Gen2/dckerCode.git
    cd dockerCode 
    ```

2. **Build**
    ```bash
    touch .hash # If non-existant
    chmod 666 .hash # Configure permissions
    docker compose build
    ```

3. **Generate Login Hash**
    ```bash
    # This will generate the hash and write it to .hash
    # NOTE: If no-input is given a random password will be generated
    docker run --rm -it \
       -u 1000:1000 \
       -v "$(pwd)/.hash:/home/coder/.hash" \
       dc-iso /usr/local/bin/gen_hash.sh
    ```

4. **Spawn the Server**
    ```bash
    # Remove '-d' to run in foreground
    docker compose up -d
    ```

5. **Access the Server**
    - Goto `http://localhost:8080`

6. **Capture Logs** 
    ```bash
    docker logs -f docker-code
    ```

7. **Down the Container**
    ```bash
    docker compose down
    ```

## Maintenance and Security

To maintain a clean slate and ensure no dangling layers or unauthorized configurations persist, use the provided pruning script:

```bash
chmod +x prune.sh
./prune.sh
```

This script handles:
*   Removing containers and project-local images.
*   Wiping persistent AI and storage volumes.
*   Clearing the Docker builder cache.

## Security Hardening Details

| Feature | Implementation | Purpose |
| :--- | :--- | :--- |
| **Root FS** | `read_only: true` | Prevents unauthorized system-level modifications. |
| **Privileges** | `no-new-privileges` | Blocks setuid/setgid escalation attempts. |
| **Capabilities** | `cap_drop: [ALL]` | Removes all Linux capabilities by default. |
| **Storage** | `tmpfs` mounts | Limits workspace-related temporary data to memory. |
| **Network** | `host-gateway` | Provides a secure bridge to host services (like Ollama) without exposing the host network. |

---

*Developed with a focus on security, portability, and AI-driven productivity.*