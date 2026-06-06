#!/usr/bin/env bash
#
# hypr-rice-setup.sh
# Автоматическая настройка окружения Hyprland в стиле скриншота:
#   - верхний бар        -> waybar
#   - нижний док         -> nwg-dock-hyprland
#   - плавающий виджет   -> eww (большие часы + дата + Now Playing через playerctl)
#
# ЗАПУСК: от ОБЫЧНОГО пользователя (НЕ root), на свежеустановленном Arch Linux,
# NVIDIA-драйверы уже стоят (ставятся на этапе установки системы).
#
#   chmod +x hypr-rice-setup.sh
#   ./hypr-rice-setup.sh
#
set -euo pipefail

# ----------------------------- вывод -----------------------------
c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_inf=$'\e[36m'; c_rst=$'\e[0m'
log()  { printf '%s==>%s %s\n' "$c_inf"  "$c_rst" "$*"; }
ok()   { printf '%s OK %s %s\n' "$c_ok"   "$c_rst" "$*"; }
warn() { printf '%s !! %s %s\n' "$c_warn" "$c_rst" "$*" >&2; }
die()  { printf '%sERR %s %s\n' "$c_err"  "$c_rst" "$*" >&2; exit 1; }

# ----------------------------- проверки -----------------------------
[ "$(id -u)" -ne 0 ]            || die "Не запускай от root. Нужен обычный пользователь с sudo."
command -v pacman >/dev/null    || die "Это не Arch Linux (нет pacman)."
command -v sudo   >/dev/null    || die "Нет sudo."
ping -c1 -W3 archlinux.org >/dev/null 2>&1 || warn "Похоже, нет сети — установка пакетов может упасть."

CFG="$HOME/.config"
mkdir -p "$CFG"

backup() {  # сохранить старый конфиг перед перезаписью
  [ -e "$1" ] && { mv "$1" "$1.bak.$(date +%s)"; warn "Старый $1 сохранён рядом как .bak.*"; }
  return 0
}

# ----------------------------- 1. официальные пакеты -----------------------------
log "Обновляю систему и ставлю пакеты из официальных репозиториев"
sudo pacman -Syu --needed --noconfirm \
  hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  hyprpolkitagent hyprpaper hyprlock hypridle \
  waybar kitty rofi-wayland mako wl-clipboard grim slurp jq \
  playerctl pavucontrol pamixer brightnessctl \
  pipewire wireplumber pipewire-pulse pipewire-alsa \
  networkmanager network-manager-applet bluez bluez-utils blueman \
  thunar polkit qt5-wayland qt6-wayland \
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk \
  papirus-icon-theme nwg-look imagemagick

# ----------------------------- 2. AUR (yay + док/виджеты) -----------------------------
if ! command -v yay >/dev/null; then
  log "Ставлю AUR-хелпер yay"
  tmp="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay.git "$tmp/yay"
  ( cd "$tmp/yay" && makepkg -si --noconfirm )
  rm -rf "$tmp"
fi

log "Ставлю пакеты из AUR (eww + nwg-dock-hyprland)"
yay -S --needed --noconfirm eww nwg-dock-hyprland \
  || warn "AUR встал не полностью. Hyprland и бар будут работать; eww/nwg-dock проверь вручную."

# ----------------------------- 3. службы -----------------------------
log "Включаю звук (pipewire) и bluetooth"
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true

# ----------------------------- 4. каталоги конфигов -----------------------------
mkdir -p "$CFG/hypr" "$CFG/waybar" "$CFG/eww" "$CFG/mako" "$CFG/kitty"

# ----------------------------- 5. hyprland.conf -----------------------------
log "Пишу конфиги"
backup "$CFG/hypr/hyprland.conf"
cat > "$CFG/hypr/hyprland.conf" <<'HYPRCONF'
########################  MONITORS  ########################
# preferred = родное разрешение; auto = позиция; 1 = масштаб.
# Работает на любом мониторе любого ПК — важно для переносимого диска.
monitor = ,preferred,auto,1

