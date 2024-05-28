#!/usr/bin/env bash
# ---
# Docker BuildX Helper script for building docker images.
# Script copied from: https://github.com/azataiot/docker
# ---

set -eu;

cat <<-'EOF'
                     _            _____
     /\             | |     /\   |_   _|
    /  \    ______ _| |_   /  \    | |
   / /\ \  |_  / _` | __| / /\ \   | |
  / ____ \  / / (_| | |_ / ____ \ _| |_
 /_/    \_\/___\__,_|\__/_/    \_\_____|
            @azataiot - 2024

EOF

PWD=$(dirname "$0")

# First argument is the path to the Dockerfile inside the Containers directory.
CONTAINERS_DIR="$PWD/../"
IMAGE_DIR="$CONTAINERS_DIR"
IMAGE_NAME="azataiot/djazz-services"

# DEFAULTS
DOCKERFILE_PATH="$IMAGE_DIR/Dockerfile"
HAS_VARIANT=false
REGISTRY="docker.io"
LATEST=true

# If the Dockerfile does not exist, show an error message and exit.
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "Dockerfile not found at $DOCKERFILE_PATH"
    exit 1;
else
    echo "Using Dockerfile: $DOCKERFILE_PATH"
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --registry)
            REGISTRY="$2"
            shift 1
            ;;
        -f)
            VARIANT="$2"
            HAS_VARIANT=true
            DOCKERFILE_PATH="$IMAGE_DIR/Dockerfile-$VARIANT"
            if [ ! -f "$DOCKERFILE_PATH" ]; then
              echo "Dockerfile not found at $DOCKERFILE_PATH"
              exit 1;
            fi
            shift 1
            ;;
        --no-latest)
            LATEST=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1;
            ;;
    esac
done

# Get the version from the Dockerfile
VERSION=$(sed -n 's/ARG VERSION=\(.*\)/\1/p' "$DOCKERFILE_PATH")

if [ -z "$VERSION" ]; then
    echo "Version not found in the Dockerfile"
    exit 1;
fi

# In case we have a variant, we need to append it to the version
if [ "$HAS_VARIANT" = true ]; then
    VERSION="$VERSION-$VARIANT"
fi
# Build the image

# Dynamically create the buildx build command
CMD="docker buildx build --platform linux/amd64,linux/arm64 -t $REGISTRY/$IMAGE_NAME:$VERSION"
if [ "$HAS_VARIANT" = true ]; then
    CMD="$CMD -f $DOCKERFILE_PATH"
fi
# if the latest flag is set to true, tag the image as latest
if [ "$LATEST" = true ]; then
    CMD="$CMD -t $REGISTRY/$IMAGE_NAME:latest"
fi

# Show info about the build
echo "Building $REGISTRY/$IMAGE_NAME:$VERSION (latest: $LATEST)"

CMD="$CMD --push $IMAGE_DIR"

# Run the build command
eval "$CMD"

