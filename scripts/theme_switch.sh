#!/bin/bash
# Usage: ./scripts/hugo_theme_switch.sh <테마명> <GitHub URL>
set -e

THEME_NAME=$1
REPO_URL=$2

# 기존 테마 제거
CURRENT_THEME=$(grep "^theme:" hugo.yaml | sed 's/theme: //' | tr -d '"')
if [ -n "$CURRENT_THEME" ] && [ "$CURRENT_THEME" != "$THEME_NAME" ] && [ -d "themes/${CURRENT_THEME}" ]; then
  echo "[제거] ${CURRENT_THEME}"
  git submodule deinit -f "themes/${CURRENT_THEME}"
  git rm -f "themes/${CURRENT_THEME}"
  rm -rf ".git/modules/themes/${CURRENT_THEME}"
fi

# 새 테마 추가
if git config --file .gitmodules "submodule.themes/${THEME_NAME}.url" &>/dev/null; then
  echo "[스킵] ${THEME_NAME} 이미 등록됨"
else
  echo "[설치] ${THEME_NAME}"
  git submodule add "$REPO_URL" "themes/${THEME_NAME}"
fi

# hugo.yaml 테마 변경
if grep -qE "^theme:" hugo.yaml; then
  sed -i '' "s/^theme:.*/theme: ${THEME_NAME}/" hugo.yaml
else
  echo "theme: ${THEME_NAME}" >> hugo.yaml
fi

echo "[완료] theme: ${THEME_NAME}"
echo "[확인] hugo server"