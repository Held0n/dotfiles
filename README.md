# dotfile

个人 macOS dotfiles，使用 [GNU stow](https://www.gnu.org/software/stow/) + Homebrew `brew bundle` + age 加密 SSH 私钥来管理。

## 仓库结构

| 包 | 符号链接到 | 用途 |
|---|---|---|
| `zsh-macos/` | `~/.zshrc` + `~/.config/zsh/*.zsh` | zsh 入口 + 5 个按序加载的片段（env、zinit、prompt、functions、extras） |
| `p10k-macos/` | `~/.p10k.zsh` | powerlevel10k 配置 |
| `git/` | `~/.gitconfig` | git 全局配置 |
| `ssh-config/` | `~/.ssh/my-ssh.config` | 纳入版本管理的干净 SSH 配置。`~/.ssh/config` 本身是 bootstrap 写入的本地 stub，仅 `Include` 这个文件 —— 见下文「stow 与自写工具」 |
| `tmux/` | `~/.tmux.conf` | tmux 配置 |
| `nvim/` | `~/.config/nvim/` | neovim 配置 |
| `zsh-ubuntu/`、`p10k-ubuntu/` | （仅 Ubuntu） | 留待 Ubuntu 配置整理成 macOS 同款布局后再使用 |
| `iterm2/` | （不 stow） | iTerm2 直接从该目录读取 plist |
| `secrets/ssh/` | （不 stow） | age 加密的 SSH 私钥；`decrypt-ssh.sh` 解密后写入 `~/.ssh/` |

## 新机器安装

```sh
# 0. 手动前置
xcode-select --install
git clone <repo-url> <你想放置仓库的路径>
cd <该路径>

# 1. 一行命令
./bootstrap-macos.sh
```

`bootstrap-macos.sh` 依次执行：

1. 如缺失则安装 Homebrew。
2. `brew bundle --file=Brewfile`（formulas、casks、字体、mas）。
3. `stow` 常驻包（`zsh-macos p10k-macos git ssh-config`），以及 `tmux nvim vim` 中目录非空的包。
4. 设置 iTerm2 `PrefsCustomFolder` 指向 `<repo>/iterm2`。
5. 运行 `scripts/decrypt-ssh.sh`（会要求输入 age 口令）。

如果目标位置已存在非符号链接的同名文件，`stow` 会拒绝覆盖；遇到冲突请先删除或重命名 `$HOME` 中的旧文件，然后重新运行。

### 安装后

- `chsh -s /opt/homebrew/bin/zsh`（把 Homebrew 安装的 zsh 设为登录 shell）。
- 打开 iTerm2 一次，让它从仓库加载偏好设置（字体应为 **Maple Mono NF**）。
- `ssh -T git@github.com` 验证 GitHub key 可用。
- 如需 REDpass，自行安装；它会把自己的配置块写入 `~/.ssh/config`。

## 日常维护

| 变更 | 操作 |
|---|---|
| 装了新的 brew/cask | `brew bundle dump --file=Brewfile --force --describe`，review 后 commit |
| 修改了 iTerm2 设置 | 已自动写入 `iterm2/com.googlecode.iterm2.plist`；`git status` 确认后 commit |
| 修改 zsh 配置 | 直接编辑仓库里的文件（已是符号链接源）；`exec zsh` 重新加载 |
| 本机新增 SSH key | `./scripts/encrypt-ssh.sh ~/.ssh/<newkey>`，然后 commit `secrets/ssh/<newkey>.age` |

## SSH 私钥加密

私钥使用 [age](https://age-encryption.org/) 的口令模式加密。口令是**记在脑子里**的，不存任何地方 —— 忘了就意味着丢失 `secrets/ssh/` 里所有 key。

```sh
# 加密一个或多个 key（交互式调用或显式传路径）
./scripts/encrypt-ssh.sh ~/.ssh/id_rsa ~/.ssh/id_rsa.pub

# 把所有 secrets/ssh/*.age 解密回 ~/.ssh/，chmod 600（bootstrap 自动调用）
./scripts/decrypt-ssh.sh
```

`decrypt-ssh.sh` 是**非覆盖**的：如果 `~/.ssh/` 中已存在同名文件，会保留原文件。要替换 key 请先在 `~/.ssh/` 中删掉它。

推荐口令：6 个以上 diceware 单词（或约 80 bit 熵）。age 使用 scrypt，弱口令在仓库泄露时可被离线暴力破解。

## stow 与自写工具

`~/.ssh/config` **不是**符号链接。Bootstrap 把它写成一个本地 stub，唯一内容是：

```
Include ~/.ssh/my-ssh.config
```

被纳入版本管理的干净配置位于 `ssh-config/.ssh/my-ssh.config`，通过符号链接出现在 `~/.ssh/my-ssh.config`。诸如 **REDpass**、**OrbStack**、**Coral** 开发沙箱工具链会自动往 `~/.ssh/config` 追加配置块 —— 这些写入只落到本地 stub 里，**不会**进入仓库，因此机器专属的 UUID 和短暂的 Pod IP 永远不会进入版本控制。按 OpenSSH 规则，先匹配到的配置项生效，所以（先读到的）`Include` 优先级高于后面追加的内容。

`.gitignore` 同时拦截了 `ssh-config/.ssh/config`，作为纵深防御：如果将来某次配置错误重新在仓库里创建了这个路径，git 会拒绝把它加入暂存区。

## 排障

- **Nerd Font 图标显示异常**：iTerm2 → Profiles → Text → 确认字体为 **Maple Mono NF**。如果选不到，`brew install --cask font-maple-mono-nf` 后重启 iTerm2。
- **p10k 抱怨字体**：同上。
- **`stow` 在 `.zshrc` 上报冲突**：通常是 oh-my-zsh 或系统默认安装留下的 `~/.zshrc`。`mv ~/.zshrc ~/.zshrc.preexisting && ./bootstrap-macos.sh` 再跑一次。
- **`ssh -T git@github.com` → permission denied**：`ls -la ~/.ssh/id_rsa_myself` 检查 key 是否存在、权限是否为 600。缺失则 `./scripts/decrypt-ssh.sh`。

## Ubuntu 上用 stow 管理 dotfile

```bash
apt install stow
```

```bash
mv ~/.bashrc ~/.bashrc_bak
stow bash -t ~
```
