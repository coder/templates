#!/usr/bin/env bash

install_rbase() {
    sudo apt-get -qq install -y --no-install-recommends \
        software-properties-common \
        gdebi-core \
        dirmngr \
        net-tools >/dev/null
    sudo add-apt-repository \
        "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
    sudo apt-get -qq install -y --no-install-recommends \
        r-base >/dev/null
}

run_rstudio_server() {
    if [ ! -z "${PID_PATH}" ] || [ ! -s "${PID_PATH}" ]; then
        touch ${PID_PATH}
        curl -fsSL -o /tmp/${RSTUDIO_PKG} ${INSTALL_FROM}/${RSTUDIO_PKG}
        echo "y" | sudo gdebi --non-interactive /tmp/${RSTUDIO_PKG} -q -
    fi
    sudo kill $(cat ${PID_PATH})
    if [ -z "${DATA_DIR}/rstudio-rserver/session-server-rpc.socket" ]; then
        sudo rm "${DATA_DIR}/rstudio-rserver/session-server-rpc.socket"
    else
        echo "'session-server-rpc.socket' does not exist! Skipping..."
    fi
    /usr/lib/rstudio-server/bin/rserver
    echo "RStudio Server Started 🥳."
    if [ -z "/home/coder/.local/share/rstudio/log/rserver.log" ]; then
        echo "Printing RStudio logs to stdout."
        cat /home/coder/.local/share/rstudio/log/rserver.log
    fi   
}

sudo locale-gen en_US.UTF-8
sudo apt -qq update
sudo apt -qq upgrade

if [ ! -d "/home/coder/.rstudio" ]; then
    mkdir -p /home/coder/.rstudio/
fi
if [ ! -d "/etc/rstudio/" ]; then
    sudo mkdir -p /etc/rstudio/
    sudo touch /etc/rstudio/{rserver.conf,database.conf}
fi

install_rbase

sudo chown -R coder:coder \
    /home/coder/.rstudio \
    /etc/rstudio

cat <<EOF > /etc/rstudio/rserver.conf
server-user=${USER}
server-daemonize=1
server-data-dir=${DATA_DIR}
server-pid-file=${PID_PATH}
auth-none=1
www-frame-origin=same
www-address=127.0.0.1
www-port=${RSTUDIO_PORT}
www-root-path=/@${CODER_USER}/${WORKSPACE_NAME}.coder/apps/${CODER_APP_NAME}/
database-config-file=/etc/rstudio/database.conf
EOF

cat <<EOF > /etc/rstudio/database.conf
provider=sqlite
directory=${DB_DIR}
EOF

run_rstudio_server