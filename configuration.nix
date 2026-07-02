# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, lib, ... }:

{
  # ──────────────────────────────────────────────────────────────────────
  #  IMPORTS
  # ──────────────────────────────────────────────────────────────────────
  # imports: List of modules to include.
  # Default: []
  # Current: Includes the auto-generated hardware configuration.
  imports = [ ./hardware-configuration.nix ];

  # ──────────────────────────────────────────────────────────────────────
  #  BOOT & KERNEL
  # ──────────────────────────────────────────────────────────────────────
  # boot.loader.systemd-boot.enable: Enables the systemd-boot EFI bootloader.
  # Default: false. Current: true (Uses systemd-boot).
  boot.loader.systemd-boot.enable = true;

  # boot.loader.systemd-boot.configurationLimit: Maximum number of boot entries.
  # Default: 0 (unlimited). Current: 10 (Keeps boot menu clean).
  boot.loader.systemd-boot.configurationLimit = 10;

  # boot.loader.systemd-boot.editor: Allow editing kernel params at boot.
  # Default: true. Current: false (SECURITY: Prevents tampering).
  boot.loader.systemd-boot.editor = false;

  # boot.loader.efi.canTouchEfiVariables: Allows installation process to modify EFI boot variables.
  # Default: false. Current: true (Required for UEFI booting).
  boot.loader.efi.canTouchEfiVariables = true;

  # boot.kernelPackages: The kernel package to use.
  # Default: pkgs.linuxPackages. Current: pkgs.linuxPackages_latest (Uses the absolute latest kernel).
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # boot.consoleLogLevel: Kernel console logging level.
  # Default: 4. Current: 0 (Reduces boot noise).
  # boot.consoleLogLevel = 0;

  # boot.initrd.verbose: Whether to show initrd boot messages.
  # Default: true. Current: false (Quiet boot).
  # boot.initrd.verbose = false;

  # boot.blacklistedKernelModules: Modules to never load.
  # Default: []. Current: Blacklists all NVIDIA drivers.
  boot.blacklistedKernelModules = [ "nouveau" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" "iTCO_wdt" "intel_oc_wdt" ];

  # boot.extraModprobeConfig: Additional configuration for modprobe.
  # Default: "". Current: Ensures nouveau is fully blacklisted and modeset is 0.
  boot.extraModprobeConfig = ''
    blacklist nouveau
    options nouveau modeset=0
  '';

  # boot.extraModulePackages: Additional kernel modules to install.
  # Default: []. Current: Installs acpi_call for battery tracking.
  boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];

  # boot.kernelModules: Kernel modules to load at boot.
  # Default: []. Current: Loads acpi_call.
  boot.kernelModules = [ "acpi_call" ];

  # boot.kernelParams: Parameters passed to the kernel at boot.
  # Default: []. Current: Contains various power saving, audio, and display tweaks.
  boot.kernelParams = [
    # The following options are commented out to allow TLP to manage them dynamically:
    # "usbcore.autosuspend=-1"              # Managed by TLP USB_AUTOSUSPEND
    # "snd_hda_intel.power_save=1800"          # Managed by TLP SOUND_POWER_SAVE_TIMEOUT_ON_AC/BAT
    # "snd_hda_intel.power_save_controller=Y" # Managed by TLP SOUND_POWER_SAVE_CONTROLLER
    # "iwlwifi.power_save=0"                # Managed by TLP WIFI_PWR_ON_AC/BAT

    "i915.enable_psr=0"                     # Default: 1. Current: 0 (Fixes display micro-stutters)
    "i915.enable_fbc=0"                     # Default: 1. Current: 0 (Fixes atomic update failure logs on Kaby Lake)
    "nowatchdog"                            # Default: not set. Current: Stops periodic CPU wakeups
    "i915.enable_guc=2"                     # Default: 0. Current: 2 (HuC firmware offloading)
    "pci=noaer"                             # Default: not set. Current: Suppress harmless PCIe correctable error log spam
  ];

  # boot.kernel.sysctl: Kernel sysctl parameters.
  # Default: {}. Current: Optimizations for zram, networking, and security.
  boot.kernel.sysctl = {
    # ZRAM Memory Management
    "vm.swappiness" = 180;             # Default: 60. Current: 180 (Aggressively swap to zram)
    "vm.watermark_boost_factor" = 0;   # Default: 15000. Current: 0 (Reduce background page reclaiming overhead)
    "vm.watermark_scale_factor" = 125; # Default: 10. Current: 125 (Tweak memory margins for smooth multitasking)

    # File watcher limits for monorepos
    "fs.inotify.max_user_watches" = 524288; # Default: 8192. Current: 524288
    "fs.inotify.max_user_instances" = 8192; # Default: 128. Current: 8192

    # Networking
    "net.core.somaxconn" = 32768;              # Default: 4096. Current: 32768 (Boost queue size for local TCP)
    "net.core.default_qdisc" = "fq";           # Default: pfifo_fast. Current: fq (Improve queue scheduling)
    "net.ipv4.tcp_congestion_control" = "bbr"; # Default: cubic. Current: bbr (Use BBR congestion control)

    # Kernel panic reboot
    "kernel.panic" = 10;          # Default: 0. Current: 10 (Reboot after 10s on panic)
    "kernel.panic_on_oops" = 0;   # Default: 0. Current: 0 (Do not panic/reboot immediately on oops)

    # Security Hardening
    "kernel.kptr_restrict" = 2;                  # Default: 0. Current: 2 (Hide kernel pointers)
    "kernel.dmesg_restrict" = 1;                 # Default: 0. Current: 1 (Restrict dmesg access)
    "net.core.bpf_jit_harden" = 2;               # Default: 0. Current: 2 (Harden BPF JIT)
    "vm.mmap_rnd_bits" = 32;                     # Default: 28. Current: 32 (ASLR randomization)
    "vm.mmap_rnd_compat_bits" = 16;              # Default: 8. Current: 16 (ASLR for 32-bit compat)
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;  # Default: 1. Current: 1 (Prevent Smurf attacks)
    "kernel.kexec_load_disabled" = 1;            # Default: 0. Current: 1 (Prevent runtime kernel replacement)
    "net.ipv4.conf.all.log_martians" = 1;        # Default: 0. Current: 1 (Log impossible packets)
    "net.ipv4.conf.default.log_martians" = 1;    # Default: 0. Current: 1 (Log impossible packets)
    "fs.protected_hardlinks" = 1;                # Default: 0. Current: 1 (Prevent hardlink attacks)
    "fs.protected_symlinks" = 1;                 # Default: 0. Current: 1 (Prevent symlink attacks)
    "fs.protected_fifos" = 2;                    # Default: 0. Current: 2 (Prevent TOCTOU attacks on FIFOs in /tmp)
    "fs.protected_regular" = 2;                  # Default: 0. Current: 2 (Prevent TOCTOU attacks on regular files in /tmp)

    # Core Dumps Hardening
    "kernel.core_pattern" = "/dev/null";         # Default: core. Current: /dev/null (Disables core dumps globally)
  };

  # ──────────────────────────────────────────────────────────────────────
  #  HARDWARE
  # ──────────────────────────────────────────────────────────────────────
  # hardware.cpu.intel.updateMicrocode: Updates Intel CPU microcode.
  # Default: false. Current: true (Essential security patches for CPU).
  hardware.cpu.intel.updateMicrocode = true;

  # hardware.graphics.enable: Enables OpenGL/Vulkan.
  # Default: false. Current: true (Required for GUI).
  hardware.graphics.enable = true;

  # hardware.graphics.enable32Bit: Enables 32-bit graphics support.
  # Default: false. Current: true (Needed for Wine/Steam).
  hardware.graphics.enable32Bit = true;

  # hardware.graphics.extraPackages: Additional graphics packages.
  # Default: []. Current: Intel media decoding drivers.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver   # Default: N/A. Current: Primary VA-API driver for Kaby Lake (Gen 9)
    intel-vaapi-driver   # Default: N/A. Current: Crucial legacy fallback layer for older media apps
    libvdpau-va-gl       # Default: N/A. Current: VDPAU driver translation layer
  ];

  # hardware.bluetooth.enable: Enables Bluetooth support.
  # Default: false. Current: true.
  hardware.bluetooth.enable = true;

  # hardware.bluetooth.settings: Bluetooth configuration.
  # Default: {}. Current: Enables experimental features for battery tracking.
  hardware.bluetooth.settings = {
    General = {
      Experimental = true;                 # Default: false. Current: true (Enables peripheral battery tracking in the KDE panel)
      Enable = "Source,Sink,Media,Socket"; # Default: unset. Current: Ensures complete media control profile mapping
    };
  };

  # ──────────────────────────────────────────────────────────────────────
  #  NETWORKING
  # ──────────────────────────────────────────────────────────────────────
  # networking.hostName: The hostname of the machine.
  # Default: "nixos". Current: "nixos-inspiron-7560".
  networking.hostName = "nixos-inspiron-7560";

  # networking.networkmanager.enable: Enables NetworkManager.
  # Default: false. Current: true (Standard for desktop networking).
  networking.networkmanager.enable = true;

  # networking.networkmanager.dns: Delegates DNS resolution to systemd-resolved.
  # Default: "default". Current: "systemd-resolved" (Ensures resolved controls DNS-over-TLS/DNSSEC).
  networking.networkmanager.dns = "systemd-resolved";

  # networking.firewall.enable: Enables the firewall.
  # Default: true. Current: true.
  networking.firewall.enable = true;

  # networking.firewall.allowedTCPPorts: Open TCP ports.
  # Default: []. Current: [].
  networking.firewall.allowedTCPPorts = [];

  # networking.firewall.allowedUDPPorts: Open UDP ports.
  # Default: []. Current: [].
  networking.firewall.allowedUDPPorts = [];

  # networking.firewall.checkReversePath: Configures reverse path filtering.
  # Default: true. Current: "loose" (Needed for Docker/Kubernetes routing).
  networking.firewall.checkReversePath = "loose";

  # networking.nameservers: List of DNS servers.
  # Default: []. Current: Cloudflare & Google (IPv4 & IPv6).
  networking.nameservers = [
    "1.1.1.1"              # Default: From DHCP. Current: Cloudflare IPv4
    "8.8.8.8"              # Default: From DHCP. Current: Google IPv4
    "2606:4700:4700::1111" # Default: From DHCP. Current: Cloudflare IPv6
    "2001:4860:4860::8888" # Default: From DHCP. Current: Google IPv6
  ];

  # ──────────────────────────────────────────────────────────────────────
  #  LOCALE & TIME
  # ──────────────────────────────────────────────────────────────────────
  # time.timeZone: The time zone setting.
  # Default: null. Current: "Asia/Kolkata".
  time.timeZone = "Asia/Kolkata";

  # time.hardwareClockInLocalTime: Keeps hardware clock in local time.
  # Default: false (UTC). Current: true (Often needed when dual-booting Windows).
  time.hardwareClockInLocalTime = true;

  # Set default language to US but use Indian formats (NixOS will automatically generate both locales)
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };



  # ──────────────────────────────────────────────────────────────────────
  #  DESKTOP ENVIRONMENT & DISPLAY
  # ──────────────────────────────────────────────────────────────────────
  # services.xserver.enable: Enables X11 (and Wayland fallback).
  # Default: false. Current: true.
  services.xserver.enable = true;

  # services.xserver.videoDrivers: Explicitly defines the video driver.
  # Default: []. Current: ["modesetting"] (Forces Intel modesetting driver).
  services.xserver.videoDrivers = [ "modesetting" ];

  # services.displayManager.sddm.enable: Enables the SDDM display manager.
  # Default: false. Current: true.
  services.displayManager.sddm.enable = true;

  # services.displayManager.sddm.wayland.enable: Renders the login screen via Wayland.
  # Default: false. Current: true (Pure Wayland login session).
  services.displayManager.sddm.wayland.enable = true;

  # services.desktopManager.plasma6.enable: Enables KDE Plasma 6.
  # Default: false. Current: true.
  services.desktopManager.plasma6.enable = true;

  # services.xserver.xkb: XKB keyboard layout configuration.
  # Default: { layout = "us"; }. Current: layout = "us".
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # xdg.portal.enable: Enables XDG desktop portals.
  # Default: false. Current: true (Needed for Flatpak and Wayland screen sharing).
  xdg.portal.enable = true;

  # xdg.portal.extraPortals: Additional portals to load.
  # Default: []. Current: GTK portal for GTK app file dialogs.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # ──────────────────────────────────────────────────────────────────────
  #  AUDIO (PIPEWIRE)
  # ──────────────────────────────────────────────────────────────────────
  # services.pulseaudio.enable: Enables legacy PulseAudio.
  # Default: false. Current: false (Using PipeWire instead).
  services.pulseaudio.enable = false;

  # security.rtkit.enable: Enables RealtimeKit for prioritizing audio threads.
  # Default: false. Current: true.
  security.rtkit.enable = true;

  # services.pipewire.enable: Enables PipeWire sound server.
  # Default: false. Current: true.
  services.pipewire = {
    enable = true;             # Default: false. Current: true (Main sound server)
    alsa.enable = true;        # Default: false. Current: true (ALSA support)
    alsa.support32Bit = true;  # Default: false. Current: true (32-bit ALSA apps)
    pulse.enable = true;       # Default: false. Current: true (PulseAudio emulation)
  };

  # services.pipewire.extraConfig: Advanced PipeWire config.
  # Default: {}. Current: Low latency quantum tuning.
  services.pipewire.extraConfig.pipewire."92-low-latency" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 512;
      "default.clock.min-quantum" = 512;
      "default.clock.max-quantum" = 1024;
    };
  };

  # services.pipewire.wireplumber.extraConfig: Advanced WirePlumber config.
  # Default: {}. Current: High-quality Bluetooth codec enhancements.
  services.pipewire.wireplumber.extraConfig."10-bluez-tweaks" = {
    "monitor.bluez.properties" = {
      "bluez5.enable-sbc-xq" = true;
      "bluez5.enable-msbc" = true;
      "bluez5.enable-hw-volume" = true;
    };
  };

  # ──────────────────────────────────────────────────────────────────────
  #  SECURITY
  # ──────────────────────────────────────────────────────────────────────
  # security.apparmor.enable: Enables AppArmor mandatory access control.
  # Default: false. Current: true.
  security.apparmor = {
    enable = true;
    packages = [ pkgs.apparmor-profiles ];
  };

  # security.pam.loginLimits: Configures limits.conf.
  # Default: []. Current: Raises file descriptor limits and realtime audio limits.
  security.pam.loginLimits = [
    { domain = "*"; type = "-"; item = "nofile"; value = "524288"; }          # Default: 1024. Current: 524288 (Raises file descriptor limits)
    { domain = "@audio"; type = "-"; item = "rtprio"; value = "95"; }         # Default: 0. Current: 95 (Real-time thread scheduling ceiling)
    { domain = "@audio"; type = "-"; item = "memlock"; value = "unlimited"; } # Default: unset. Current: unlimited (Prevents page swapping out of audio layers)
  ];

  # security.sudo.execWheelOnly: Restricts sudo to the wheel group only.
  # Default: false. Current: true.
  security.sudo.execWheelOnly = true;

  # security.pam.services.*.enableKwallet: Allows KWallet to auto-unlock on login.
  # Default: false. Current: true.
  security.pam.services.sddm.enableKwallet = true;
  security.pam.services.kdewallet.enableKwallet = true;

  # ──────────────────────────────────────────────────────────────────────
  #  SERVICES
  # ──────────────────────────────────────────────────────────────────────
  # services.udev.extraRules: Custom udev rules.
  # Default: "". Current: Optimizes NVMe and aggressively removes NVIDIA GPU from PCI bus.
  services.udev.extraRules = ''
    # NVMe flash storage performance pathing
    ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme*", ATTR{queue/scheduler}="none"

    # Completely remove the NVIDIA VGA/3D Graphics Controller from the PCI bus
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ATTR{power/control}="auto", ATTR{remove}="1"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", ATTR{power/control}="auto", ATTR{remove}="1"

    # Remove the paired NVIDIA HDMI Audio controller to prevent phantom power draw
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
  '';

  # services.thermald.enable: Prevents Intel CPUs from overheating.
  # Default: false. Current: true.
  services.thermald.enable = true;

  # services.timesyncd.enable: NTP time synchronization.
  # Default: true. Current: true.
  services.timesyncd.enable = true;

  # services.dbus.implementation: D-Bus implementation.
  # Default: "dbus". Current: "broker" (High performance drop-in replacement).
  services.dbus.implementation = "broker";

  # services.printing.enable: Enables CUPS printing.
  # Default: false. Current: true.
  services.printing.enable = true;

  # services.resolved: Systemd-resolved configuration.
  # Default: enabled. Current: Enforces DNSSEC and opportunistic DNS-over-TLS.
  services.resolved = {
    enable = true;             # Default: true. Current: true (Enables systemd-resolved)
    settings = {
      Resolve = {
        DNSSEC = "allow-downgrade";              # Default: "allow-downgrade". Current: "true" (Enforce cryptographic validation of DNS responses)
        DNSOverTLS = "opportunistic";  # Default: "no". Current: "opportunistic" (Encrypt all DNS lookups when supported, prevents captive portal breakage)
        FallbackDNS = [
          "1.1.1.1#cloudflare-dns.com"
          "9.9.9.9#dns.quad9.net"
        ]; # Default: list of default fallbacks. Current: Cloudflare & Quad9 securely configured
      };
    };
  };

  # services.fstrim.enable: Enables SSD TRIM.
  # Default: false. Current: true.
  services.fstrim.enable = true;

  # services.ananicy.enable: Auto-renice daemon for desktop responsiveness.
  # Default: false. Current: true.
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  # services.btrfs.autoScrub: Periodic Btrfs scrubbing.
  # Default: false. Current: true (Monthly).
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # services.journald.extraConfig: Systemd journal configuration.
  # Default: "". Current: Caps logs at 500MB and 7 days.
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxFileSec=7d
  '';

  # services.avahi.enable: mDNS/DNS-SD discovery.
  # Default: false. Current: true (Allows local hostname discovery).
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # services.irqbalance.enable: Distributes hardware interrupts across CPUs.
  # Default: false. Current: true.
  services.irqbalance.enable = true;

  # services.openssh.enable: Enables SSH daemon.
  # Default: false. Current: true (Hardened: key-only auth, no root login).
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;   # Default: true. Current: false (Key-only authentication)
      PermitRootLogin = "no";           # Default: "prohibit-password". Current: "no" (No root SSH at all)
    };
  };

  # services.earlyoom.enable: Kills memory-heavy processes before system freezes.
  # Default: false. Current: true (Threshold raised to 8% for safety).
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 8;  # Default: 10. Current: 8 (Trigger when RAM falls below 8%)
    freeSwapThreshold = 5; # Default: 10. Current: 5 (Trigger when Swap falls below 5%)
    extraArgs = [
      "-g"                                             # Default: unset. Current: Prefer killing process group leader
      "--prefer" "(-|.*/)?(node|docker|kubectl|kind)$" # Default: unset. Current: Target rogue dev runtimes first
      "--avoid" "(-|.*/)?(plasma6|sddm|brave)$"        # Default: unset. Current: Avoid killing your active desktop/browser
    ];
  };

  # services.fwupd.enable: Allows firmware updates (BIOS/UEFI).
  # Default: false. Current: true.
  services.fwupd.enable = true;

  # services.gnome.gnome-keyring.enable: GNOME Keyring daemon.
  # Default: false. Current: true (Useful for Brave/Chrome).
  services.gnome.gnome-keyring.enable = true;

  # services.flatpak.enable: Enables Flatpak application support.
  # Default: false. Current: true.
  services.flatpak.enable = true;

  # services.upower.enable: Advanced power management daemon.
  # Default: false. Current: true (Improves battery status reporting).
  services.upower.enable = true;

  # ──────────────────────────────────────────────────────────────────────
  #  POWER MANAGEMENT
  # ──────────────────────────────────────────────────────────────────────
  # powerManagement.cpufreq.max: Maximum CPU frequency in kHz.
  # Commented out to prioritize TLP's scaling governor and frequency tuning.
  # powerManagement.cpufreq.max = 2900000;

  # Disable conflicting power management daemons
  services.power-profiles-daemon.enable = false;

  # Advanced Laptop Power Management Engine
  services.tlp = {
    enable = true;
    settings = {
      # CPU Performance and Energy Scaling
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # Intel P-state limits (capping 3.5 GHz max turbo to 2.9 GHz = ~83%)
      CPU_MAX_PERF_ON_AC = 83;
      CPU_MAX_PERF_ON_BAT = 83;

      # Dell Motherboard Battery Care Thresholds
      START_CHARGE_THRESH_BAT0 = 80;
      STOP_CHARGE_THRESH_BAT0 = 90;

      # Connectivity & Radios
      WOL_DISABLE = "Y";
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";

      # USB Hardware Management
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_PHONE = 1; # Stops phone debugging interfaces from disconnecting

      # Onboard Realtek Audio Power Tuning
      SOUND_POWER_SAVE_ON_AC = 1;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";
      SOUND_POWER_SAVE_TIMEOUT_ON_AC = 1800; # 30 min delay prevents audio crackling
      SOUND_POWER_SAVE_TIMEOUT_ON_BAT = 1800;

      # Bus and Controller Optimization
      SATA_LINKPWR_ON_AC = "med_power_with_dipm";
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
      PCIE_ASPM_ON_AC = "powersave";
      PCIE_ASPM_ON_BAT = "powersave";

      # PCI Runtime Power Management
      RUNTIME_PM_ON_AC = "on";           # Keep PCI devices always on while plugged in
      RUNTIME_PM_ON_BAT = "auto";        # Auto-suspend idle PCI devices on battery
    };
  };

  # zramSwap.enable: Uses compressed RAM as swap.
  # Default: false. Current: true (100% of RAM size).
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };

  # ──────────────────────────────────────────────────────────────────────
  #  USERS & PACKAGES
  # ──────────────────────────────────────────────────────────────────────
  # users.users.<name>: Defines user accounts.
  # Current: Configures 'ndhiman' with Zsh and specific group memberships.
  users.users."ndhiman" = {
    isNormalUser = true;         # Default: false. Current: true
    description = "Nikhil Dhiman"; # Default: "". Current: "Nikhil Dhiman"
    shell = pkgs.zsh;            # Default: pkgs.bash. Current: pkgs.zsh
    extraGroups = [ "networkmanager" "wheel" "docker" "audio" ]; # Default: []. Current: Assigned groups
    packages = with pkgs; [
      brave                      # Default: unset. Current: Web browser
      kubectl                    # Default: unset. Current: Kubernetes CLI
      kind                       # Default: unset. Current: Local Kubernetes
      kdePackages.yakuake        # Default: unset. Current: Drop-down terminal
      antigravity                # Default: unset. Current: IDE/Editor
      motrix                     # Default: unset. Current: Download manager
      beekeeper-studio           # Default: unset. Current: Database GUI
      onlyoffice-desktopeditors  # Default: unset. Current: Office suite
      vlc                        # Default: unset. Current: Media player
      postman                    # Default: unset. Current: API testing
      nodejs                     # Default: unset. Current: JS Runtime
      kubernetes-helm            # Default: unset. Current: K8s package manager
      fastfetch                  # Systems information layout visualizer
      lsd                        # Modern replacement for 'ls'
      bat                        # Syntax-highlighting cat clone
      ripgrep                    # Ultra-fast text search engine
      fd                         # Simple, fast alternative to 'find'
    ];
  };

  # nixpkgs.config.allowUnfree: Allows installation of non-open-source software.
  # Default: false. Current: true.
  nixpkgs.config.allowUnfree = true;

  # environment.systemPackages: Packages available system-wide.
  # Default: []. Current: Core utilities.
  environment.systemPackages = with pkgs; [
    vim  # Default: unset. Current: Command line editor
    git  # Default: unset. Current: Version control
    btop # Default: unset. Current: System monitor
    kdePackages.partitionmanager # Default: unset. Current: Disk management (requires system-wide Polkit rules)
  ];

  # fonts.packages: System fonts to install.
  # Default: []. Current: Core fonts and emoji support.
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code   # Default: unset. Current: Monospace font with ligatures
    noto-fonts             # Default: unset. Current: Universal fallback font
    noto-fonts-cjk-sans    # Default: unset. Current: Asian language support
    noto-fonts-color-emoji # Default: unset. Current: Emoji support
  ];

  # ──────────────────────────────────────────────────────────────────────
  #  PROGRAMS (ZSH, GIT, STARSHIP, ETC)
  # ──────────────────────────────────────────────────────────────────────
  # programs.firefox.enable: Enables Firefox.
  # Default: false. Current: false.
  programs.firefox.enable = false;

  # programs.zsh.enable: Enables the Z shell.
  # Default: false. Current: true (With comprehensive aliases and plugins).
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    # Aliases ported from your configuration
    shellAliases = {
      reload = "source ~/.zshrc";
      ".." = "cd ..";
      "..." = "cd ../..";
      ".3" = "cd ../../..";
      c = "clear";
      x = "exit";

      # High-visibility output overrides
      ls = "lsd";
      l = "lsd -AF --group-directories-first";
      ll = "lsd -lAFh --group-directories-first";
      grep = "grep --color=auto";
      diff = "diff --color=auto";
      ip = "ip -color=auto";
      cat = "bat";

      # Defensive Safeguards against data-loss
      rm = "rm -iv";
      cp = "cp -iv";
      mv = "mv -iv";

      # Git Tracking Shortcuts
      gs = "git status";
      ga = "git add";
      gaa = "git add .";
      gc = "git commit -m";
      gca = "git commit -am";
      gp = "git push";
      gl = "git pull";
      glog = "git log --oneline --graph --decorate --all";
      gco = "git checkout";
      gb = "git branch";

      # Local Workspace Housekeeping Operations
      nuke-modules = "find . -name \"node_modules\" -type d -prune -exec rm -rf {} + && echo \"node_modules deleted\"";

      # Enterprise Datastore Interface Hooks
      pg-start = "sudo systemctl start postgresql";
      pg-stop = "sudo systemctl stop postgresql";
      pg-status = "systemctl status postgresql";
      redis-start = "sudo systemctl start redis";
      redis-stop = "sudo systemctl stop redis";

      # Runtime Engine Interfaces
      pn = "pnpm";
      pni = "pnpm install";
      pnd = "pnpm dev";
      pnb = "pnpm build";
      pnt = "pnpm test";

      # Hypervisor & High-Performance Virtualization Vectors
      d = "docker";
      db = "docker build";
      dr = "docker run --rm -it";
      dps = "docker ps";
      dpa = "docker ps -a";
      di = "docker images";
      dex = "docker exec -it";
      dlog = "docker logs -f";
      dstopall = "docker stop $(docker ps -aq)";
      drmall = "docker rm $(docker ps -aq)";
      dprune = "docker system prune -a --volumes -f";

      # Orchestration Configuration Matrices (Kubernetes / Minikube)
      k = "kubectl";
      ka = "kubectl apply -f";
      kdel = "kubectl delete";
      kdelf = "kubectl delete -f";
      kg = "kubectl get";
      kgp = "kubectl get pods";
      kgpa = "kubectl get pods --all-namespaces";
      kgs = "kubectl get svc";
      kgd = "kubectl get deployments";
      kgn = "kubectl get nodes";
      kgns = "kubectl get namespaces";
      kd = "kubectl describe";
      kdp = "kubectl describe pod";
      klogs = "kubectl logs -f";
      kex = "kubectl exec -i -t";
      kpf = "kubectl port-forward";
      mk = "minikube";
      mks = "minikube start";
      mkx = "minikube stop";
      mkst = "minikube status";
      mkd = "minikube dashboard";
      mkip = "minikube ip";
      mkenv = "eval $(minikube podman-env)";

      # Identity Access Management Cloud Interfaces
      awswho = "aws sts get-caller-identity";
      awsregion = "aws configure get region";
      awslogin = "aws sso login";

      # System Telemetry & Process Investigation Vectors
      listen = "sudo ss -tunlp | grep LISTEN";
      port = "sudo lsof -i -P -n | grep LISTEN";
      myip = "curl -s ifconfig.me && echo \"\"";
      localip = "ip -br a 2>/dev/null || ip address";
      pingg = "ping -c 4 8.8.8.8";
      flushdns = "command -v resolvectl &>/dev/null && resolvectl flush-caches || sudo systemd-resolve --flush-caches 2>/dev/null || echo \"DNS flush skipped (systemd-resolved target absent)\"";
      get = "curl -i";
      mx = "chmod +x";
      mine = "sudo chown -R $USER:$USER";

      # Advanced Systemd Daemon & Core Telemetry Pipeline
      sstart = "sudo systemctl start";
      sstop = "sudo systemctl stop";
      srestart = "sudo systemctl restart";
      sstatus = "systemctl status";
      senable = "sudo systemctl enable --now";
      sdisable = "sudo systemctl disable --now";
      scu = "systemctl --user";
      scustatus = "systemctl --user status";
      jlog = "journalctl -xe";
      jtail = "journalctl -f";
      jcrash = "journalctl -p 3 -xb";
      ju = "journalctl -u";
      jclean = "sudo journalctl --vacuum-time=7d";

      # Bare-Metal Memory / Storage Performance Inspection
      df = "df -h";
      du = "du -sh * | sort -h";
      disks = "lsblk -f";
      free = "free -h";
      meminfo = "free -m -l -t";
      cpuinfo = "lscpu";
      psg = "ps aux | grep -v grep | grep -i";
      myps = "ps -U $USER";
      ka9 = "killall -9";
      sysinfo = "command -v fastfetch &>/dev/null && fastfetch || uname -a";

      # Environment Suspension & Execution State Changes
      reboot = "sudo reboot";
      poweroff = "sudo poweroff";
      suspend = "systemctl suspend";

      # Navigation / Editor bridges
      ag = "antigravity";
      agy = "antigravity";
      open = "xdg-open";
    };

    # Initialize custom shell options
    interactiveShellInit = ''
      # Configuration metadata for the completion systems engine
      zstyle :compinstall filename "$HOME/.zshrc"

      autoload -Uz compinit
      compinit -d "$HOME/.zcompdump" 2>/dev/null

      # Load and bind smart substring history search modules
      autoload -U up-line-or-beginning-search
      autoload -U down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search

      # History settings
      HISTFILE=~/.zsh_history
      HISTSIZE=500000
      SAVEHIST=500000

      # Shell options
      setopt EXTENDED_HISTORY
      setopt SHARE_HISTORY
      setopt HIST_EXPIRE_DUPS_FIRST
      setopt HIST_IGNORE_DUPS
      setopt HIST_IGNORE_ALL_DUPS
      setopt HIST_FIND_NO_DUPS
      setopt HIST_IGNORE_SPACE
      setopt HIST_SAVE_NO_DUPS

      # Terminal Keybindings (Emacs layout)
      bindkey -e

      # Interactive history search (Up/Down arrows)
      bindkey "^[[A" up-line-or-beginning-search
      bindkey "^[[B" down-line-or-beginning-search

      # Standard cursor and inline manipulation mapping fixes
      bindkey "^[[3~" delete-char               # Delete key
      bindkey "^[[H" beginning-of-line          # Home key standard variant A
      bindkey "^[[1~" beginning-of-line         # Home key standard variant B
      bindkey "^[OH" beginning-of-line          # Home key alternate map
      bindkey "^[[F" end-of-line                # End key standard variant A
      bindkey "^[[4~" end-of-line               # End key standard variant B
      bindkey "^[OF" end-of-line                # End key alternate map

      # Cursor manipulation bindings via Ctrl key vectors
      bindkey "^[[1;5C" forward-word            # Ctrl + Right Arrow
      bindkey "^[[1;5D" backward-word           # Ctrl + Left Arrow
      bindkey "^H" backward-kill-word           # Ctrl + Backspace
      bindkey "^[[3;5~" kill-word               # Ctrl + Delete

      # Inject local user binary paths securely
      export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

      # Node Package Manager (pnpm) Environment Configuration
      export PNPM_HOME="$HOME/.local/share/pnpm"
      case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
      esac

      # Displays environmental context layout upon terminal instance deployment
      if (( $+commands[fastfetch] )); then
          fastfetch
      fi
    '';
  };

  # programs.zoxide.enable: Smart directory navigation engine.
  # Default: false. Current: true.
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # programs.fzf.enable: Command-line fuzzy finder integration.
  # Default: false. Current: true.
  programs.fzf = {
    # enable = true;
    keybindings = true;
    fuzzyCompletion = true;
  };

  # programs.git.enable: Enables Git and sets global configuration.
  # Default: false. Current: true.
  programs.git = {
    enable = true;
    config = {
      user = {
        name = "Nikhil Dhiman";
        email = "nikhil.x.dhiman@gmail.com";
      };
      core.editor = "antigravity --wait";
      init.defaultBranch = "main";
      pull.rebase = false;
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        cm = "commit -m";
      };
    };
  };

  # programs.starship.enable: Enables the Starship cross-shell prompt.
  # Default: false. Current: true (With custom TOML config).
  programs.starship = {
    enable = true;
    settings = {
      "$schema" = "https://starship.rs/config-schema.json";
      add_newline = true;
      command_timeout = 800;
      format = ''
        ┌── $os$directory $git_branch$git_state$git_status$package$fill$nodejs$python$aws$docker_context$cmd_duration$status
        └── $character'';

      fill = {
        symbol = " ";
      };

      character = {
        success_symbol = "[➜ ](bold green)";
        error_symbol = "[➜ ](bold red)";
        vicmd_symbol = "[❮ ](bold yellow)";
      };

      os = {
        disabled = false;
        format = "[$symbol]($style) ";
        style = "bold white";
        symbols = {
          Windows = " ";
          Ubuntu = " ";
          Debian = " ";
          Fedora = " ";
          NixOS = " ";
          Linux = " ";
        };
      };

      directory = {
        truncation_length = 4;
        truncate_to_repo = true;
        style = "bold cyan";
        read_only = "󰌾 ";
        home_symbol = " ~";
      };

      git_branch = {
        symbol = " ";
        style = "bold magenta";
        format = "on [$symbol$branch]($style) ";
      };

      git_state = {
        style = "bold yellow";
        format = "[\\($state( $progress_current/$progress_total)\\)]($style) ";
      };

      git_status = {
        style = "bold red";
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        conflicted = "🏳 ";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${count}⇣\${count}";
        untracked = "\${count}";
        staged = "\${count}";
        modified = "📝\${count}";
        stashed = "📦";
        renamed = "";
        deleted = "🗑";
      };

      nodejs = {
        symbol = " ";
        style = "bold green";
        format = "via [$symbol($version)]($style) ";
      };

      python = {
        symbol = " ";
        style = "bold yellow";
        format = "via [$symbol($version)(\\($virtualenv\\))]($style) ";
      };

      aws = {
        symbol = " ";
        style = "bold yellow";
        format = "on [$symbol($profile)]($style) ";
      };

      docker_context = {
        symbol = " ";
        style = "bold blue";
        format = "inside [$symbol($context)]($style) ";
      };

      cmd_duration = {
        min_time = 2000;
        style = "bold yellow";
        format = "took [$duration]($style) ";
      };

      status = {
        disabled = false;
        style = "bold red";
        format = "[$symbol $code]($style)";
        symbol = "✘";
      };
    };
  };

  # programs.kdeconnect.enable: Enables KDE Connect.
  # Default: false. Current: true.
  programs.kdeconnect.enable = true;

  # programs.nix-ld.enable: Run unpatched dynamic binaries.
  # Default: false. Current: true.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib zlib fuse3 icu nss openssl curl expat libuuid
    ];
  };

  # programs.direnv.enable: Directory environments.
  # Default: false. Current: true.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # programs.mtr.enable: Network diagnostic tool.
  # Default: false. Current: true.
  programs.mtr.enable = true;

  # programs.gnupg.agent.enable: GPG key agent.
  # Default: false. Current: true.
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-qt;
  };

  # documentation.nixos.enable: Installs NixOS documentation locally.
  # Default: true. Current: false (Saves ~300MB).
  documentation.nixos.enable = false;

  # programs.appimage.enable: System-wide AppImage support.
  # Default: false. Current: true.
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # ──────────────────────────────────────────────────────────────────────
  #  VIRTUALISATION
  # ──────────────────────────────────────────────────────────────────────
  # virtualisation.docker.enable: Enables Docker daemon.
  # Default: false. Current: true.
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" "--volumes" ];
    };
  };

  # ──────────────────────────────────────────────────────────────────────
  #  NIX SETTINGS
  # ──────────────────────────────────────────────────────────────────────
  # nix.gc.automatic: Enables automatic garbage collection.
  # Default: false. Current: true (Weekly, older than 7d).
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # nix.settings: Core Nix package manager settings.
  # Default: {}. Current: Optimized caching, auto-optimization, and security sandboxing.
  nix.settings = {
    trusted-users = [ "root" "@wheel" ];
    allowed-users = [ "@wheel" ];      # Security: Restrict nix daemon access
    sandbox = true;                    # Security: Enforce build sandboxing
    connect-timeout = 5;
    stalled-download-timeout = 20;
    fallback = true;
    auto-optimise-store = true;
    min-free = 5368709120;  # 5 GB
    max-free = 10737418240; # 10 GB
  };

  # ──────────────────────────────────────────────────────────────────────
  #  SYSTEMD
  # ──────────────────────────────────────────────────────────────────────
  # systemd.settings.Manager: Systemd manager settings.
  # Default: {}. Current: 30s timeout to prevent hang on reboot.
  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "30s";
    DefaultTimeoutStopSec = "30s";
  };

  # systemd.coredump.enable: Process core dumps on crash.
  # Default: true. Current: false (Saves disk space).
  systemd.coredump.enable = false;

  # ──────────────────────────────────────────────────────────────────────
  #  ENVIRONMENT
  # ──────────────────────────────────────────────────────────────────────
  # environment.sessionVariables: Global environment variables.
  # Default: {}. Current: Wayland overrides and hardware decoding flags.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";      # Default: unset. Current: 1 (Forces Electron apps to Wayland)
    LIBVA_DRIVER_NAME = "iHD"; # Default: unset. Current: iHD (Forces Intel media rendering engine)
    VDPAU_DRIVER = "va_gl";    # Default: unset. Current: va_gl (Forces Intel media rendering engine)
    EDITOR = "antigravity --wait";    # Default: nano. Current: Antigravity Editor
    VISUAL = "antigravity --wait";    # Default: nano. Current: Antigravity Editor
  };

  # ──────────────────────────────────────────────────────────────────────
  #  SYSTEM STATE
  # ──────────────────────────────────────────────────────────────────────
  # system.stateVersion: NixOS release version for stateful data compatibility.
  # Default: matches install version. Current: "26.05". Do not change.
  system.stateVersion = "26.05";
}
