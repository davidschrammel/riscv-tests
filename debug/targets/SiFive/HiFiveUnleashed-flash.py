import targets

class E51(targets.Hart):
    xlen = 64
    ram = 0x80000000
    ram_size = 1024 * 1024
    instruction_hardware_breakpoint_count = 2
    link_script_path = "HiFiveUnleashed-flash.lds"
    reset_vectors = [0x1004]

class U54(targets.Hart):
    xlen = 64
    ram = 0x80000000
    ram_size = 1024 * 1024
    instruction_hardware_breakpoint_count = 2
    link_script_path = "HiFiveUnleashed-flash.lds"
    reset_vectors = [0x1004]

class HiFiveUnleashedFlash(targets.Target):
    support_hasel = False
    harts = [E51(), U54(), U54(), U54(), U54()]
    openocd_config_path = "HiFiveUnleashed.cfg"
