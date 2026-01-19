#!/bin/bash

# Утилита для генерации отчета о сборке
# Создает файл build_report_{date_time}.txt с информацией:
# Номер запуска
# Уникальный номер ревизии
# Тип сборки
# Значение покрытия (если применимо)

# Использование:
# ./generate-report.sh <режим> [coverage_percent]
# где режим: release, debug или coverage
# coverage_percent: процент покрытия (только для coverage)

set -e  # Остановка при ошибке

# Подключаем утилиты
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Рабочая директория (внутри контейнера это /build)
WORK_DIR="${WORK_DIR:-/build}"

# Проверка аргументов
if [ $# -lt 1 ]; then
    log_error "Использование: $0 <режим> [coverage_percent]"
    log_error "  режим: release, debug или coverage"
    log_error "  coverage_percent: процент покрытия (только для coverage)"
    exit 1
fi

BUILD_MODE="$1"
COVERAGE_PERCENT="${2:-N/A}"

# Проверка корректности режима
if [ "$BUILD_MODE" != "release" ] && [ "$BUILD_MODE" != "debug" ] && [ "$BUILD_MODE" != "coverage" ]; then
    log_error "Неверный режим: $BUILD_MODE (должен быть release, debug или coverage)"
    exit 1
fi

# Для coverage режима coverage_percent должен быть указан
if [ "$BUILD_MODE" = "coverage" ] && [ "$COVERAGE_PERCENT" = "N/A" ]; then
    log_error "Для режима coverage необходимо указать процент покрытия"
    exit 1
fi

log_info "Генерация отчета о сборке..."

# Получаем номер запуска и ревизию
BUILD_NUMBER=$(get_build_number)
REVISION=$(get_revision)

# Формируем имя файла отчета с датой и временем
# Формат: build_report_YYYYMMDD-HHMMSS.txt
DATE_TIME=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "unknown")
REPORTS_DIR="$WORK_DIR/reports"
mkdir -p "$REPORTS_DIR"
REPORT_FILE="$REPORTS_DIR/build_report_${DATE_TIME}.txt"

# Создаем отчет
log_info "Создание отчета: $REPORT_FILE"
cat > "$REPORT_FILE" <<EOF
Build Report
============

Build Number: $BUILD_NUMBER
Revision: $REVISION
Build Type: $BUILD_MODE
Coverage: $COVERAGE_PERCENT
Date: $(date '+%Y-%m-%d %H:%M:%S')

EOF

log_info "Отчет успешно создан: $REPORT_FILE"
log_info "Номер запуска: $BUILD_NUMBER"
log_info "Ревизия: $REVISION"
log_info "Режим сборки: $BUILD_MODE"
if [ "$COVERAGE_PERCENT" != "N/A" ]; then
    log_info "Покрытие кода: ${COVERAGE_PERCENT}%"
fi
