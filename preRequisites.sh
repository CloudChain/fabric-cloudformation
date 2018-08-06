set -e

SDIR=$(dirname "$0")
cd ${SDIR}
source $SDIR/scripts/env.sh


# 安装Docker
# 当操作系统为aws ami 时使用yum 安装docker
yum install -y docker
/etc/init.d/docker start

# 其它linux 平台
#curl -fsSL get.docker.com -o get-docker.sh
#sh get-docker.sh

# 安装docker-compose
curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

# 下载fabirc 二进制及docker镜像
sh ${SDIR}/bootstrap.sh -b

# Start with a clean data directory
DDIR=${SDIR}/${DATA}
if [ -d ${DDIR} ]; then
   log "Cleaning up the data directory from previous run at $DDIR"
   rm -rf ${SDIR}/data
fi
mkdir -p ${DDIR}/logs
