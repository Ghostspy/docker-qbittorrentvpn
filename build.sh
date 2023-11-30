#/bin/zsh

depot configure-docker
docker buildx build -f Dockerfile . --platform linux/amd64,linux/arm64 -t harbor.ghosthacker.com/library/qbittorrent:4.6.2-lt2 --push --no-cache