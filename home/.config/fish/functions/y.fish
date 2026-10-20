# Yazi wrapper: change to its last directory on exit.
function y
    set tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi --cwd-file="$tmp" $argv
    if test -s "$tmp"; and set cwd (cat -- "$tmp")
        test -d "$cwd"; and cd "$cwd"
    end
    rm -f -- "$tmp"
end
