#!/bin/bash

echo -e "\33[0;32mDeploying updates to Github...\033[0m"

draft_files=$(grep -rl "draft: true" content/posts/)

if [ -n "$draft_files" ]; then
    echo -e "\033[0;33m⚠️  draft: true 파일 발견:\033[0m"
    echo "$draft_files"
    echo ""
    read -p "전부 draft: false로 변경할까요? (y/n): " fix

    if [ "$fix" = "y" ] || [ "$fix" = "Y" ]; then
        echo "$draft_files" | while read -r file; do
            sed -i '' 's/draft: true/draft: false/' "$file"
            echo "✅ 수정됨: $file"
        done
    else
        echo -e "\033[0;31m🚫 draft: true 파일이 남아있어 배포를 중단합니다.\033[0m"
        exit 1
    fi
fi
    

#서브 모듈(테마) 업데이트
git submodule update --remote

# 커밋 메시지 작성 (인자 없으면 시간)
msg="rebuild: $(date +"%Y-%m-%dT %H:%M:%S%z")"
if [ $# -eq 1 ]; then
    msg="$1"
fi

# main에 push 및 Action이 자동 빌드 & gh-paghes 배포
git add .
git commit -m "$msg"
git push origin main

echo -e "\033[0;32m✅ 배포 완료! Actions 탭에서 확인하세요.\033[0m"
echo "https://github.com/infdev00/infdev00.github.io/actions"