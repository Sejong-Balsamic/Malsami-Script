#!/bin/bash
#
# docker_info.sh - 시놀로지 환경에서 sudo docker를 사용하여
#                       컨테이너/이미지 정보를 JSON 형태로 ONLY 출력하는 스크립트
#
# chkconfig: - 60 30
# description: Docker info as JSON
#

DOCKER_CMD="sudo docker"

# --------------------------------------------------------------
# 1) 컨테이너 정보 (docker inspect)
#    - 반환: [ { ... } ] 형태의 JSON
# --------------------------------------------------------------
show_container_info() {
    local container_name="$1"
    if [ -z "${container_name}" ]; then
        # JSON 형식으로 오류 전달 시, 필요하다면 아래와 같이 처리 가능
        echo '{"error": "No container name specified"}'
        exit 1
    fi

    # docker inspect -> 기본적으로 배열([]) 형태의 JSON 반환
    # 컨테이너가 1개만 매칭되면 [ { ... } ]
    # 여러 개 매칭되면 [ { ... }, { ... }, ... ]
    ${DOCKER_CMD} inspect "${container_name}"
}

# --------------------------------------------------------------
# 2) 이미지 정보 (docker inspect)
#    - 반환: [ { ... } ] 형태의 JSON
# --------------------------------------------------------------
show_image_info() {
    local image_name="$1"
    if [ -z "${image_name}" ]; then
        echo '{"error": "No image name specified"}'
        exit 1
    fi

    ${DOCKER_CMD} inspect "${image_name}"
}

# --------------------------------------------------------------
# 3) 모든 컨테이너 목록 (docker ps -a)
#    - docker ps --format '{{json .}}' : 각 컨테이너를 JSON 오브젝트로 출력
#    - 이를 JSON 배열로 감싸서 반환
#    - 예) [ {"ID":"...","Image":"..."}, {"ID":"...","Image":"..."} ]
# --------------------------------------------------------------
list_containers() {
    containers=$(${DOCKER_CMD} ps -a --format='{{json .}}')

    # JSON 배열 시작
    echo -n '['

    count=0
    while IFS= read -r line; do
        # 첫 번째가 아니면 앞에 콤마(,) 붙이기
        if [ $count -gt 0 ]; then
            echo -n ','
        fi
        echo -n "$line"
        count=$((count+1))
    done <<< "$containers"

    # JSON 배열 종료
    echo ']'
}

# --------------------------------------------------------------
# 4) 모든 이미지 목록 (docker images)
#    - docker images --format '{{json .}}' : 각 이미지를 JSON 오브젝트로 출력
#    - 이를 JSON 배열로 감싸서 반환
# --------------------------------------------------------------
list_images() {
    images=$(${DOCKER_CMD} images --format='{{json .}}')

    echo -n '['
    count=0
    while IFS= read -r line; do
        if [ $count -gt 0 ]; then
            echo -n ','
        fi
        echo -n "$line"
        count=$((count+1))
    done <<< "$images"
    echo ']'
}

# --------------------------------------------------------------
# 5) 컨테이너 로그 (docker logs)
#    - 여러 줄이므로, 각 줄을 "JSON 배열"로 만들어 반환
#    - 특수문자(쌍따옴표 등)는 간단 sed 치환
# --------------------------------------------------------------
show_container_logs() {
    local container_name="$1"
    if [ -z "${container_name}" ]; then
        echo '{"error": "No container name specified for logs"}'
        exit 1
    fi

    # 최근 100줄 로그 (필요시 변경)
    logs=$(${DOCKER_CMD} logs --tail 100 "${container_name}" 2>&1)

    # JSON 배열 시작
    echo -n '['
    count=0
    while IFS= read -r line; do
        # 쌍따옴표만 간단 이스케이프 처리 (필요시 다른 특수문자도 처리 가능)
        escaped_line=$(echo "$line" | sed 's/"/\\"/g')

        if [ $count -gt 0 ]; then
            echo -n ','
        fi
        # 한 줄을 JSON string으로
        echo -n "\"${escaped_line}\""
        count=$((count+1))
    done <<< "$logs"
    echo ']'
}

# --------------------------------------------------------------
# 메인 로직 (SysV init 스타일)
# --------------------------------------------------------------
case "$1" in
  container)
    # Usage: ./docker_info.sh container <container_name>
    show_container_info "$2"
    ;;
  image)
    # Usage: ./docker_info.sh image <image_name>
    show_image_info "$2"
    ;;
  ps)
    # Usage: ./docker_info.sh ps
    list_containers
    ;;
  images)
    # Usage: ./docker_info.sh images
    list_images
    ;;
  logs)
    # Usage: ./docker_info.sh logs <container_name>
    show_container_logs "$2"
    ;;
  *)
    # 모든 에러/미매칭 사용법에 대해서도 JSON으로 반환
    echo '{"error": "Invalid command. Use one of [container, image, ps, images, logs]."}'
    exit 1
    ;;
esac

exit 0
