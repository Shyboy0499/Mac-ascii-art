#!/bin/bash
# Swan Lake Mist: SketchyBar colours to match lake.html, sampled from the same
# photo. Colours are 0xAARRGGBB. The names follow the usual SketchyBar
# colors.sh, so this can stand in for one that uses them.
#
# The look: dark forest-green pills over the fog, fog-grey text, and the swan
# as the one bright thing: the focused workspace is a white pill.

# --- from the photo -----------------------------------------------------------
export BLACK=0xff050906        # the water at its darkest
export WHITE=0xffe8ebe7        # the swan
export GREY=0xff9da1a6         # fog
export GREEN=0xff56702f        # grass where the light catches it
export BLUE=0xff7a8682         # sheen on the water, the photo's nearest thing to blue
export ORANGE=0xffb8662e       # the swan's beak
# not in the photo, muted to sit with it, for plugins that want them
export RED=0xffa4553f
export YELLOW=0xffb9a66a
export MAGENTA=0xff8a7a8c
export TRANSPARENT=0x00000000

# --- the bar ------------------------------------------------------------------
export BAR_COLOR=0x00000000          # clear, so the fog shows; 0xb3050906 for a dark band
export BAR_BORDER_COLOR=0x00000000
export ICON_COLOR=0xffc9ccd0         # light fog
export LABEL_COLOR=0xffc9ccd0
export BACKGROUND_1=0xe61b241c       # item pills: the forest, nearly opaque
export BACKGROUND_2=0xe62a3529       # pills a step lighter, for groups/brackets
export BACKGROUND_BORDER=0xff33403a  # misted spruce
export POPUP_BACKGROUND_COLOR=0xf00b110c
export POPUP_BORDER_COLOR=0xff3f4b45
export SHADOW_COLOR=0xff050906

# --- workspaces ---------------------------------------------------------------
export ACCENT_COLOR=$WHITE           # the focused workspace's pill
export ACCENT_LABEL_COLOR=0xff0b110c # its text, dark on the white
export INACTIVE_COLOR=$BACKGROUND_1
