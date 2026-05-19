# macOS Dotfile Sync —— 设计文档

**日期**：2026-05-19
**分支**：`feat/macos-dotfile-sync`
**目标**：把当前 macOS 上的 shell / 终端 / 工具 / 密钥配置，通过这个 dotfile 仓库可重复地复刻到新 macOS 上。

---

## 1. 目标与非目标

### 目标

- 新 macOS 装机后，能通过**一句命令**把以下内容恢复到与旧机一致的状态：
  - Homebrew 安装的 formula / cask / 字体
  - zsh 配置（`~/.zshrc`、`~/.p10k.zsh`、`~/.config/script/*.zsh`）
  - Git 全局配置（`~/.gitconfig`、`~/.gitignore_global`）
  - SSH 配置（`~/.ssh/config`）和私钥（`~/.ssh/id_*`、`*.pem`）
  - iTerm2 偏好设置
  - tmux / neovim / vim 配置
  - Maple Mono Nerd Font 字体
- 用 **GNU stow** 管理 `$HOME` 下的符号链接（替代当前手写的 `link.sh`）。
- 用 **age + passphrase** 加密 SSH 私钥后入库，passphrase 靠记忆，不依赖任何云服务或密码管理器。
- 一切操作幂等：重复跑 bootstrap 脚本不应破坏已有状态。

### 非目标（本次不做）

- **macOS 系统偏好**（`defaults write` Dock/Finder/键盘/触控板等）不同步。
- **1Password / SSH agent** 改造。
- **Ubuntu 侧**的重组（虽然新布局给 Ubuntu 留了位置，但 Ubuntu 相关包不在本次实现范围）。
- **GitHub CLI / `gh auth login`** 等需要交互登录的步骤的自动化。
- **kitty**：从仓库**彻底移除**（已不再使用）。
- **ClickHouse 相关**：`script/clickhouse_functions.zsh` 删除；`zsh-macos/.zshrc` 中所有 `CK_HOME`、`PATH:$CK_HOME`、`source clickhouse_functions.zsh` 行剥离。
- **pre-commit hook 等额外工具链**：用 `.gitignore` 兜底防止明文私钥误提交，不引入 husky/pre-commit 之类。

---

## 2. 仓库目标布局

每个一级目录（除了 `scripts/`、`docs/`、`secrets/` 和顶层文件）都是一个 **stow 包**，内部结构镜像到 `$HOME`。

```
dotfile/
├── README.md                      # 装机与日常使用说明（含命令清单、stow 包列表与对应路径）
├── Brewfile                       # brew bundle 输入
├── bootstrap-macos.sh             # 新机入口：brew → stow → iTerm2 prefs → decrypt-ssh
├── .gitignore                     # 兜底拦截明文私钥
│
├── scripts/
│   ├── encrypt-ssh.sh             # 旧 mac 用：~/.ssh/id_* → secrets/ssh/*.age
│   └── decrypt-ssh.sh             # 新 mac 用：secrets/ssh/*.age → ~/.ssh/，chmod 600
│
├── zsh-macos/                     # stow 包
│   └── .zshrc                     # → ~/.zshrc
├── zsh-ubuntu/                    # stow 包（保留位置，本次不动）
│   └── .zshrc
│
├── p10k-macos/
│   └── .p10k.zsh                  # → ~/.p10k.zsh
├── p10k-ubuntu/
│   └── .p10k.zsh
│
├── git/
│   ├── .gitconfig                 # → ~/.gitconfig
│   └── .gitignore_global          # → ~/.gitignore_global
│
├── ssh-config/
│   └── .ssh/
│       └── config                 # → ~/.ssh/config（known_hosts 不进库）
│
├── script/                        # 取代当前 link.sh 的功能
│   └── .config/script/
│       └── git_functions.zsh      # → ~/.config/script/git_functions.zsh
│
├── iterm2/                        # 不是 stow 包，由 iTerm2 自己读
│   └── com.googlecode.iterm2.plist
│
├── tmux/
│   └── .tmux.conf                 # → ~/.tmux.conf
├── nvim/
│   └── .config/nvim/...           # → ~/.config/nvim/...
├── vim/                           # 仅当旧 mac 有 vim 配置时建立
│   ├── .vimrc
│   └── .vim/
│
└── secrets/
    └── ssh/                       # age -p 密文
        ├── id_ed25519.age
        ├── id_ed25519.pub.age
        ├── zhanghongtai-jumpserver.pem.age
        └── starrocks-dev.age
```

### 关键改动相对当前仓库

