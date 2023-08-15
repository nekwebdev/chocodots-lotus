#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

source "$XDG_CONFIG_HOME"/shell/aliasrc

PS1='[\u@\h \W]\$ '