########################  NVIDIA + WAYLAND ENV  ########################
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
# Если будут артефакты/мерцание на старых драйверах — раскомментируй:
# env = GBM_BACKEND,nvidia-drm
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = MOZ_ENABLE_WAYLAND,1
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

cursor {
    # Программный курсор — самый надёжный вариант на NVIDIA.
    no_hardware_cursors = true
}

########################  AUTOSTART  ########################
exec-once = hyprpaper
exec-once = waybar
exec-once = mako
exec-once = eww open clock
exec-once = nwg-dock-hyprland -i 44 -mb 10
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = systemctl --user start hyprpolkitagent
exec-once = hypridle

########################  INPUT  ########################
input {
    kb_layout = us,ru
    kb_options = grp:alt_shift_toggle
    follow_mouse = 1
    sensitivity = 0
}

########################  LOOK & FEEL  ########################
general {
    gaps_in = 6
    gaps_out = 14
    border_size = 2
    col.active_border = rgba(e0567aff) rgba(8a2c44ff) 45deg
    col.inactive_border = rgba(2a2024aa)
    layout = dwindle
}

decoration {
    rounding = 12
    blur {
        enabled = true
        size = 6
        passes = 3
        new_optimizations = true
    }
    shadow {
        enabled = true
        range = 18
        render_power = 3
        color = rgba(00000066)
    }
    active_opacity = 1.0
    inactive_opacity = 0.94
}

animations {
    enabled = true
    bezier = ease, 0.25, 0.1, 0.25, 1.0
    animation = windows, 1, 5, ease, popin 80%
    animation = fade, 1, 6, ease
    animation = workspaces, 1, 5, ease, slide
}

dwindle {
    pseudotile = true
    preserve_split = true
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
}

########################  KEYBINDS  ########################
$mainMod = SUPER
bind = $mainMod, Q, exec, kitty
bind = $mainMod, R, exec, rofi -show drun
bind = $mainMod, E, exec, thunar
bind = $mainMod, C, killactive,
bind = $mainMod, V, togglefloating,
bind = $mainMod, F, fullscreen,
bind = $mainMod, J, togglesplit,
bind = $mainMod SHIFT, M, exit,

# фокус по стрелкам
bind = $mainMod, left,  movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up,    movefocus, u
bind = $mainMod, down,  movefocus, d

# рабочие столы 1..0
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# скриншот выделенной области в буфер
bind = , Print, exec, grim -g "$(slurp)" - | wl-copy

# медиа / громкость / яркость
bindl  = , XF86AudioPlay,        exec, playerctl play-pause
bindl  = , XF86AudioNext,        exec, playerctl next
bindl  = , XF86AudioPrev,        exec, playerctl previous
bindle = , XF86AudioRaiseVolume, exec, pamixer -i 5
bindle = , XF86AudioLowerVolume, exec, pamixer -d 5
bindl  = , XF86AudioMute,        exec, pamixer -t
bindle = , XF86MonBrightnessUp,  exec, brightnessctl set 5%+
bindle = , XF86MonBrightnessDown,exec, brightnessctl set 5%-

# окна мышью
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

########################  WINDOW RULES  ########################
windowrulev2 = float, class:(pavucontrol)
windowrulev2 = float, class:(blueman-manager)
windowrulev2 = float, title:(Picture-in-Picture)
HYPRCONF