| 现有 | 新结构 | 备注 |
|---|---|---|
| `init.sh`（Ubuntu apt） | 删除 | 不维护 Ubuntu 装机 |
| `link.sh` | 删除 | 由 `bootstrap-macos.sh` + stow 替代 |
| `macos/zsh/zshrc` | `zsh-macos/.zshrc` | 同时剥离 ClickHouse 相关行 |
| `macos/kitty/` | 删除整个目录 | 不再使用 kitty |
| `ubuntu/zsh/zshrc` | `zsh-ubuntu/.zshrc` | 仅搬运，不改 |
| `ubuntu/zsh/p10k.zsh` | `p10k-ubuntu/.p10k.zsh` | 同上 |
| `script/clickhouse_functions.zsh` | 删除 | 不同步 |
| `script/git_functions.zsh` | `script/.config/script/git_functions.zsh` | 调整为 stow 包内布局 |
| 无 | `iterm2/com.googlecode.iterm2.plist` | 旧 mac 上 iTerm2 配置写到这里 |
| 无 | `p10k-macos/.p10k.zsh` | 旧 mac 上 `~/.p10k.zsh` 拷过来 |
| 无 | `git/.gitconfig`、`git/.gitignore_global` | 旧 mac 拷过来 |
| 无 | `ssh-config/.ssh/config` | 旧 mac 拷过来 |
| 无 | `tmux/`、`nvim/`、`vim/` | 旧 mac 上有什么搬什么 |
| 无 | `Brewfile` | `brew bundle dump --describe` 产物 |
| 无 | `secrets/ssh/*.age` | age -p 加密的 SSH 私钥 |

---

## 3. bootstrap-macos.sh 总流程

### 用法

```sh
# 0. 提前手动
xcode-select --install
# 自行选目录 clone 仓库，不假定路径
git clone <repo-url> <自选路径>
cd <自选路径>

# 1. 一键
./bootstrap-macos.sh
```

脚本顶部用 `set -euo pipefail`；用 `REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"` 推导仓库根，**不写死任何 clone 路径**。

### 步骤

| # | 步骤 | 内容 | 失败处理 |
|---|---|---|---|
| 1 | install-homebrew | `command -v brew` 没有就跑官方 `/bin/bash -c "$(curl ...install.sh)"` | 非零退出立即停 |
| 2 | brew bundle | `brew bundle --file="$REPO_ROOT/Brewfile"` | 退出，让用户看 brew 报错 |
| 3 | stow packages | `cd "$REPO_ROOT" && stow -t "$HOME" zsh-macos p10k-macos git ssh-config script` + 检测存在的 `tmux nvim vim` 包后追加 stow | stow 默认行为：撞到已有非软链文件就报错退出，**不自动覆盖、不自动备份** |
| 4 | configure-iterm2 | `defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$REPO_ROOT/iterm2"`；`defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true` | 跳过（这两个 `defaults write` 不会失败） |
| 5 | decrypt-ssh | 调用 `scripts/decrypt-ssh.sh`，交互式提示 passphrase | passphrase 错就让用户重试；不破坏已有 `~/.ssh/` 文件 |
| 6 | post-install 提示 | 打印需要手动做的事：`chsh -s /opt/homebrew/bin/zsh`、第一次开 iTerm2 验证字体、`ssh -T git@github.com` 测试 | — |

### 设计约束

- **幂等**：每一步都允许重复跑。stow 重复 stow 无副作用；brew bundle 已装的会 skip；decrypt-ssh 遇到已存在目标会跳过（见 §4）。
- **不静默吞错**：`set -euo pipefail`，任何一步非零退出整脚本停。
- **不做需要 sudo 的事**：`chsh`、需要密码的 `defaults` 等只打印提示，让用户自己跑。
- **可单独执行**：每个步骤是独立函数或独立子脚本，可以单跑 `./scripts/decrypt-ssh.sh` 或 `brew bundle` 而不动其他。

---

## 4. SSH 私钥加解密流程

仓库里只存 `secrets/ssh/*.age`。明文私钥永远不出 `~/.ssh/`。

### `scripts/encrypt-ssh.sh`（旧 mac）

```
用途：把 ~/.ssh/ 里指定的私钥/pem 加密成 secrets/ssh/*.age

行为：
  1. 列出 ~/.ssh/ 下所有候选（id_*（不含 .pub）、*.pem、以及用户额外指定的文件）
  2. fzf 多选确认要加密的文件
  3. 提示输入一次 age passphrase（所有文件共用同一个）
  4. 对每个选中的 file：age -p -o "$REPO_ROOT/secrets/ssh/$(basename "$file").age" "$file"
  5. 打印 git status，让用户自己 git add / commit
```

