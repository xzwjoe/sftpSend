#!/bin/bash
# -------------------------------------------------------------------------------------------------------
# SFTPでファイル送信(公開鍵認証)
# $1: 処理区分(1:ファイルリストTXTに記載あるファイルのみ転送、その他:ALL)
# $2: 送信するファイルが置かれたローカルパス
# $3: 対象HOST
# $4: 対象HOSTのディレクトリ
# -------------------------------------------------------------------------------------------------------

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

# -------------------------------------------------------------------------------------------------------
# 対象HOSTにファイルが存在するかのチェック
# TODO
# 戻り値：0(Existed) 1(Not Existed/OR Connection Error?)
# -------------------------------------------------------------------------------------------------------
function checkFileExist() {
  # $1: /path/filename
  # $2: host
  # $3: logfile

  sudo su - ALCSFTP -c "sftp -b <(echo \"get $1 /dev/null\") ${2}:/" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "ファイル存在: $1" >> "$3" 2>&1
    return 0
  fi
  return 1
}

# -------------------------------------------------------------------------------------------------------
# 対象HOSTにファイルを送信
# 戻り値：0(Succeed) 1(Failed)
# -------------------------------------------------------------------------------------------------------
function sendFile() {
  # $1: /path/filename
  # $2: hostのpath
  # $3: host
  # $4: logfile

  sudo su - ALCSFTP -c "sftp -b <(echo \"put $1 $2\") ${3}:/" >> "$4" 2>&1
  RTN=$?

  if [ ! "$RTN" -eq 0 ]; then
    echo "転送異常($RTN): $1" >> "$4" 2>&1
    return "$RTN"
  fi

  echo "転送完了: $1" >> "$4" 2>&1
  return 0
}

# 処理区分(1:ファイルリストTXTに記載あるファイルのみ転送、その他:ALL)
EXE_TYPE=$1
# ローカルパス
FOLDER=$2
# 対象HOST
TARGET_HOST=$3
# 対象HOSTのディレクトリ
TARGET_FOLDER=$4

RET=0

case $EXE_TYPE in
  "1")
    LOGFILE="${APPLICATION_LOG_DIR}/YN.log"
    SENDFILETXT="${YU_FILELIST_TXT}"
    ;;
  *)
    LOGFILE="${APPLICATION_LOG_DIR}/$(basename "$0" .sh).log"
    SENDFILETXT=""
esac

echo "$(date +%Y/%m/%d-%H:%M:%S) 処理開始(PID: $$)" >> "$LOGFILE" 2>&1

if [ $# -ne 4 ]; then
  echo "実行するには4個の引数が必要です。" >> "$LOGFILE" 2>&1
  exit 1
fi

FILELIST=("${FOLDER}"/*)
if [ ${#FILELIST[@]} -eq 0 ]; then
  echo "ファイルなし" >> "$LOGFILE" 2>&1
  exit 0
fi
echo "ファイル一覧：" >> "$LOGFILE" 2>&1
printf "%s\n" "${FILELIST[@]}" >> "$LOGFILE" 2>&1

echo "転送開始..." >> "$LOGFILE" 2>&1
# 1件ずつ転送
for file in "${FILELIST[@]}"; do

  # TXTが設定ありAND記載ないの場合はスキップ
  if [ -n "${SENDFILETXT}" ]; then
    if ! grep -qF "${file}" "${SENDFILETXT}"; then
      echo "ファイルリストに記載がない: $file" >> "$LOGFILE" 2>&1
      continue
    fi
  fi

  # ファイル存在チェック
  checkFileExist "${TARGET_FOLDER}/${file}" "${TARGET_HOST}" "${LOGFILE}"
  if [ $? -eq 0 ]; then
    # 存在の場合はスキップ
    RET=1
    continue
  fi

  # ファイル送信
  sendFile "${APPLICATION_SEND_DIR}/${file}" "${TARGET_FOLDER}" "${TARGET_HOST}" "${LOGFILE}"
  if [ $? -ne 0 ]; then
    # 失敗
    RET=1
    continue
  fi

  # バックアップ TODO
  TS=$(date +%Y%m%d%H%M%S%3N)
  BK_NAME=$(echo "$file" | sed "s/\(.*\)\./\1_$TS\./")

done

if [ $RET -eq 0 ]; then
  echo "$(date +%Y/%m/%d-%H:%M:%S) 処理終了(PID: $$)" >> "$LOGFILE" 2>&1
else
  echo "$(date +%Y/%m/%d-%H:%M:%S) 処理異常(PID: $$)" >> "$LOGFILE" 2>&1
fi

echo "" >> "$LOGFILE" 2>&1

exit "$RET"