#!/bin/bash

# Вспомогательные функции для скриптов сборки
# Общие утилиты, используемые в разных скриптах

# Функция логирования: информационное сообщение
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

# Функция логирования: сообщение об ошибке
log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

# Функция получения ревизии проекта
# Возвращает уникальный номер ревизии для использования в именах артефактов
# Использует короткий git commit hash, если git доступен, иначе timestamp
get_revision() {
    # Пытаемся получить git commit hash (короткий, 7 символов)
    if command -v git >/dev/null 2>&1; then
        # Проверяем, находимся ли мы в git-репозитории
        if git rev-parse --git-dir >/dev/null 2>&1; then
            # Получаем короткий hash текущего коммита
            REVISION=$(git rev-parse --short HEAD 2>/dev/null || echo "")
            if [ -n "$REVISION" ]; then
                echo "$REVISION"
                return 0
            fi
        fi
    fi
    
    # Если git недоступен или не в репозитории - используем timestamp
    # Формат: YYYYMMDD-HHMMSS
    REVISION=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "unknown")
    echo "$REVISION"
}

# Функция получения и инкремента номера запуска
# Хранит номер в файле build_number.txt в рабочей директории
# Возвращает текущий номер запуска (инкрементируется при каждом вызове)
get_build_number() {
    WORK_DIR="${WORK_DIR:-/build}"
    BUILD_NUMBER_FILE="$WORK_DIR/build_number.txt"
    
    # Читаем текущий номер или начинаем с 1
    if [ -f "$BUILD_NUMBER_FILE" ]; then
        BUILD_NUMBER=$(cat "$BUILD_NUMBER_FILE" | head -1 | awk '{print $1}')
        # Проверяем, что это число
        if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
            BUILD_NUMBER=1
        fi
    else
        BUILD_NUMBER=0
    fi
    
    # Инкрементируем номер
    BUILD_NUMBER=$((BUILD_NUMBER + 1))
    
    # Сохраняем новый номер
    echo "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"
    
    echo "$BUILD_NUMBER"
}