### `scripts/decrypt-ssh.sh`（新 mac）

```
用途：把 secrets/ssh/*.age 解密回 ~/.ssh/，权限 600

行为：
  1. 扫描 "$REPO_ROOT/secrets/ssh/"*.age
  2. 提示输入一次 passphrase
  3. 对每个 file.age：
       target="$HOME/.ssh/${basename%.age}"
       如果 target 已存在 → 跳过 + 警告（不覆盖）
       否则 age -d 输出到 target，chmod 600
  4. （可选）对识别为常用 key 的文件跑 ssh-add --apple-use-keychain
```

### 策略

- **同一 passphrase 解所有 key**：减少操作摩擦；分级需求出现时再开 `secrets/ssh-prod/` 之类的独立子目录与独立 passphrase。
- **不覆盖已有文件**：decrypt 永远是"只补不覆盖"。要更新某个 key 的话，自己先 `rm ~/.ssh/<file>` 再跑。
- **.gitignore 兜底**：

  ```
  # 明文私钥/pem 永不入库（容错：万一忘了加密）
  secrets/ssh/id_*
  !secrets/ssh/id_*.age
  !secrets/ssh/id_*.pub.age
  secrets/ssh/*.pem
  !secrets/ssh/*.pem.age
  ```

- **passphrase 不存盘**：脚本读 stdin，不接环境变量、不写临时文件、不让 shell history 留痕。

### 长期风险（用户已确认接受）

- **passphrase 一旦忘记，仓库里所有 `.age` 文件都解不开**。
- **passphrase 强度建议**：4 个以上不相关的实词 + 数字符号，或 diceware 风格的 6 词以上。

---

## 5. 每项配置的迁移与日常维护

### Brewfile

- **旧 mac 一次性导出**：`brew bundle dump --file=Brewfile --force --describe`（`--describe` 加注释提升可读性）。
- **导出后用户手动清理**：只保留真正在用的 formula/cask/mas。
- **必加项**（dump 之外补的）：
  - `cask "font-maple-mono-nf"`（Maple Mono Nerd Font）
  - `brew "age"`、`brew "stow"`（bootstrap 自身依赖）
  - `brew "fzf"`、`brew "jq"`（encrypt-ssh 依赖 fzf 多选）
- **日常维护**：装新软件后手动跑一次 `brew bundle dump --file=Brewfile --force --describe`，commit。不做自动 hook。

### Git 全局配置

- **旧 mac 一次性**：`cp ~/.gitconfig git/.gitconfig`、`cp ~/.gitignore_global git/.gitignore_global`（前提：目录已存在 `git/`）。
- **新 mac**：`stow git`。

### zshrc & p10k

- `zsh-macos/.zshrc` = 现有 `macos/zsh/zshrc` 的副本，**剥离**以下行：
  - `export CK_HOME="/Users/heldon/Directory/Project/clickhouse/build/programs"`
  - `export PATH="$PATH:$CK_HOME"`
  - `source ~/.config/script/clickhouse_functions.zsh`
- **保留**两个 SSH alias，但调整路径与 decrypt-ssh 的落点对齐：
  - `alias jump="ssh -i ~/.ssh/zhanghongtai-jumpserver.pem zhanghongtai@jumpserver.devops.xiaohongshu.com"`（pem 路径从 `/Users/heldon/...` 改为 `~/.ssh/`）
  - `alias sr-dev='ssh -t -i ~/.ssh/starrocks-dev root@10.4.65.79 "tmux new-session -A -s main"'`（保持原样，已经是 `~/.ssh/`）
- `p10k-macos/.p10k.zsh` = 旧 mac 上 `~/.p10k.zsh` 原样拷贝；如果 `POWERLEVEL9K_MODE` 不是 `nerdfont-complete` 或 `nerdfont-v3`，改为 nerdfont 系列。
- Ubuntu 侧（`zsh-ubuntu/`、`p10k-ubuntu/`）：保留搬运，但**本次实现不动**，留 TODO。

### SSH config

- **旧 mac**：`cp ~/.ssh/config ssh-config/.ssh/config`。
- **新 mac**：`stow ssh-config`。
- `known_hosts` **不进仓库**，第一次连每个 host 重新 accept 指纹。

### iTerm2

