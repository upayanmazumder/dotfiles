# ~/.config/fish/functions/y.fish
# Yazi wrapper: cd to the last directory on exit.
# `yy` also changes directory; plain `yazi` stays in the current dir.
function y
    set tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi --cwd-file="$tmp" $argv
    if test -s "$tmp"; and set cwd (cat -- "$tmp")
        test -d "$cwd"; and cd "$cwd"
    end
    rm -f -- "$tmp"
end
