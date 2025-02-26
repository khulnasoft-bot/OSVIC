#!/bin/bash

display_usage() {
    echo "This script fetches updates, creates dumps, and diffs as JSON files."
    echo -e "\nUsage: $0 [options]\n"
    echo "Options:"
    echo "  -n, --no-data-update     Skip data update"
    echo "  -p, --push-data          Push data to the remote repository"
    echo "  -u, --username USERNAME  Git username for authentication"
    echo "  -w, --password PASSWORD  Git password/token for authentication"
}

DO_DATA_UPDATE=1
DO_PUSH=0
GIT_USERNAME=""
GIT_PASSWORD=""
GIT_ORIGIN="origin"

while (( "$#" )); do
  case "$1" in
    -n|--no-data-update)
      DO_DATA_UPDATE=0
      shift
      ;;
    -p|--push-data)
      DO_PUSH=1
      shift
      ;;
    -u|--username)
      if [ -n "$2" ]; then
        GIT_USERNAME="$2"
        shift 2
      else
        echo "Error: Missing argument for --username" >&2
        exit 1
      fi
      ;;
    -w|--password)
      if [ -n "$2" ]; then
        GIT_PASSWORD="$2"
        shift 2
      else
        echo "Error: Missing argument for --password" >&2
        exit 1
      fi
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      display_usage
      exit 1
      ;;
    *)
      display_usage
      exit 1
      ;;
  esac
done

if [[ -n "$GIT_USERNAME" && -n "$GIT_PASSWORD" ]]; then
    GIT_ORIGIN="https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/khulnasoft/OSVIC"
fi

start_time=$(date -u +%s)
echo "[+] Started at $(date -u)"

current_date=$(date -u +"%Y-%m-%d")
current_datetime=$(date -u +"%Y-%m-%d %H:%M:%S")

echo "[+] Pulling latest updates from GitHub"
git pull --rebase || { echo "Error: Git pull failed."; exit 1; }

if [ $DO_DATA_UPDATE -eq 1 ]; then
    echo "[+] Updating data..."
    env/bin/python CWE/fetch-and-update.py
    env/bin/python CPE/fetch-and-update.py
    env/bin/python CVE/fetch-and-update.py
    env/bin/python VIA/fetch-and-update.py
    env/bin/python EPSS/fetch-and-update.py
    env/bin/python KEV/fetch-and-update.py
fi

echo "$current_datetime" > lastupdate.txt

if [ $DO_PUSH -eq 1 ]; then
    echo "[+] Preparing to push updates..."
    git add .
    
    if git diff-index --quiet HEAD --; then
        echo "[+] No changes detected, skipping commit."
    else
        git commit -m "data-update-${current_datetime}"
        git push ${GIT_ORIGIN} :refs/tags/$current_date
        git tag -f $current_date
        git push ${GIT_ORIGIN} --tags
        git push ${GIT_ORIGIN} HEAD
    fi
fi

end_time=$(date -u +%s)
elapsed=$((end_time - start_time))
echo "[+] Completed in $elapsed seconds."
