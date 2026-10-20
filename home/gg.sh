#!/usr/bin/env bash

set +e

echo "==> Updating keyrings and mirrors..."
sudo pacman -Sy --noconfirm archlinux-keyring cachyos-keyring cachyos-mirrorlist reflector || true

echo "==> Full system upgrade..."
sudo pacman -Syu --noconfirm || true

PKGS=(
base-devel
git
github-cli
curl
wget
aria2
rsync
ripgrep
fd
fzf
bat
eza
zoxide
btop
htop
fastfetch
jq
yq
tree
unzip
zip
p7zip
less
nano
vim
neovim
tmux
openssh
gnupg
stow

python
python-pip
python-pipx

nodejs
npm
pnpm

go

rust
rustup

jdk21-openjdk
maven
gradle

docker
docker-compose

podman
buildah

kubectl
helm
k9s

sqlite
postgresql-libs

cmake
ninja
meson
make
gcc
gdb
lldb
clang
lld

openssl

dnsutils
bind
nmap
traceroute
tcpdump
inetutils

firewalld

ffmpeg
imagemagick

vlc
mpv

obs-studio

gparted

flatpak

ntfs-3g
exfatprogs

xdg-utils
xdg-user-dirs

networkmanager

bluez
bluez-utils

udisks2

starship

zsh

ttf-jetbrains-mono-nerd
noto-fonts
noto-fonts-cjk
noto-fonts-emoji

wl-clipboard
cliphist

brightnessctl
playerctl

man-db
man-pages
texinfo
)

echo "==> Installing packages..."
for pkg in "${PKGS[@]}"; do
    sudo pacman -S --needed --noconfirm "$pkg" || true
done

if command -v paru >/dev/null 2>&1; then
    echo "==> Installing AUR packages..."
    paru -S --needed --noconfirm \
        visual-studio-code-bin \
        google-chrome \
        spotify \
        lazygit \
        lazydocker \
        bruno \
        postman-bin \
        insomnia \
        docker-buildx \
        docker-compose-switch \
        ttf-ms-fonts \
        localsend-bin \
        github-desktop-bin \
        || true
fi

echo "==> Enabling services..."
sudo systemctl enable --now docker.service || true
sudo systemctl enable --now bluetooth.service || true
sudo systemctl enable --now firewalld.service || true

echo "==> Adding current user to docker group..."
sudo usermod -aG docker "$USER" || true

echo "==> Updating Flatpak..."
flatpak update -y || true

echo "==> Updating rust toolchain..."
rustup default stable || true
rustup update || true

echo "==> Installing latest npm tools..."
npm install -g \
pnpm \
corepack \
typescript \
typescript-language-server \
eslint \
prettier \
npm-check-updates \
tsx \
nodemon \
turbo \
vercel \
netlify-cli \
serve \
@anthropic-ai/claude-code \
@google/gemini-cli \
@openai/codex \
|| true

corepack enable || true

echo "==> Cleaning caches..."
sudo pacman -Sc --noconfirm || true

echo
echo "================================================="
echo "Done."
echo "Reboot recommended if kernel/glibc/systemd updated."
echo "Log out and back in for docker group changes."
echo "================================================="
