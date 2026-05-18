#!/bin/bash
# Usage: ./hugo_theme_switch.sh <테마명> <GitHub URL>
set -e

THEME_NAME=$1
REPO_URL=$2

# 1. 유효성 검사
if [ -z "$THEME_NAME" ] || [ -z "$REPO_URL" ]; then
  echo "Usage: $0 <테마명> <GitHub URL>"
  exit 1
fi

if [ ! -f "hugo.yaml" ]; then
  echo "[ERROR] hugo.yaml 파일이 없습니다. Hugo 프로젝트 루트에서 실행해주세요."
  exit 1
fi

# 2. Git 서브모듈로 테마 추가
if [ ! -d "themes/${THEME_NAME}" ]; then
  echo "[설치] ${THEME_NAME}을 Git 서브모듈로 추가 중..."
  git submodule add "$REPO_URL" "themes/${THEME_NAME}"
else
  echo "[스킵] ${THEME_NAME} 이미 존재함"
fi

# 3. 설정 파일 백업 및 테마 변경 (YAML 포맷 반영)
cp "hugo.yaml" "hugo.yaml.bak"

if grep -qE "^theme:" "hugo.yaml"; then
  # 정규식을 이용해 기존 theme: 라인을 교체 (macOS/Linux 호환)
  sed "s/^theme:.*/theme: ${THEME_NAME}/" "hugo.yaml.bak" > "hugo.yaml"
else
  # 기존에 theme 설정이 없었다면 맨 아래에 추가
  echo "theme: ${THEME_NAME}" >> "hugo.yaml"
fi

echo "[완료] hugo.yaml → theme: ${THEME_NAME} (백업: hugo.yaml.bak)"
echo "확인: hugo server -D"