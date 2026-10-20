# Commands to run in interactive sessions can go here
if status is-interactive
    # No greeting
    set fish_greeting

    # Fastfetch on new shells (once per session — uses a sentinel)
    if test "$TERM" != "linux" -a "$TERM" != "dumb"
        if not set -q __fish_fastfetch_shown
            set -g __fish_fastfetch_shown 1
            fastfetch 2>/dev/null
        end
    end

    # Colors (illogical-impulse / quickshell generates this file at runtime;
    # guard its absence so a fresh machine without quickshell running yet
    # still gets a usable shell)
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias pamcan pacman
    alias q 'qs -c ii'
    if test "$TERM" != "linux"
        alias ls 'eza --icons=auto'
    end
    if test "$TERM" = "xterm-kitty"
        alias ssh 'kitten ssh'
    end

    # Abbreviations — expand on Space/Enter for fast workflows
    # Git
    abbr --add g    git
    abbr --add gst  'git status'
    abbr --add gco  'git checkout'
    abbr --add gcb  'git checkout -b'
    abbr --add ga   'git add'
    abbr --add gc   'git commit'
    abbr --add gca  'git commit --amend'
    abbr --add gd   'git diff'
    abbr --add gds  'git diff --staged'
    abbr --add gl   'git log --oneline -20'
    abbr --add gp   'git push'
    abbr --add gpl  'git pull'
    abbr --add gr   'git rebase'
    # Docker
    abbr --add d    docker
    abbr --add dc   'docker compose'
    abbr --add dps  'docker ps'
    # Kubernetes
    abbr --add k    kubectl
    abbr --add kgp  'kubectl get pods'
    abbr --add kgs  'kubectl get services'
    abbr --add kctx 'kubectx'
    abbr --add kns  'kubens'
    # Package / tools
    abbr --add p    pnpm
    abbr --add px   'pnpm exec'
    abbr --add pdx  'pnpm dlx'
    abbr --add tf   terraform
    abbr --add y    yazi
    abbr --add lg   lazygit
    abbr --add z    zoxide
end

# Prompt: Oh My Posh is the single canonical prompt across every machine.
oh-my-posh init fish --config ~/.config/oh-my-posh/themes/night-owl.omp.json | source

# Shell integrations
zoxide init fish | source
# fzf: adds ctrl-t (file widget), alt-c (cd widget), shift-tab (fuzzy completion).
# Sourced before atuin so atuin's ctrl-r history binding (already in use) wins
# over fzf's own ctrl-r history widget -- no behavior change to history search.
fzf --fish | source
atuin init fish | source
direnv hook fish | source

# PATH
fish_add_path ~/.local/bin
fish_add_path ~/Scripts/bin

# opencode
fish_add_path /home/upayan/.opencode/bin

# npm global (user-prefix, e.g. paseo CLI)
fish_add_path ~/.npm-global/bin
