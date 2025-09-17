#!/bin/bash

# Define your internal registry and the base image name
INTERNAL_REGISTRY="media.johnson.int:5000" # Or "admin.dettonville.int:5000"
BASE_IMAGE_NAME="ansible/ansible-test"

# Define the versions you want to build
# These should match the versions you use in your Jenkins pipeline's YAML configs
ANSIBLE_VERSIONS=("2.14" "2.15" "latest" "devel") # Example: 2.14, 2.15, latest, devel
PYTHON_VERSIONS=("3.9" "3.10" "3.11") # Example: 3.9, 3.10, 3.11

# Path to your Dockerfile (assuming it's in the current directory)
DOCKERFILE_PATH="image"

# --- Login to your internal registry (if required) ---
# Your daemon.json has "insecure-registries", so it might not need HTTPS,
# but it could still require authentication.
echo "Attempting to log in to ${INTERNAL_REGISTRY}..."
docker login "${INTERNAL_REGISTRY}"
# You will be prompted for Username and Password.

# --- Build and Push Loop ---
for ANSIBLE_VER in "${ANSIBLE_VERSIONS[@]}"; do
    for PYTHON_VER in "${PYTHON_VERSIONS[@]}"; do
        # Construct the tag based on your naming convention
        TAG=""
        if [ "${ANSIBLE_VER}" = "latest" ]; then
            TAG="latest-py${PYTHON_VER}"
        elif [ "${ANSIBLE_VER}" = "devel" ]; then
            TAG="devel-py${PYTHON_VER}"
        else
            TAG="stable-${ANSIBLE_VER}-py${PYTHON_VER}"
        fi

        FULL_IMAGE_NAME="${INTERNAL_REGISTRY}/${BASE_IMAGE_NAME}:${TAG}"

        echo "--- Building image: ${FULL_IMAGE_NAME} (Ansible: ${ANSIBLE_VER}, Python: ${PYTHON_VER}) ---"
        # Build the Docker image, passing versions as build arguments
        docker build \
            --build-arg ANSIBLE_CORE_VERSION="${ANSIBLE_VER}" \
            --build-arg PYTHON_VERSION="${PYTHON_VER}" \
            -t "${FULL_IMAGE_NAME}" \
            "${DOCKERFILE_PATH}"

        if [ $? -eq 0 ]; then
            echo "--- Successfully built ${FULL_IMAGE_NAME}. Pushing to registry... ---"
            docker push "${FULL_IMAGE_NAME}"
            if [ $? -eq 0 ]; then
                echo "--- Successfully pushed ${FULL_IMAGE_NAME} ---"
            else
                echo "!!! Failed to push ${FULL_IMAGE_NAME} !!!"
            fi
        else
            echo "!!! Failed to build ${FULL_IMAGE_NAME} !!!"
        fi
        echo "" # Newline for readability
    done
done

echo "--- All requested images processed ---"
