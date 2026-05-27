# 1. Stop and remove all containers, networks, and local images built for this project
docker compose down --rmi local --volumes --remove-orphans

# 2. Specifically delete the persistent volumes
docker volume rm ollamaState hermesStorage

# 3. System prune to clear out dangling build caches and temporary layers
docker builder prune -f