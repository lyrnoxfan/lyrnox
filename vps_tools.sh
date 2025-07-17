# 主菜单
show_menu() {
    clear
    echo "==============================="
    echo "         VPS 工具箱            "
    echo "==============================="
    echo "1. 更新系统组件"
    echo "2. DD系统"
    echo "3. 八合一节点工具箱"
    echo "4. 更改DNS配置"
    echo "5. VPS压力测试"
    echo "6. 流量消耗器"
    echo "7. VPS性能测试"
    echo "8. 安装Openlist"
    echo "9. 安装1Panel"
    echo "10. 显示VPS信息"
    echo "11. 更换系统镜像源"
    echo "12. root用户管理"
    echo "13. 安装Docker和Compose"
    echo "14. speedtest测速"
    echo "15. 哪吒面板"
    echo "0. 退出"
    echo "==============================="
    read -p "请输入选项 [0-15]: " option
    return $option
}

# 更新组件
update_components() {
    echo "正在更新系统组件..."
    apt update -y && apt upgrade -y && apt install -y \
    curl wget sudo socat net-tools htop gnupg2 jq \
    unzip zip git make dnsutils iputils-ping tmux ufw ca-certificates
    echo -e "\n\033[32m组件更新完成！\033[0m"
    sleep 2
}

# DD系统
dd_system() {
    echo "准备DD系统..."
    curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O reinstall.sh $_
    if [ $? -ne 0 ]; then
        echo -e "\033[31m下载DD脚本失败！\033[0m"
        return
    fi
    
    chmod +x reinstall.sh
    echo "1. 安装飞牛系统"
    echo "2. 自定义DD"
    read -p "请选择 [1-2]: " choice
    
    case $choice in
        1) bash reinstall.sh fnos ;;
        2) bash reinstall.sh ;;
        *) echo "无效选择" ;;
    esac
}

# 节点工具箱
node_toolkit() {
    echo "安装八合一节点工具箱..."
    bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)
}

# 更改DNS
change_dns() {
    cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 2606:4700:4700::1111
nameserver 2606:4700:4700::1001
nameserver 2001:4860:4860::8888
nameserver 2001:4860:4860::8844
EOF
    echo -e "\033[32mDNS配置已更新！\033[0m"
    service networking restart
    sleep 2
}

# 压力测试
stress_test() {
    echo "警告：此操作将消耗大量资源！"
    read -p "确定继续吗？(y/n) " confirm
    [ "$confirm" != "y" ] && return
    
    cat > stress_test.sh <<'EOF'
#!/bin/bash
# 压力测试
TARGET_DIR="/tmp/stress_test"
MEM_SAFETY_GAP="0.5"
DISK_SAFETY_GAP="1"

cleanup() {
    kill -9 $MEM_PID $DISK_PID $CPU_PID >/dev/null 2>&1
    rm -rf $TARGET_DIR
    exit 0
}

trap cleanup SIGTERM SIGINT

mkdir -p $TARGET_DIR
cd $TARGET_DIR || exit 1

# 内存测试
mem_test() {
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    safety_kb=$((total_mem_kb * ${MEM_SAFETY_GAP%.*} / 100))
    alloc_kb=$((total_mem_kb - safety_kb))
    while true; do
        stress-ng --vm 1 --vm-bytes ${alloc_kb}K --vm-keep
        sleep 1
    done
}

# 磁盘测试
disk_test() {
    while true; do
        disk_info=($(df -k $TARGET_DIR | awk 'NR==2{print $2,$4}'))
        total_disk=${disk_info[0]}
        free_space=${disk_info[1]}
        safety_margin=$((total_disk * ${DISK_SAFETY_GAP%.*} / 100))
        fill_size_mb=$(( (free_space - safety_margin) / 1024 ))
        [ $fill_size_mb -lt 10 ] && fill_size_mb=10
        dd if=/dev/urandom of=testfile bs=1M count=$fill_size_mb status=none
        rm testfile
        sleep 1
    done
}

# CPU测试
cpu_test() {
    while true; do
        stress-ng --cpu $(nproc)
        sleep 1
    done
}

mem_test &
MEM_PID=$!

disk_test &
DISK_PID=$!

cpu_test &
CPU_PID=$!

echo "压力测试已在后台永久运行 (PID: $MEM_PID, $DISK_PID, $CPU_PID)"
echo "要停止测试，请执行: kill -9 $MEM_PID $DISK_PID $CPU_PID"

# 永久等待
while true; do
    sleep 3600
done
EOF

    chmod +x stress_test.sh
    nohup ./stress_test.sh > stress.log 2>&1 &
    
    # 获取并显示进程ID
    STRESS_PID=$!
    echo -e "\033[32m压力测试已在后台启动！\033[0m"
    echo "日志文件: $(pwd)/stress.log"
    echo "主进程PID: $STRESS_PID"
    echo "停止命令: kill -9 $STRESS_PID"
    sleep 2
}

