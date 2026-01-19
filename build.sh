#!/bin/bash

# Главный скрипт конвейера сборки
# Точка входа для запуска сборки проекта jq в Docker контейнере
#
# Использование:
# ./build.sh [release|debug|coverage]

set -e  # Остановка при ошибке

# Получаем директорию, где находится скрипт
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Подключаем утилиты
source "$SCRIPT_DIR/scripts/utils.sh"

# Имя Docker образа для сборки
DOCKER_IMAGE="jq-build-env"

# Функция для проверки наличия Docker образа
check_docker_image() {
    if docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
        log_info "Docker образ '$DOCKER_IMAGE' найден"
        return 0
    else
        log_info "Docker образ '$DOCKER_IMAGE' не найден, начинаем сборку образа"
        return 1
    fi
}

# Функция для сборки Docker образа
build_docker_image() {
    log_info "Сборка Docker образа '$DOCKER_IMAGE'..."
    docker build -t "$DOCKER_IMAGE" -f Dockerfile .
    if [ $? -eq 0 ]; then
        log_info "Docker образ '$DOCKER_IMAGE' успешно собран"
    else
        log_error "Ошибка при сборке Docker образа"
        exit 1
    fi
}

# Функция для вывода справки
show_usage() {
    echo "Использование: $0 [release|debug|coverage]"
    echo ""
    echo "Режимы сборки:"
    echo "  release   - Сборка с оптимизациями, strip, deb пакет"
    echo "  debug     - Сборка с отладочными символами, deb пакет"
    echo "  coverage  - Сборка с gcov/lcov, интеграционное тестирование"
    exit 1
}

# Проверка аргументов
if [ $# -eq 0 ]; then
    log_error "Не указан режим сборки"
    show_usage
fi

BUILD_MODE="$1"

# Проверка корректности режима сборки
case "$BUILD_MODE" in
    release|debug|coverage)
        log_info "Режим сборки: $BUILD_MODE"
        ;;
    *)
        log_error "Неверный режим сборки: $BUILD_MODE"
        show_usage
        ;;
esac

# Проверка и сборка Docker образа при необходимости
if ! check_docker_image; then
    build_docker_image
fi

# Вызов соответствующего скрипта сборки внутри Docker контейнера
log_info "Запуск сборки в режиме '$BUILD_MODE'..."

# Определяем какой скрипт запускать
case "$BUILD_MODE" in
    release)
        BUILD_SCRIPT="scripts/build-release.sh"
        ;;
    debug)
        BUILD_SCRIPT="scripts/build-debug.sh"
        ;;
    coverage)
        BUILD_SCRIPT="scripts/build-coverage.sh"
        ;;
esac

# Запускаем скрипт внутри Docker контейнера
# Монтируем текущую директорию в /build контейнера
# Передаем переменную WORK_DIR для работы скриптов
docker run --rm \
    -v "$SCRIPT_DIR:/build" \
    -w /build \
    -e WORK_DIR=/build \
    "$DOCKER_IMAGE" \
    bash "$BUILD_SCRIPT"

# Генерация отчёта о сборке
log_info "Генерация отчёта о сборке..."

# Для coverage режима читаем процент покрытия из файла
COVERAGE_PERCENT="N/A"
if [ "$BUILD_MODE" = "coverage" ]; then
    COVERAGE_FILE="$SCRIPT_DIR/coverage_percent.txt"
    if [ -f "$COVERAGE_FILE" ]; then
        COVERAGE_PERCENT=$(cat "$COVERAGE_FILE" | head -1 | awk '{print $1}')
        if [ -z "$COVERAGE_PERCENT" ]; then
            COVERAGE_PERCENT="N/A"
        else
            COVERAGE_PERCENT="${COVERAGE_PERCENT}%"
        fi
    fi
fi

# Запускаем генерацию отчёта внутри контейнера
docker run --rm \
    -v "$SCRIPT_DIR:/build" \
    -w /build \
    -e WORK_DIR=/build \
    "$DOCKER_IMAGE" \
    bash scripts/generate-report.sh "$BUILD_MODE" "$COVERAGE_PERCENT"

log_info "Сборка завершена"
