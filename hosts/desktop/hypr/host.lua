-- host.lua (desktop): RTX 3060 on the proprietary NVIDIA driver
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.config({ cursor = { no_hardware_cursors = true } })
