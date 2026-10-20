#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
[ -r /home/upayan/.config/byobu/prompt ] && . /home/upayan/.config/byobu/prompt   #byobu-prompt#

# Added by DevRelay installer
export PATH="$HOME/.devrelay/bin:$PATH"
export PATH=$HOME/.local/go/bin:$PATH
export PATH=$PATH:$HOME/.local/go/bin:$HOME/go/bin

# Ollama on Raspberry Pi (syn)
export OLLAMA_HOST="http://syn:11434"
