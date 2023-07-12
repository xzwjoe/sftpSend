#!/bin/bash
# ログローテーション

# -------------------------------------------------------------------------------------------------------
# スクリプトが実行されたパスを取得
# -------------------------------------------------------------------------------------------------------
script_executed_dir=$(cd "$(dirname "${BASH_SOURCE:-$0}")" || exit; pwd)

# -------------------------------------------------------------------------------------------------------
# 環境変数設定ファイル「environment.conf」読み込み
# 以後、ファイルに記載された変数が使用可能になる。
# -------------------------------------------------------------------------------------------------------
if [ -f "${script_executed_dir}/environment.conf" ]; then
  source "${script_executed_dir}/environment.conf"
else
  echo "Config file ${script_executed_dir}/environment.conf Not Found." >&2
  exit 1
fi

LOGFILE="${APPLICATION_LOG_DIR}/$(basename "$0" .sh).log"

# 更新日時でファイルを削除
#echo "削除:" >> "$LOGFILE" 2>&1
#find "${APPLICATION_LOGBK_DIR}"/* -mtime +30 >> "$LOGFILE" 2>&1
#find "${APPLICATION_LOGBK_DIR}"/* -mtime +30 -exec rm -f {} \;

MAX_GEN=10
dt=$(date +%Y%m%d)
BACKUP_FILENAME="_log_${dt}.gz"

# NO LOG END
if [ "$(find "${APPLICATION_LOG_DIR}" -name "*.log" | wc -l)" -eq 0 ]; then
  exit 0
fi

# ローテーション
for ((i = MAX_GEN; i > 0; i--)); do
  FILE=$(find "${APPLICATION_LOGBK_DIR}" -name "${i}_*.gz")
  if [ -z "$FILE" ]; then
    continue
  fi

  if [ "$i" -eq "$MAX_GEN" ]; then
    rm -f "$FILE"
  else
    AFTER=$(basename "$FILE" | sed -e "s/$i/$((i+1))/")
    mv "$FILE" "${APPLICATION_LOGBK_DIR}/${AFTER}"
  fi
done

# gzip
cd "$APPLICATION_LOG_DIR" || exit
tar czf "${dt}.tar.gz" *.log
mv "${dt}.tar.gz" "${APPLICATION_LOGBK_DIR}/1${BACKUP_FILENAME}"
rm -f "${APPLICATION_LOG_DIR}"/*.log

exit 0