# ----------------------------- 6. waybar -----------------------------
backup "$CFG/waybar/config"
cat > "$CFG/waybar/config" <<'WBCONF'
{
  "layer": "top",
  "position": "top",
  "height": 34,
  "margin-top": 8,
  "margin-left": 12,
  "margin-right": 12,
  "spacing": 6,
  "modules-left": ["custom/arch", "hyprland/workspaces"],
  "modules-center": ["hyprland/window"],
  "modules-right": ["tray", "pulseaudio", "network", "bluetooth", "battery", "clock"],

  "custom/arch": {
    "format": "  Main",
    "tooltip": false,
    "on-click": "rofi -show drun"
  },
  "hyprland/workspaces": {
    "format": "{icon}",
    "on-click": "activate",
    "format-icons": { "default": "", "active": "" }
  },
  "hyprland/window": { "max-length": 60, "separate-outputs": true },
  "tray": { "spacing": 10 },
  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": " muted",
    "format-icons": { "default": ["", "", ""] },
    "on-click": "pavucontrol"
  },
  "network": {
    "format-wifi": "  {essid}",
    "format-ethernet": "  wired",
    "format-disconnected": "  off",
    "tooltip-format": "{ifname} {ipaddr}"
  },
  "bluetooth": { "format": " {status}", "on-click": "blueman-manager" },
  "battery": {
    "states": { "warning": 30, "critical": 15 },
    "format": "{icon} {capacity}%",
    "format-icons": ["", "", "", "", ""]
  },
  "clock": {
    "format": "{:%H:%M}",
    "format-alt": "{:%a %d %b}",
    "tooltip-format": "<tt>{calendar}</tt>"
  }
}
WBCONF

backup "$CFG/waybar/style.css"
cat > "$CFG/waybar/style.css" <<'WBCSS'
* {
  font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
  font-size: 13px;
  border: none;
  border-radius: 0;
  min-height: 0;
}
window#waybar { background: transparent; }

.modules-left, .modules-center, .modules-right {
  background: rgba(20, 14, 17, 0.78);
  border-radius: 14px;
  padding: 0 6px;
}
#custom-arch { color: #e0567a; font-weight: bold; padding: 0 12px; }
#workspaces button { color: #8a7a80; padding: 0 8px; }
#workspaces button.active { color: #ffffff; }
#window { color: #cfc2c6; }
#clock, #pulseaudio, #network, #bluetooth, #battery, #tray {
  color: #e7dde0;
  padding: 0 10px;
}
#battery.warning  { color: #e0a356; }
#battery.critical { color: #e0567a; }
WBCSS

# ----------------------------- 7. eww (часы + Now Playing) -----------------------------
backup "$CFG/eww/eww.yuck"
cat > "$CFG/eww/eww.yuck" <<'EWWYUCK'
(defpoll g_hour   :interval "1s"  "date +%H")
(defpoll g_min    :interval "1s"  "date +%M")
(defpoll g_date   :interval "30s" "date '+%A %d %b' | tr '[:lower:]' '[:upper:]'")
(defpoll g_title  :interval "1s"  "playerctl metadata title 2>/dev/null || echo ''")
(defpoll g_artist :interval "1s"  "playerctl metadata artist 2>/dev/null || echo ''")

(defwidget clockface []
  (box :class "root" :orientation "v" :space-evenly false :halign "start" :valign "start"
    (box :class "timebox" :space-evenly false :halign "start"
      (label :class "tdigit" :text g_hour)
      (label :class "tsep"   :text " ")
      (label :class "tdigit" :text g_min))
    (label :class "date" :halign "start" :text g_date)
    (box :class "np" :orientation "h" :space-evenly false :halign "start"
         :visible {g_title != ""}
      (label :class "nplabel" :text "NOW\nPLAYING")
      (box :orientation "v" :space-evenly false :halign "start"
        (label :class "nptitle"  :halign "start" :limit-width 28 :text g_title)
        (label :class "npartist" :halign "start" :limit-width 28 :text g_artist)))))

(defwindow clock
  :monitor 0
  :geometry (geometry :x "28px" :y "26px" :width "380px" :height "240px" :anchor "top left")
  :stacking "bg"
  :focusable false
  :exclusive false
  (clockface))
EWWYUCK

