#!/bin/bash

export V_PORT=${V_PORT:-'8080'}
export CFPORT=${CFPORT:-'443'}
export FILE_PATH=${FILE_PATH:-'/tmp'}
export UUID=${UUID:-'7160b696-dd5e-42e3-a024-145e92cec916'}
export VLESS_WSPATH=${VLESS_WSPATH:-'startvl'}
export CF_IP=${CF_IP:-'ip.sb'}
export openserver=${openserver:-'1'}
export openuscf=${openuscf:-'0'}
export NEZHA_VERSION=${NEZHA_VERSION:-'V0'}
export NEZHA_PORT=${NEZHA_PORT:-'443'}

if [ ! -d "$FILE_PATH" ]; then
  mkdir -p "${FILE_PATH}"
fi

cleanup_files() {
  rm -rf ${FILE_PATH}/*
}

# Download Dependency Files
download_program() {
  local program_name="$1"
  local default_url="$2"
  local x64_url="$3"

  local download_url
  case "$(uname -m)" in
    x86_64|amd64|x64)
      download_url="${x64_url}"
      ;;
    *)
      download_url="${default_url}"
      ;;
  esac

  if [ ! -f "${program_name}" ]; then
    if [ -n "${download_url}" ]; then
      echo "Downloading ${program_name}..." > /dev/null
      if command -v curl &> /dev/null; then
        curl -sSL "${download_url}" -o "${program_name}"
      elif command -v wget &> /dev/null; then
        wget -qO "${program_name}" "${download_url}"
      fi
      echo "Downloaded ${program_name}" > /dev/null
    else
      echo "Skipping download for ${program_name}" > /dev/null
    fi
  else
    echo "${program_name} already exists, skipping download" > /dev/null
  fi
}

initialize_downloads() {
  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ]; then
    case "${NEZHA_VERSION}" in
      "V0" )
        download_program "${FILE_PATH}/npm" "https://github.com/kahunama/myfile/releases/download/main/nezha-agent_arm" "https://github.com/kahunama/myfile/releases/download/main/nezha-agent"
        ;;
      "V1" )
        download_program "${FILE_PATH}/npm" "https://github.com/mytcgd/myfiles/releases/download/main/nezha-agentv1_arm" "https://github.com/mytcgd/myfiles/releases/download/main/nezha-agentv1"
        ;;
    esac
    sleep 3
    chmod +x ${FILE_PATH}/npm
  fi

  download_program "${FILE_PATH}/web" "https://github.com/mytcgd/myfiles/releases/download/main/xray_arm" "https://github.com/mytcgd/myfiles/releases/download/main/xray"
  sleep 3
  chmod +x ${FILE_PATH}/web

  if [ "${openserver}" -eq 1 ]; then
    download_program "${FILE_PATH}/server" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    sleep 3
    chmod +x ${FILE_PATH}/server
  fi
}

# my_config
my_config() {
  generate_config() {
  cat > ${FILE_PATH}/out.json << EOF
{
    "log": {
        "access": "/dev/null",
        "error": "/dev/null",
        "loglevel": "none"
    },
    "dns": {
        "servers": [
            "https+local://8.8.8.8/dns-query"
        ]
    },
    "inbounds": [
        {
            "port": ${V_PORT},
            "listen": "::",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "level": 0
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "/${VLESS_WSPATH}"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly": false
            }
        }
    ],
    "outbounds": [
        {
            "tag": "direct",
            "protocol": "freedom"
        },
        {
            "tag": "block",
            "protocol": "blackhole"
        }
    ]
}
EOF
  }

  argo_type() {
    if [ -e "${FILE_PATH}/server" ] && [ -z "${ARGO_AUTH}" ] && [ -z "${ARGO_DOMAIN}" ]; then
      echo "ARGO_AUTH or ARGO_DOMAIN is empty, use Quick Tunnels" > /dev/null
      return
    fi

    if [ -e "${FILE_PATH}/server" ] && [ -n "$(echo "${ARGO_AUTH}" | grep TunnelSecret)" ]; then
      echo ${ARGO_AUTH} > ${FILE_PATH}/tunnel.json
      cat > ${FILE_PATH}/tunnel.yml << EOF
tunnel=$(echo "${ARGO_AUTH}" | cut -d\" -f12)
credentials-file: ${FILE_PATH}/tunnel.json
protocol: http2

ingress:
  - hostname: ${ARGO_DOMAIN}
    service: http://localhost: ${V_PORT}
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
    else
      echo "ARGO_AUTH Mismatch TunnelSecret" > /dev/null
    fi
  }

  args() {
    case "$openuscf" in
      "0" )
        if [ ${openserver} -eq 1 ] && [ -e "${FILE_PATH}/server" ]; then
          if [ -n "$(echo "$ARGO_AUTH" | grep '^[A-Z0-9a-z=]\{120,250\}$')" ]; then
            args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
          elif [ -n "$(echo "$ARGO_AUTH" | grep TunnelSecret)" ]; then
            args="tunnel --edge-ip-version auto --config ${FILE_PATH}/tunnel.yml run"
          else
            args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile ${FILE_PATH}/boot.log --loglevel info --url http://localhost:${V_PORT}"
          fi
        fi
        ;;
      "1" )
        if [ ${openserver} -eq 1 ] && [ -e "${FILE_PATH}/server" ]; then
          if [ -n "$(echo "$ARGO_AUTH" | grep '^[A-Z0-9a-z=]\{120,250\}$')" ]; then
            args="tunnel --region us --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
          elif [ -n "$(echo "$ARGO_AUTH" | grep TunnelSecret)" ]; then
            args="tunnel --region us --edge-ip-version auto --config ${FILE_PATH}/tunnel.yml run"
          else
            args="tunnel --region us --edge-ip-version auto --no-autoupdate --protocol http2 --logfile ${FILE_PATH}/boot.log --loglevel info --url http://localhost:${V_PORT}"
          fi
        fi
        ;;
    esac
  }

  generate_config
  argo_type
  args
}

# generate_pm2_file
generate_pm2_file() {
  server_randomness=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 5)
  web_randomness=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 5)
  npm_randomness=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 5)

  if [ "${openserver}" -eq 1 ] && [ -e "${FILE_PATH}/server" ]; then
    mv ${FILE_PATH}/server ${FILE_PATH}/${server_randomness} && sleep 1
  fi
  if [ -e "${FILE_PATH}/web" ]; then
    mv ${FILE_PATH}/web ${FILE_PATH}/${web_randomness} && sleep 1
  fi

  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ] && [ -e "${FILE_PATH}/npm" ]; then
    mv ${FILE_PATH}/npm ${FILE_PATH}/${npm_randomness}
    case "$NEZHA_VERSION" in
      "V0" )
        tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
        if [[ " ${tlsPorts[@]} " =~ " ${NEZHA_PORT} " ]]; then
          NEZHA_TLS="--tls"
        else
          NEZHA_TLS=""
        fi
        NEZHA_RUNS="${FILE_PATH}/${npm_randomness} -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} --report-delay=4 --disable-auto-update"
        ;;
      "V1" )
        tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
        if [[ " ${tlsPorts[@]} " =~ " ${NEZHA_PORT} " ]]; then
          NEZHA_TLS="true"
        else
          NEZHA_TLS="false"
        fi
        cat > ${FILE_PATH}/config.yml << ABC
client_secret: $NEZHA_KEY
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 4
server: $NEZHA_SERVER:$NEZHA_PORT
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: $NEZHA_TLS
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: $UUID
ABC
        NEZHA_RUNS="${FILE_PATH}/${npm_randomness} -c ${FILE_PATH}/config.yml"
        ;;
    esac
  fi

  cat > ${FILE_PATH}/ecosystem.config.js << ABC
module.exports = {
  "apps":[
      {
          "name":"web",
          "script":"${FILE_PATH}/${web_randomness} run -c ${FILE_PATH}/out.json"
ABC
  if [ "${openserver}" -eq 1 ]; then
    cat >> ${FILE_PATH}/ecosystem.config.js << DEF
      },
      {
          "name":"server",
          "script":"${FILE_PATH}/${server_randomness} ${args}",
DEF
  fi
  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ]; then
    cat >> ${FILE_PATH}/ecosystem.config.js << GHI
      },
      {
          "name":"npm",
          "script":"${NEZHA_RUNS}",
GHI
  fi
  cat >> ${FILE_PATH}/ecosystem.config.js << JKL
      }
  ]
}
JKL
}

# run
run_processes() {
  generate_pm2_file

  if [ -e "${FILE_PATH}/ecosystem.config.js" ]; then
    pm2 start ${FILE_PATH}/ecosystem.config.js
  fi

  sleep 30

  export ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g') && sleep 1
  check_hostname_change && sleep 2

  if [ -n "$SUB_URL" ]; then
    upload >/dev/null 2>&1 &
  else
    build_urls
  fi
}

# check_hostname
check_hostname_change() {
  if [ -s "${FILE_PATH}/boot.log" ]; then
    export ARGO_DOMAIN=$(cat ${FILE_PATH}/boot.log | grep -o "info.*https://.*trycloudflare.com" | sed "s@.*https://@@g" | tail -n 1)
  fi
  if [ -n "${MY_DOMAIN}" ] && [ -z "${ARGO_DOMAIN}" ]; then
    export ARGO_DOMAIN="${MY_DOMAIN}"
  fi
  export UPLOAD_DATA="vless://${UUID}@${CF_IP}:${CFPORT}?host=${ARGO_DOMAIN}&path=%2F${VLESS_WSPATH}%3Fed%3D2048&type=ws&encryption=none&security=tls&sni=${ARGO_DOMAIN}#${ISP}-${SUB_NAME}"
}

# build_urls
build_urls() {
  if [ -n "${UPLOAD_DATA}" ]; then
    echo -e "${UPLOAD_DATA}" | base64 | tr -d '\n' > "${FILE_PATH}/log.txt"
  fi
}

# upload
upload_subscription() {
  if command -v curl &> /dev/null; then
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"URL_NAME\":\"$SUB_NAME\",\"URL\":\"$UPLOAD_DATA\"}" $SUB_URL)
  elif command -v wget &> /dev/null; then
    response=$(wget -qO- --post-data="{\"URL_NAME\":\"$SUB_NAME\",\"URL\":\"$UPLOAD_DATA\"}" --header="Content-Type: application/json" $SUB_URL)
  fi
}

export previousargoDomain=""
upload() {
  if [ ${openserver} -eq 1 ] && [ -z "${ARGO_AUTH}" ]; then
    while true; do
      if [[ "$previousargoDomain" == "$ARGO_DOMAIN" ]]; then
        echo "domain name has not been updated, no need to upload" > /dev/null
      else
        upload_subscription
        build_urls
        export previousargoDomain="$ARGO_DOMAIN"
      fi
      sleep 60
      check_hostname_change && sleep 2
    done
  else
    upload_subscription
    build_urls
  fi
}

# main
main() {
  cleanup_files
  initialize_downloads
  my_config
  run_processes
}
main