# 流量消耗
traffic_consumer() {
    if [ ! -f webBenchmark_linux_x64 ]; then
        wget https://github.com/maintell/webBenchmark/releases/download/0.5/webBenchmark_linux_x64
        chmod +x webBenchmark_linux_x64
    fi
    
    echo "1. 默认URL"
    echo "2. 自定义URL"
    read -p "请选择 [1-2]: " choice
    
    case $choice in
        1) url='https://v.qianguolive.cn/v/0c9d872c-9579-4592-8502-21920a9353c5.mp4' ;;
        2) read -p "输入URL: " url ;;
        *) echo "无效选择"; return ;;
    esac
    
    nohup ./webBenchmark_linux_x64 -c 64 -s "$url" > traffic.log 2>&1 &
    echo -e "\033[32m流量消耗已启动！\033[0m"
    echo "日志文件: $(pwd)/traffic.log"
    sleep 2
}

# VPS测试
vps_test() {
    bash <(curl -sL https://run.NodeQuality.com)
}

# 安装Openlist
install_openlist() {
    echo "正在安装Openlist..."
    
    # 创建数据目录
    mkdir -p /opt/openlist/data
    
    # 运行容器
    docker run -d \
      --name=openlist \
      -p 5244:5244 \
      -v /opt/openlist/data:/opt/alist/data \
      alliot/alist:latest
    
    # 获取容器ID
    CONTAINER_ID=$(docker ps -aqf "name=openlist")
    
    if [ -z "$CONTAINER_ID" ]; then
        echo -e "\033[31mOpenlist容器启动失败！\033[0m"
        return
    fi
    
    echo "等待容器启动..."
    sleep 10
    
    # 设置管理员密码
    echo "请设置管理员密码："
    read -p "输入新密码: " admin_pass
    
    if [ -n "$admin_pass" ]; then
        docker exec -it openlist /bin/sh -c "./alist admin set $admin_pass"
        echo -e "\033[32m管理员密码已设置！\033[0m"
    else
        echo "跳过密码设置，稍后请手动设置。"
    fi
    
    IP_ADDR=$(curl -4s ip.sb || echo "localhost")
    echo -e "\033[32mOpenlist安装完成！\033[0m"
    echo "访问地址: http://$IP_ADDR:5244"
    echo "数据目录: /opt/openlist/data"
    sleep 2
}

# 安装1Panel
install_1panel() {
    echo "正在安装1Panel..."
    curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh
    bash quick_start.sh
}

# 显示系统信息
show_info() {
    echo -e "\n\033[34m===== 系统信息 =====\033[0m"
    echo "CPU型号: $(lscpu | grep 'Model name' | cut -d':' -f2 | sed 's/^ *//')"
    echo "CPU核心: $(nproc)"
    echo "内存大小: $(free -h | awk '/Mem/{print $2}')"
    echo "硬盘空间: $(df -h / | awk 'NR==2{print $2}')"
    echo "系统版本: $(lsb_release -d | cut -d':' -f2 | sed 's/^ *//')"
    echo "公网IPv4: $(curl -4s ip.sb)"
    echo "公网IPv6: $(curl -6s ip.sb 2>/dev/null || echo 'N/A')"
    echo -e "\n按任意键继续..."
    read -n1
}

# 更换镜像源
change_repo() {
    # 备份原始源
    backup_file="/etc/apt/sources.list.bak_$(date +%Y%m%d%H%M%S)"
    cp /etc/apt/sources.list "$backup_file"
    echo -e "\033[33m已备份原始源文件到: $backup_file\033[0m"
    
    # 获取系统版本代号
    codename=$(lsb_release -cs)
    
    echo "请选择镜像源:"
    echo "1. Debian 官方默认源"
    echo "2. 清华大学镜像源"
    echo "3. 自定义镜像源"
    read -p "输入选项 [1-3]: " choice
    
    case $choice in
        1)
            # Debian 官方默认源
            cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian $codename main contrib non-free
deb http://deb.debian.org/debian $codename-updates main contrib non-free
deb http://deb.debian.org/debian $codename-backports main contrib non-free
deb http://security.debian.org/debian-security $codename-security main contrib non-free
EOF
            echo -e "\033[32m已设置为 Debian 官方默认源\033[0m"
            ;;
        2)
            # 清华大学镜像源
            cat > /etc/apt/sources.list <<EOF
