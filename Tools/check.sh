#!/bin/sh
# Повна перевірка на Mac: збірка під симулятор + усі тести (додаток і ZalizoCore).
# Запуск із кореня репозиторію:  sh Tools/check.sh
set -e
DEST='platform=iOS Simulator,name=iPhone 17'
xcodebuild -project Zalizo.xcodeproj -scheme Zalizo -destination "$DEST" build | tail -5
xcodebuild -project Zalizo.xcodeproj -scheme Zalizo -destination "$DEST" test | tail -25
