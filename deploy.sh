#!/bin/bash
set -e  # 任何一步出错就停止

echo "=== 0. 验证 Emacs 版本 ==="
MIN_VERSION="24.5"

if command -v emacs &>/dev/null; then
    # 读取当前版本号（只取前三个数字段，如 29.4.1 -> 29.4.1）
    CURRENT_VERSION=$(emacs --version | head -n1 | sed -E 's/.*Emacs ([0-9.]+).*/\1/')
    echo "    检测到 Emacs 版本: $CURRENT_VERSION"

    # 用 sort -V 做版本比较：如果 MIN_VERSION 排在 CURRENT_VERSION 后面，说明当前版本够新
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

if [ "$NEED_INSTALL" -eq 1 ]; then
    echo ""
    echo "=== 0.5 安装/升级 Emacs ==="

    # 先更新 apt 源
    sudo apt update

    # 尝试安装 emacs（apt 里的版本可能比较旧，但至少是 28+ 了）
    sudo apt install -y emacs

    # 验证安装结果
    NEW_VERSION=$(emacs --version | head -n1 | sed -E 's/.*Emacs ([0-9.]+).*/\1/')
    echo "    安装完成，当前版本: $NEW_VERSION"

    # 再次检查版本是否达标
    if [ "$(printf '%s\n' "$MIN_VERSION" "$NEW_VERSION" | sort -V | head -n1)" != "$MIN_VERSION" ]; then
        echo ""
        echo "    ⚠️  apt 源中的 Emacs 版本 ($NEW_VERSION) 仍低于 $MIN_VERSION"
        echo "    📦 尝试添加 PPA 获取更新版本..."

        # 添加 PPA（Ubuntu 专用，Debian 用户需要手动处理）
        if command -v add-apt-repository &>/dev/null; then
            sudo add-apt-repository -y ppa:ubuntuhandbook1/emacs
            sudo apt update
            sudo apt install -y emacs

            FINAL_VERSION=$(emacs --version | head -n1 | sed -E 's/.*Emacs ([0-9.]+).*/\1/')
            echo "    PPA 安装完成，当前版本: $FINAL_VERSION"
        else
            echo "    ⚠️  无法添加 PPA（非 Ubuntu 系统？）"
            echo "    请手动从 https://www.gnu.org/software/emacs/ 下载安装最新版"
            echo "    或运行: sudo apt install -y software-properties-common 后再试"
        fi
    fi
fi

echo ""
echo "=== 1. 清理旧的 Emacs 配置 ==="
cd ~
rm -f .emacs .emacs.custom.el
rm -rf .emacs.local .emacs.rc .emacs.snippets

echo "=== 2. 创建 dotfiles 目录 ==="
mkdir -p ~/dotfiles
cd ~/dotfiles

echo "=== 3. 查找并解压 emacs-config.zip ==="
if [ -f ~/emacs-config.zip ]; then
    mv ~/emacs-config.zip ~/dotfiles/
elif [ ! -f ~/dotfiles/emacs-config.zip ]; then
    echo "❌ 错误：找不到 emacs-config.zip！请先把它放到 ~/ 或 ~/dotfiles/ 下"
    exit 1
fi

unzip -o emacs-config.zip

echo "=== 4. 建立软链接 ==="
ln -sf "$(pwd)/.emacs" ~/.emacs
ln -sf "$(pwd)/.emacs.custom.el" ~/.emacs.custom.el
ln -sf "$(pwd)/.emacs.local" ~/.emacs.local
ln -sf "$(pwd)/.emacs.rc" ~/.emacs.rc
ln -sf "$(pwd)/.emacs.snippets" ~/.emacs.snippets

echo "=== 4.5 写入自定义配置到 .emacs 开头 ==="
cat > /tmp/emacs-header.el << 'HEADER'
;; 彻底关闭 tree-sitter
(setq major-mode-remap-alist nil)
(dolist (mode '(c-mode c++-mode c-or-c++-mode json-mode java-mode python-mode
                       go-mode rust-mode typescript-mode javascript-mode
                       bash-mode css-mode html-mode yaml-mode))
  (add-to-list 'major-mode-remap-alist `(,mode)))

;; 跳过包签名验证
(setq package-check-signature nil)

;; 设置代理
(setq url-proxy-services
      '(("http" . "192.168.254.1:7890")
        ("https" . "192.168.254.1:7890")))

(setq custom-file "~/.emacs.custom.el")
(package-initialize)

HEADER

# 把自定义头部插入到 .emacs 最前面
cat /tmp/emacs-header.el "$(pwd)/.emacs" > /tmp/.emacs.new
mv /tmp/.emacs.new "$(pwd)/.emacs"
rm -f /tmp/emacs-header.el

echo "=== 5. 验证链接 ==="
ls -la ~/.emacs*

echo ""
echo "=== 6. 最终版本确认 ==="
emacs --version | head -n1

echo ""
echo "=== 7. 启动 Emacs (--debug-init) ==="
echo "   关闭 Emacs 后脚本结束。"
emacs --debug-init

echo ""
echo "✅ 全部完成！"