# 清华大学镜像源
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $codename main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ $codename main contrib non-free

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $codename-updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ $codename-updates main contrib non-free

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $codename-backports main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ $codename-backports main contrib non-free

# 安全更新
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security $codename-security main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security $codename-security main contrib non-free
EOF
            echo -e "\033[32m已设置为清华大学镜像源\033[0m"
            ;;
        3)
            # 自定义镜像源
            custom_sources="/etc/apt/sources.list.custom"
            > "$custom_sources"  # 清空文件
            
            echo "请输入自定义镜像源 (每行一个源，输入 'n' 结束):"
            i=1
            while true; do
                read -p "源 $i: " source_line
                if [ "$source_line" = "n" ]; then
                    break
                fi
                echo "$source_line" >> "$custom_sources"
                i=$((i+1))
                
                # 询问是否继续添加
                read -p "是否继续添加？(y/n) " continue_adding
                if [ "$continue_adding" = "n" ]; then
                    break
                fi
            done
            
            if [ -s "$custom_sources" ]; then
                cp "$custom_sources" /etc/apt/sources.list
                echo -e "\033[32m已应用自定义镜像源\033[0m"
            else
                echo -e "\033[31m未输入任何有效源，源文件未更改\033[0m"
            fi
            ;;
        *)
            echo -e "\033[31m无效选项，源文件未更改\033[0m"
            return
            ;;
    esac
    
    # 更新软件包列表
    echo "正在更新软件包列表..."
    apt update
    sleep 2
}

# 安装Docker和Compose
install_docker_compose() {
    echo "正在安装Docker和Docker Compose..."
    
    # 检查是否已安装
    if command -v docker &> /dev/null; then
        echo -e "\033[33mDocker 已安装，跳过安装步骤\033[0m"
    else
        # 安装Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        echo -e "\033[32mDocker 安装完成！\033[0m"
    fi
    
    # 安装Docker Compose
    if command -v docker-compose &> /dev/null; then
        echo -e "\033[33mDocker Compose 已安装，跳过安装步骤\033[0m"
    else
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo -e "\033[32mDocker Compose 安装完成！\033[0m"
    fi
    
    # 启动Docker并设置开机自启
    systemctl start docker
    systemctl enable docker
    
    # 验证安装
    echo -e "\n\033[34m===== 验证安装 =====\033[0m"
    docker --version
    docker-compose --version
    
    echo -e "\033[32mDocker和Docker Compose安装完成！\033[0m"
    sleep 2
}

