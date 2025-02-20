program=$(basename "$0")

USAGE=$(cat <<EOF
Build the VyOS 'vyos-build' Docker image with Docker BuildX.

Usage: $program <path> [args]

where <path> is the path to the 'vyos-build' git submodule, and [args]
are passed to the BuildX 'build' command.

Unless overridden, the image will be built with the tag

vyos-build:<git-rev>

where <git-rev> is the short git-rev of the 'vyos-build' submodule.
EOF
     )

usage () {
    echo "$USAGE" >&2
}

if [ "$#" -lt 1 ]; then
    usage
    exit 1
fi

if [ -z "${1+x}" ]; then
    usage
    exit 1
fi

# Check that the 'vyos-build' git submodule exists and is checked out.
SUBMODULE_PATH="$1"
if [ ! -d "$SUBMODULE_PATH" ] || [ ! -e "$SUBMODULE_PATH/.git" ]; then
    echo "'vyos-build' submodule at path $SUBMODULE_PATH does not exist or is not checked out."
    echo "Please initialize and update the submodule."
    exit 2
fi

# Check that the Dockerfile exists where we expect it.
DOCKER_DIR="$SUBMODULE_PATH/docker"
DOCKERFILE="$DOCKER_DIR/Dockerfile"
if [ ! -f "$DOCKERFILE" ]; then
    echo "'vyos-build' Dockerfile does not exist at expected path $DOCKERFILE, aborting."
    exit 3
fi

# Obtain the git ref of the submodule.
cd "$SUBMODULE_PATH" || exit 1
git_ref=$(git rev-parse --short HEAD)
cd .. || exit 4

# Build the image.
tag="vyos-build:git-${git_ref}"
shift
build_cmd="docker buildx build -t $tag $* $DOCKER_DIR"
echo "Running build command:"
echo "$build_cmd"
eval "$build_cmd"
