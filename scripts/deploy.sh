#!/bin/bash

echo -e "\033[0;32mDeploying updates to Github...\033[0m"

#서브 모듈(테마) 업데이트
git submodule update --remote

# 커밋 메시지 작성 (인자 없으면 시간)
msg="rebuild: $(date +"%Y-%m-%dT %H:%M:%S%z")"
if [ $# -eq 1 ]; then
    msg="$1"
fi

# /new-post가 저장한 AI 초안 원본 사본 삭제
find content -name "*.orig.md" -delete

# main에 push 및 Action이 자동 빌드 & gh-paghes 배포
git add .
git commit -m "$msg"
git push origin main

echo -e "\033[0;32m✅ 배포 완료! Actions 탭에서 확인하세요.\033[0m"
echo "https://github.com/infdev00/infdev00.github.io/actions"