- **旧 mac 一次性**：iTerm2 → Settings → General → Settings → 勾 "Load preferences from a custom folder or URL"，路径填 `<repo>/iterm2/`。iTerm2 把当前 plist 写到该目录。之后改设置会自动同步回这个文件，commit 即可。
- **新 mac**（bootstrap 自动）：

  ```sh
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$REPO_ROOT/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  ```

  下次开 iTerm2 就是仓库里的设置。
- **字体**：固化在 plist 里（Maple Mono NF）。前提是 brew bundle 已经把字体装上。

### tmux / neovim / vim

- **旧 mac**：把 `~/.tmux.conf` 拷到 `tmux/.tmux.conf`；`~/.config/nvim/` 整目录拷到 `nvim/.config/nvim/`；vim 同理（按实际有的来）。
- **新 mac**：`stow tmux nvim vim`（按实际存在的包跑）。
- nvim 插件管理器（lazy.nvim/packer 等）第一次启动 nvim 时自动拉插件，不需要额外步骤。

### Nerd Font

- 进 Brewfile：`cask "font-maple-mono-nf"`。`brew bundle` 时自动装到 `~/Library/Fonts/`。
- p10k 不指定字体家族，字体由终端（iTerm2）的 plist 决定。

### ClickHouse 相关

- 删 `script/clickhouse_functions.zsh`。
- 从 `zsh-macos/.zshrc` 剥离相关三行（见上）。
- Ubuntu 侧 `ubuntu/zsh/zshrc` 也 source 了 `clickhouse_functions.zsh`，本次不修，留 TODO 给 Ubuntu 改造。

---

## 6. README.md 内容大纲

README 必须包含以下章节（用户明确要求装机使用说明写进 README）：

1. **What this is**：仓库用途一句话。
2. **新 macOS 装机流程**：
   - 前置步骤（Xcode CLT、clone）
   - `./bootstrap-macos.sh`
   - bootstrap 跑完后的手动收尾清单
3. **stow 包列表**：每个包 → 对应的 `$HOME` 路径表格。
4. **日常维护**：
   - 装新软件后怎么更新 Brewfile
   - 改 iTerm2 设置后会自动同步到仓库，记得 commit
   - 加新 SSH key：`scripts/encrypt-ssh.sh`
   - 改 zshrc/p10k：直接编辑仓库里的文件（已经是软链了）
5. **SSH 私钥加解密**：
   - 旧机加密：`scripts/encrypt-ssh.sh`
   - 新机解密：`scripts/decrypt-ssh.sh`（或 bootstrap 自动调用）
   - passphrase 丢失后果 + 强度建议
6. **冲突处理**：stow 报已有文件冲突时怎么办（手动看、删/改名、或用 `--adopt`）。
7. **故障排查**：常见问题（字体没渲染、p10k 报错、ssh permission denied 等）。

---

## 7. 验证清单（新 mac 跑完 bootstrap 后手动验证）

1. 新开 iTerm2：p10k 提示符出来、Nerd Font 图标渲染正确、字体是 Maple Mono NF。
2. `git config --global user.email` 返回正确邮箱。
3. `ssh -T git@github.com` 能通（说明 SSH 私钥解密 + chmod 对）。
4. `j somedir` 能用（说明 `script` 包 stow 成功、`zshrc` source 到 `~/.config/script/git_functions.zsh`）。
5. `which jump`、`which sr-dev` 出 alias 定义；`jump` 能连（视网络）。
6. `ls -la ~/.zshrc ~/.p10k.zsh ~/.gitconfig ~/.ssh/config` 都是软链且指向仓库内文件。
7. `ls -la ~/.ssh/id_* ~/.ssh/*.pem` 是实文件、权限 600。

---

## 8. 实施顺序建议

落到 plan 里时按这个顺序：

1. 在旧 mac 上准备所有"源材料"（Brewfile dump、p10k.zsh、gitconfig、ssh config、tmux/nvim、iTerm2 prefs folder）。
2. 重组仓库目录到 §2 的新布局。
3. 写 `scripts/encrypt-ssh.sh` 和 `scripts/decrypt-ssh.sh`。
4. 在旧 mac 上跑 `encrypt-ssh.sh` 把 SSH 私钥加密入库。
5. 写 `bootstrap-macos.sh`。
6. 写 `Brewfile`、`.gitignore`、`README.md`。
7. 删除 `init.sh`、`link.sh`、`macos/`、`ubuntu/`、`script/clickhouse_functions.zsh`（确认重组完成、新结构跑通后再删）。
8. 在新 mac 上端到端跑一次 `bootstrap-macos.sh`，按 §7 验证。