# root用户管理
root_management() {
    echo "===== root用户管理 ====="
    echo "1. 切换root用户"
    echo "2. 更改root密码"
    echo "3. 远程root登录控制"
    echo "0. 返回主菜单"
    read -p "请选择 [0-3]: " choice
    
    case $choice in
        1)
            if [ "$EUID" -eq 0 ]; then
                echo -e "\033[33m已经是root用户！\033[0m"
            else
                echo "切换至root用户..."
                sudo -i
            fi
            ;;
        2)
            echo "更改root密码..."
            passwd root
            ;;
        3)
            # 检查是否root用户
            if [ "$EUID" -ne 0 ]; then
                echo -e "\033[31m此功能需要root权限！请使用sudo运行本脚本\033[0m"
                return
            fi
            
            # 远程root登录控制
            echo "1. 允许远程root登录"
            echo "2. 禁止远程root登录"
            echo "3. 查看当前状态"
            read -p "请选择 [1-3]: " remote_choice
            
            case $remote_choice in
                1)
                    # 检查并修改配置
                    if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
                        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
                    else
                        echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
                    fi
                    
                    # 重启SSH服务
                    systemctl restart sshd
                    echo -e "\033[32m已允许远程root登录\033[0m"
                    ;;
                2)
                    # 检查并修改配置
                    if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
                        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
                    else
                        echo "PermitRootLogin no" >> /etc/ssh/sshd_config
                    fi
                    
                    # 重启SSH服务
                    systemctl restart sshd
                    echo -e "\033[32m已禁止远程root登录\033[0m"
                    ;;
                3)
                    # 显示当前状态
                    sshd_config="/etc/ssh/sshd_config"
                    permit_root=$(grep -i "^PermitRootLogin" $sshd_config || echo "PermitRootLogin yes (默认)")
                    password_auth=$(grep -i "^PasswordAuthentication" $sshd_config || echo "PasswordAuthentication yes (默认)")
                    
                    echo -e "\n\033[34m===== SSH配置状态 =====\033[0m"
                    echo "远程root登录: $permit_root"
                    echo "密码认证: $password_auth"
                    echo "配置路径: $sshd_config"
                    echo -e "\n按任意键继续..."
                    read -n1
                    ;;
                *)
                    echo "无效选择"
                    return
                    ;;
            esac
            ;;
        0)
            return
            ;;
        *)
            echo "无效选项"
            ;;
    esac
    sleep 2
}

# speedtest测速
speed_test() {
    echo "准备安装speedtest测速工具..."
    
    # 检查是否已安装
    if command -v speedtest &> /dev/null; then
        echo "speedtest已安装，直接运行测速..."
        speedtest
        return
    fi
    
    # 清理旧版本
    echo "清理旧版本..."
    rm -f /etc/apt/sources.list.d/speedtest.list >/dev/null 2>&1
    
    # 更新软件包列表
    apt-get update -y
    
    # 卸载冲突包
    echo "移除冲突包..."
    apt-get remove -y speedtest speedtest-cli >/dev/null 2>&1
    
    # 安装依赖
    echo "安装依赖..."
    apt-get install -y curl
    
    # 添加官方仓库
    echo "添加官方仓库..."
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
    
    # 安装speedtest
    echo "安装speedtest..."
    apt-get install -y speedtest
    
    # 验证安装
    if ! command -v speedtest &> /dev/null; then
        echo -e "\033[31mspeedtest安装失败！\033[0m"
        return
    fi
    
    echo -e "\n\033[32mspeedtest安装完成！开始测速...\033[0m"
    speedtest
    echo -e "\n测速完成！"
    sleep 2
}

# 哪吒面板
nezha_panel() {
    echo "正在安装哪吒面板..."
    curl -L https://raw.githubusercontent.com/nezhahq/scripts/refs/heads/main/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh
    echo -e "\033[32m哪吒面板安装完成！\033[0m"
    sleep 2
}

# 主循环
while true; do
    show_menu
    case $? in
        1) update_components ;;
        2) dd_system ;;
        3) node_toolkit ;;
        4) change_dns ;;
        5) stress_test ;;
        6) traffic_consumer ;;
        7) vps_test ;;
        8) install_openlist ;;
        9) install_1panel ;;
        10) show_info ;;
        11) change_repo ;;
        12) root_management ;;
        13) install_docker_compose ;;
        14) speed_test ;;
        15) nezha_panel ;;
        0) exit 0 ;;
        *) echo "无效选项"; sleep 1 ;;
    esac
done