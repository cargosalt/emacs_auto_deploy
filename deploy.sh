#!/bin/bash
set -e

echo "========================================="
echo "  Emacs 配置一键部署脚本 (deploy.sh)"
echo "========================================="

# ---------- 0. 验证 Emacs 版本 ----------
echo ""
echo ">>> [0/6] 验证 Emacs 版本..."
MIN_VERSION="24.5"

if command -v emacs &>/dev/null; then
    CURRENT_VERSION=$(emacs --version | head -n1 | sed -E 's/.*Emacs ([0-9.]+).*/\1/')
    echo "    检测到 Emacs 版本: $CURRENT_VERSION"

    if [ "$(printf '%s\n' "$MIN_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" = "$MIN_VERSION" ]; then
        echo "    ✅ 版本 >= $MIN_VERSION，符合要求"
        NEED_INSTALL=0
    else
        echo "    ⚠️  版本低于 $MIN_VERSION，需要升级"
        NEED_INSTALL=1
    fi
else
    echo "    ⚠️  未检测到 Emacs，需要安装"
    NEED_INSTALL=1
fi

# ---------- 0.5 安装/升级 Emacs（先测后修） ----------
if [ "$NEED_INSTALL" -eq 1 ]; then
    echo ""
    echo ">>> [0.5/6] 安装/升级 Emacs..."

    # 先尝试正常更新，成功就跳过换源
    echo "    📡 尝试更新软件源..."
    if sudo apt update -y; then
        echo "    ✅ 软件源正常，无需修复"
    else
        echo "    ⚠️  apt update 失败，尝试自动修复软件源..."
        if [ -f /etc/apt/sources.list ]; then
            sudo sed -i 's|cn.archive.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list 2>/dev/null || true
            sudo sed -i 's|security.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list 2>/dev/null || true
            echo "    🔧 已将问题源替换为清华镜像"
        fi
        sudo rm -rf /var/lib/apt/lists/*
        sudo apt update -y || true
    fi

    # 安装 Emacs
    echo "    📦 安装 Emacs..."
    sudo apt install -y emacs

    # 验证
    if command -v emacs &>/dev/null; then
        NEW_VERSION=$(emacs --version | head -n1 | sed -E 's/.*Emacs ([0-9.]+).*/\1/')
        echo "    ✅ 安装完成，当前版本: $NEW_VERSION"
    else
        echo "    ❌ Emacs 安装失败！请手动运行: sudo apt install -y emacs"
        exit 1
    fi
fi

# ---------- 1. 清理旧配置 ----------
echo ""
echo ">>> [1/6] 清理旧的 Emacs 配置..."
cd ~
rm -f .emacs .emacs.custom.el
rm -rf .emacs.local .emacs.rc .emacs.snippets
echo "    ✅ 旧配置已清理。"

# ---------- 2. 创建 dotfiles 目录 ----------
echo ""
echo ">>> [2/6] 创建 ~/dotfiles 目录..."
mkdir -p ~/dotfiles
cd ~/dotfiles
echo "    ✅ 目录就绪: $(pwd)"

# ---------- 3. 查找并解压 zip ----------
echo ""
echo ">>> [3/6] 解压配置文件..."

ZIP_SRC=""
if [ -f ~/emacs_auto_deploy-main/emacs-config.zip ]; then
    ZIP_SRC=~/emacs_auto_deploy-main/emacs-config.zip
elif [ -f ~/dotfiles/emacs-config.zip ]; then
    ZIP_SRC=~/dotfiles/emacs-config.zip
elif ls ~/*.zip 1>/dev/null 2>&1; then
    ZIP_SRC=$(ls ~/*.zip | head -n1)
fi

if [ -z "$ZIP_SRC" ]; then
    echo "    ❌ 错误：找不到 emacs-config.zip！"
    echo "       请先把它放到 ~/emacs_auto_deploy-main/ 或 ~/dotfiles/ 下"
    exit 1
fi

echo "    找到: $ZIP_SRC"
cp "$ZIP_SRC" ~/dotfiles/emacs-config.zip
unzip -o ~/dotfiles/emacs-config.zip
echo "    ✅ 解压完成。"

# ---------- 4. 建立软链接 ----------
echo ""
echo ">>> [4/6] 建立软链接到 home 目录..."
ln -sf "$(pwd)/.emacs" ~/.emacs
ln -sf "$(pwd)/.emacs.custom.el" ~/.emacs.custom.el
ln -sf "$(pwd)/.emacs.local" ~/.emacs.local
ln -sf "$(pwd)/.emacs.rc" ~/.emacs.rc
ln -sf "$(pwd)/.emacs.snippets" ~/.emacs.snippets
echo "    ✅ 软链接已创建。"

# ---------- 5. 验证 ----------
echo ""
echo ">>> [5/6] 验证部署结果..."
echo ""
echo "  📁 ~/dotfiles/ 配置目录内容:"
ls -la ~/dotfiles/.emacs*
echo ""
echo "  🔗 home 目录软链接:"
ls -la ~/.emacs*
echo ""
echo "  📦 Emacs 版本:"
emacs --version | head -n1

# ---------- 6. 启动 Emacs ----------
echo ""
echo ">>> [6/6] 启动 Emacs (--debug-init)..."
echo "    关闭 Emacs 后脚本结束。"
echo ""
emacs --debug-init

echo ""
echo "========================================="
echo "  ✅ 全部完成！Emacs 已配置并启动。"
echo "========================================="
