#!/bin/bash
#
# docker_info.sh - 시놀로지 환경에서 sudo docker를 사용하여
#                       컨테이너/이미지 정보를 JSON 형태로 ONLY 출력하는 스크립트
#
# chkconfig: - 60 30
# description: Docker info as JSON
#

set -euo pipefail
IFS=$'\n\t'

DOCKER_CMD="sudo docker"

# jq가 설치되어 있는지 확인
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq is not installed. Please install jq to use this script."}'
    exit 1
fi

# Helper Functions

# 에러 처리 함수
error_exit() {
    local message="$1"
    echo "{\"error\": \"${message}\"}"
    exit 1
}

# 컨테이너 존재 여부 확인
validate_container() {
    local container_name="$1"
    if ! ${DOCKER_CMD} ps -a --format '{{.Names}}' | grep -wq "${container_name}"; then
        error_exit "Container '${container_name}' does not exist."
    fi
}

# 이미지 존재 여부 확인
validate_image() {
    local image_name="$1"
    if ! ${DOCKER_CMD} images --format '{{.Repository}}:{{.Tag}}' | grep -wq "${image_name}"; then
        error_exit "Image '${image_name}' does not exist."
    fi
}

# 컨테이너 정보 (docker inspect <container_name> [OPTIONS])
show_container_info() {
    local container_name="$1"
    shift 1
    local inspect_options=("$@")

    if [ -z "${container_name}" ]; then
        error_exit "No container name specified."
    fi

    validate_container "${container_name}"

    ${DOCKER_CMD} inspect "${inspect_options[@]}" "${container_name}" | jq '.[0]'
}

# 이미지 정보 (docker inspect <image_name> [OPTIONS])
show_image_info() {
    local image_name="$1"
    shift 1
    local inspect_options=("$@")

    if [ -z "${image_name}" ]; then
        error_exit "No image name specified."
    fi

    validate_image "${image_name}"

    ${DOCKER_CMD} inspect "${inspect_options[@]}" "${image_name}" | jq '.[0]'
}

# 모든 컨테이너 목록 (docker ps [OPTIONS])
list_containers() {
    local ps_options=("$@")
    ${DOCKER_CMD} ps "${ps_options[@]}" --format '{{json .}}' | jq -s .
}

# 모든 이미지 목록 (docker images [OPTIONS])
list_images() {
    local images_options=("$@")
    ${DOCKER_CMD} images "${images_options[@]}" --format '{{json .}}' | jq -s .
}

# 컨테이너 로그 (docker logs <container_name> [OPTIONS])
show_container_logs() {
    local container_name="$1"
    shift 1
    local log_options=("$@")

    if [ -z "${container_name}" ]; then
        error_exit "No container name specified for logs."
    fi

    validate_container "${container_name}"

    # 로그 명령어 실행
    logs=$(${DOCKER_CMD} logs "${log_options[@]}" "${container_name}" 2>&1 || true)

    # 로그를 JSON 배열로 변환
    echo "$logs" | jq -R -s -c 'split("\n") | map(select(length > 0))'
}

# 시스템 정보 (docker info [OPTIONS])
show_system_info() {
    local info_options=("$@")
    ${DOCKER_CMD} info "${info_options[@]}" --format '{{json .}}' | jq '.'
}

# 메인 로직
main() {
    if [ $# -lt 1 ]; then
        error_exit "No command specified. Use one of [container, image, ps, images, logs, system]."
    fi

    case "$1" in
        container)
            if [ $# -lt 2 ]; then
                error_exit "Usage: $0 container <container_name> [OPTIONS]"
            fi
            local container_name="$2"
            shift 2
            show_container_info "${container_name}" "$@"
            ;;
        image)
            if [ $# -lt 2 ]; then
                error_exit "Usage: $0 image <image_name> [OPTIONS]"
            fi
            local image_name="$2"
            shift 2
            show_image_info "${image_name}" "$@"
            ;;
        ps)
            # 'ps'는 추가 옵션 없이도 사용 가능
            shift 1
            list_containers "$@"
            ;;
        images)
            # 'images'는 추가 옵션 없이도 사용 가능
            shift 1
            list_images "$@"
            ;;
        logs)
            if [ $# -lt 2 ]; then
                error_exit "Usage: $0 logs <container_name> [OPTIONS]"
            fi
            local container_name="$2"
            shift 2
            show_container_logs "${container_name}" "$@"
            ;;
        system)
            # 'system'은 추가 옵션 없이도 사용 가능
            shift 1
            show_system_info "$@"
            ;;
        help|-h|--help)
            cat <<EOF
Usage: $0 COMMAND [OPTIONS]

Commands:
  container <container_name> [OPTIONS]   Show detailed information of a specific container.
  image <image_name> [OPTIONS]           Show detailed information of a specific image.
  ps [OPTIONS]                           List containers with optional flags.
  images [OPTIONS]                       List images with optional flags.
  logs <container_name> [OPTIONS]        Show logs of a specific container with optional flags.
  system [OPTIONS]                       Show Docker system-wide information with optional flags.
  help                                   Show this help message.

Examples:
  $0 ps
  $0 ps -a
  $0 container my_container --format '{{.Name}}: {{.Status}}'
  $0 logs my_container --tail 50
  $0 logs my_container -f
  $0 system
EOF
            ;;
        *)
            error_exit "Invalid command '${1}'. Use one of [container, image, ps, images, logs, system]."
            ;;
    esac
}

main "$@"

exit 0
