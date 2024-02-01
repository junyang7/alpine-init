#!/usr/bin/env sh


set -e
ROOT=$(cd "$(dirname "$0")";cd .;pwd)


########################################################################################################################
# 填写你的信息
########################################################################################################################
HOST=
Us=
Root=
Addr=
Protocol=
Domain=


ssh-keygen -R ${HOST}
ssh-copy-id root@${HOST}
ssh root@${HOST} << 'EOF'
echo 'http://mirrors.ustc.edu.cn/alpine/v3.19/main
http://mirrors.ustc.edu.cn/alpine/v3.19/community
http://mirrors.ustc.edu.cn/alpine/edge/main
http://mirrors.ustc.edu.cn/alpine/edge/community
http://mirrors.ustc.edu.cn/alpine/edge/testing' > /etc/apk/repositories
apk update
apk add docker git bash vim htop tzdata
rc-update add docker boot && service docker restart
git config --global http.sslVerify false
git config --global init.defaultBranch master
mkdir -p /ziji/oss/git /ziji/oss/bin
reboot
EOF


sleep 30


rm -rf ${ROOT}/git-server
git clone https://github.com/junyang7/git-server.git ${ROOT}/git-server
cd ${ROOT}/git-server
awk '{gsub("{Us}", "'${Us}'"); gsub("{Root}", "'${Root}'"); gsub("{Addr}", "'${Addr}'"); gsub("{Protocol}", "'${Protocol}'"); gsub("{Domain}", "'${Domain}'"); print}' ${ROOT}/git-server/main.go > ${ROOT}/git-server/main.go.bak
mv ${ROOT}/git-server/main.go.bak ${ROOT}/git-server/main.go
bash build_linux.sh
cd ${ROOT}
scp -r -v ${ROOT}/git-server/git root@${HOST}:/ziji/oss/bin/


ssh root@${HOST} << 'EOF'
nohup /ziji/oss/bin/git > /ziji/oss/bin/git.log.$(date +\%Y\%m\%d) 2>&1 &
git init --bare /ziji/oss/git/user/repo.git
exit
EOF


########################################################################################################################
# 模拟应用代理机器
########################################################################################################################


ssh root@${HOST} << 'EOF'
apk add nginx
mv /etc/nginx/http.d/default.conf /etc/nginx/http.d/default.conf.bak
touch /etc/nginx/http.d/git.conf
echo 'server {
    listen                      80;
    server_name                 git.ziji.fun;
    location / {
        proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header        Host $http_host;
        proxy_redirect          off;
        proxy_pass              http://127.0.0.1:10000;
    }
}' > /etc/nginx/http.d/git.conf
nginx -t
rc-update add nginx boot
service nginx restart
service nginx status
exit
EOF


git clone http://${Domain}/user/repo test_1
cd test_1
echo 1 > 1
git add 1
git commit -m 1
git push
