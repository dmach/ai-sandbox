#!/bin/sh


# securely run gemini in a container:
# - mount the working directory as /workspace
# - drop all capabilities that are not required for a good reason
# - prevent from accessing private network ranges
# - use public DNS


# error out on -y/--yolo argument
for arg in "$@"; do
    if [ "$arg" == "-y" -o "$arg" == "--yolo" ]; then
        echo "Avoid -y/--yolo. It causes unpredictable issues and compromises data integrity. Stick to verified, curated output."
        exit 1
    fi
done


# create and configure an isolated network if it doesn't exist
NETWORK='ai-isolated-net'
NETWORK_CONFIG="$HOME/.local/share/containers/storage/networks/${NETWORK}.json"

podman network exists "${NETWORK}"
if [ $? -ne 0 ]; then
    podman network create "${NETWORK}" --subnet 172.16.0.0/24 --gateway 172.16.0.1

    echo "$(jq '.routes += [
        {"destination": "10.0.0.0/8", "gateway": "172.16.0.254"},
        {"destination": "192.168.0.0/16", "gateway": "172.16.0.254"}
    ]' "${NETWORK_CONFIG}")" > "${NETWORK_CONFIG}"
fi


# extract the git author/email from either local or global git config
GIT_AUTHOR_NAME="$(git config user.name)"
GIT_AUTHOR_EMAIL="$(git config user.email)"

# resolve the host-side system.md target so the container reads a real file path
SYSTEM_MD_LINK="${HOME}/.gemini/system.md"
SYSTEM_MD_REAL="$(readlink -f "${SYSTEM_MD_LINK}")"

if [ -z "${SYSTEM_MD_REAL}" ] || [ ! -f "${SYSTEM_MD_REAL}" ]; then
    echo "Missing or invalid ${SYSTEM_MD_LINK}. Run install.sh to recreate it."
    exit 1
fi

AI_USER_UID=1000
AI_USER_GID=1000

# capability 'dac_override' is required by zypper/rpm
# capabilities 'setuid' and 'setgid' are required by sudo
podman run \
    -it \
    --rm \
    -e TERM='xterm-256color' \
    -e COLORTERM='truecolor' \
    -e GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT}" \
    -e GEMINI_SANDBOX='0' \
    -e GEMINI_CLI_TRUST_WORKSPACE='1' \
    -e GEMINI_SYSTEM_MD="/home/aiuser/.gemini/system.md" \
    -e GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME}" \
    -e GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL}" \
    --network="${NETWORK}" \
    --cap-drop=all \
    --cap-add=dac_override \
    --cap-add=setgid \
    --cap-add=setuid \
    --userns="keep-id:uid=${AI_USER_UID},gid=${AI_USER_GID}" \
    --tmpfs /tmp \
    --dns=8.8.8.8 \
    -v "${HOME}/.gemini:/home/aiuser/.gemini:rw,z" \
    -v "${SYSTEM_MD_REAL}:/home/aiuser/.gemini/system.md:ro,z" \
    -v "${PWD}:/workspace:rw,z" \
    -w "/workspace" \
    gemini \
    gemini --no-sandbox "$@"

# krun has a bug that hitting 'Enter' doesn't submit the message in the Gemini prompt, it only moves to the next line
#--runtime=krun \

