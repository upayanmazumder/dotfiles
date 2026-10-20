hl.on("hyprland.start", function ()
    -- Steam (and other XWayland apps) read HiDPI scale from the Xorg
    -- Xft.dpi resource, not the compositor's fractional scale. Monitor
    -- scale here is 1.50, so Xft.dpi = 96 * 1.5 = 144.
    hl.exec_cmd("echo 'Xft.dpi: 144' | xrdb -merge")

    -- Apps
    hl.exec_cmd("discord --start-minimized")
    hl.exec_cmd("spotify")
end)