backup "$CFG/eww/eww.scss"
cat > "$CFG/eww/eww.scss" <<'EWWSCSS'
* {
  all: unset;
  font-family: "JetBrainsMono Nerd Font", monospace;
}
.root { padding: 6px; }
.timebox {
  border: 2px solid rgba(255, 255, 255, 0.85);
  border-radius: 10px;
  padding: 4px 16px;
}
.tdigit { font-size: 58px; font-weight: 700; color: #ffffff; }
.tsep   { font-size: 58px; color: #ffffff; }
.date {
  font-size: 15px;
  letter-spacing: 3px;
  color: #e7dde0;
  margin-top: 8px;
  margin-left: 4px;
}
.np { margin-top: 14px; }
.nplabel {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 1px;
  color: #b0a4a8;
  margin-right: 12px;
}
.nptitle  { font-size: 15px; font-weight: 700; color: #ffffff; }
.npartist { font-size: 13px; color: #cbbfc3; }
EWWSCSS

# ----------------------------- 8. mako -----------------------------
backup "$CFG/mako/config"
cat > "$CFG/mako/config" <<'MAKOCONF'
font=JetBrainsMono Nerd Font 11
background-color=#140e11ee
text-color=#e7dde0
border-color=#e0567a
border-size=2
border-radius=10
padding=12
default-timeout=5000
MAKOCONF

# ----------------------------- 9. kitty -----------------------------
backup "$CFG/kitty/kitty.conf"
cat > "$CFG/kitty/kitty.conf" <<'KITTYCONF'
font_family      JetBrainsMono Nerd Font
font_size        12
background_opacity 0.92
background       #100a0d
foreground       #e7dde0
cursor           #e0567a
window_padding_width 10
confirm_os_window_close 0
KITTYCONF

# ----------------------------- 10. hyprpaper + фон -----------------------------
backup "$CFG/hypr/hyprpaper.conf"
cat > "$CFG/hypr/hyprpaper.conf" <<EOF
preload = $HOME/.config/hypr/wallpaper.jpg
wallpaper = ,$HOME/.config/hypr/wallpaper.jpg
splash = false
EOF

if [ ! -f "$CFG/hypr/wallpaper.jpg" ]; then
  if command -v magick >/dev/null; then
    magick -size 2560x1440 gradient:'#2a141c'-'#080507' "$CFG/hypr/wallpaper.jpg"
    ok "Создан временный тёмный фон. Замени его своей картинкой: $CFG/hypr/wallpaper.jpg"
  else
    warn "Положи обои в $CFG/hypr/wallpaper.jpg — без файла hyprpaper не запустится."
  fi
fi

# ----------------------------- 11. автозапуск Hyprland с TTY1 -----------------------------
if ! grep -q "exec Hyprland" "$HOME/.bash_profile" 2>/dev/null; then
  cat >> "$HOME/.bash_profile" <<'PROF'

# Auto-start Hyprland on the first virtual terminal after login
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-}" = "1" ]; then
  exec Hyprland
fi
PROF
  ok "Добавил автозапуск Hyprland в ~/.bash_profile (логинишься в TTY1 — стартует графика)."
fi

# ----------------------------- готово -----------------------------
echo
ok "Готово."
cat <<'DONE'

Дальше:
  1) Замени обои:  ~/.config/hypr/wallpaper.jpg  (своя картинка с любого источника).
  2) Перезайди:    выйди из сессии и снова залогинься в TTY1  (или просто: reboot).
  3) Горячие клавиши:
       Super+Q  терминал (kitty)
       Super+R  меню приложений (rofi)
       Super+E  файловый менеджер (thunar)
       Super+C  закрыть окно,  Super+F  на весь экран,  Super+V  плавающее
       Alt+Shift переключить раскладку (us/ru)
  4) Док: иконки закрепляются ПКМ по запущенному приложению (nwg-dock).
  5) "Now Playing" в виджете появится, когда заиграет плеер с MPRIS
     (Spotify, mpv, браузер). Проверка:  playerctl metadata

Тонкая настройка:
  - док:   nwg-dock-hyprland -h   (размер, позиция, авто-скрытие)
  - бар:   ~/.config/waybar/{config,style.css}
  - часы:  ~/.config/eww/{eww.yuck,eww.scss}
DONE
