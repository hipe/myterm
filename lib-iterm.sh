#!/usr/bin/env bash

## NOTE for `iterm` users -- this file is not used: it is here for reference.
## (it lives in a different git repository)

# adapted from http://kpumuk.info/mac-os-x/how-to-show-ssh-host-name-on-the-iterms-background/

HEIGHT_TALL=750
WIDTH_NARROW=600
WIDTH_SCROLLBAR=15
HEIGHT_TITLEBAR_TABS=44

# arr=($(iterm_bounds_get))
function iterm_bounds_get {
  local size=( $(
    osascript -e "
      tell application \"iTerm\"
        get the bounds of the first window
      end tell" | tr ',' ' '
  ) )
  echo "${size[@]}"
}

function iterm_bounds_set {
  if [[ ! "$1,$2,$3,$4" =~ "^[0-9]+,[0-9]+,[0-9]+,[0-9]+$" ]] ; then
    echo "bad args to item_bounds_set: ($1, $2, $3, $4)"
    return
  fi
  local exec_me="
    tell application \"iTerm\"
      set the bounds of the first window to {$1, $2, $3, $4}
    end tell
  "
  osascript -e "$exec_me"
}

function iterm_dimensions_get {
  local size=($(iterm_bounds_get))
  local x1=${size[0]} y1=${size[1]} x2=${size[2]} y2=${size[3]}
  local w=$(( $x2 - $x1 - $WIDTH_SCROLLBAR))
  local h=$(( $y2 - $y1 - $HEIGHT_TITLEBAR_TABS))
  echo "${w}x${h}"
}

function iterm_dimensions_set {
  local w=$1 h=$2
  local b=($(iterm_bounds_get))
  local x=${b[0]} y=${b[1]}
  iterm_bounds_set $x $y $w $h
}

# check to see if we have the correct terminal for doing this kind of thing
# this won't work when we sudo something because TERM_PROGRAM isn't picked up
function iterm_ok {
  if [ "$(tty)" == 'not a tty' ] || [ "$TERM_PROGRAM" != "iTerm.app" ] ; then
    echo ''
  else
    echo 'ok'
  fi
}

function iterm_set {
  local prop=$1
  local val=$2
  local tty=$(tty)
  osascript -e "
    tell application \"iTerm\"
      repeat with theTerminal in terminals
        tell theTerminal
          try
            tell session id \"$tty\"
              set bounds of window 1 to \"$val\"
            end tell
            on error errmesg number errn
          end try
        end tell
      end repeat
    end tell
  "
}

function iterm_bg_image_make {
  local text1=$1
  local text2=$2
  local color_bg=${3:-#000000}
  local color_fg=${4:-#662020}
  local dimensions=$(iterm_dimensions_get)
  local font_ttf=${5:-$HOME/.bash/resources/SimpleLife.ttf}
  local font_points=${6:-60}
  local font_style=${7:-Normal} # Font style (Any, Italic, Normal, Oblique)
  local gravity=${8:-NorthEast}
      # Text gravity (NorthWest, North, NorthEast,
      # West, Center, East, SouthWest, South, SouthEast)
  local offset1=${8:-20,10}
  local offset2=${9:-20,80}
  local outpath="/tmp/iTermBG.$$.png"
  convert \
    -size "$dimensions" xc:"$color_bg" -gravity "$gravity" -fill "$color_fg" \
    -font "$font_ttf" -style "$font_style" -pointsize "$font_points" \
    -antialias -draw "text $offset1 '$text1'" \
    -pointsize 30 -draw "text $offset2 '$text2'" \
    "$outpath"
  echo $outpath
}

function iterm_bg_image_delete {
  local path=${1:-/tmp/itermBG.$$.png}
  rm $path
}

function iterm_bg_image_empty {
  local opath="/tmp/iTermBG.empty.png"
  if [ ! -f /tmp/iTermBG.empty.png ]; then
    local dims=$(iterm_dimensions_get)
    convert -size "$dims" xc:"#000000" "$opath"
  fi
  echo $opath
}

function iterm_bg_image_set {
  local tty=$(tty)
  osascript -e "
    tell application \"iTerm\"
      repeat with theTerminal in terminals
        tell theTerminal
          try
            tell session id \"$tty\"
              set background image path to \"$1\"
            end tell
            on error errmesg number errn
          end try
        end tell
      end repeat
    end tell
  "
}

function iterm_bg_color_set {
  local tty=$(tty)
  osascript -e "
    tell application \"iTerm\"
      repeat with theTerminal in terminals
        tell theTerminal
          try
            tell session id \"$tty\"
              set background image path to \"\"
              set background color to \"$1\"
            end tell
            on error errmesg number errn
          end try
        end tell
      end repeat
    end tell
  "
}

function iterm_window_title_set {
  osascript -e "
    tell application \"iTerm\"
      set the name of the first window to \"$1\"
    end tell
  "
}
