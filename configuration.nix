# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.editor = false; # SECURITY: Prevents editing kernel params at boot
  boot.loader.efi.canTouchEfiVariables = true;

  # Mounts the extra partition on boot
  fileSystems."/mnt/DATA" = {  # <--- Change this to your folder path
    device = "/dev/disk/by-uuid/c342fea6-6c69-4121-a97f-7231859b36b8"; # <--- Paste UUID here
    fsType = "ext4";  # <--- Change to "ntfs", "btrfs", or "auto" if unsure
    options = [ "nofail" "defaults" ]; # "nofail" prevents boot hang if drive is missing
  };

  # Microcode
  hardware.cpu.intel.updateMicrocode = true;
  services.fwupd.enable = true; # SECURITY: Allows BIOS/Firmware updates




  networking.hostName = "nixos-inspiron-7560"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # --- GRAPHICS CONFIGURATION (Fixes the Nouveau/SDDM Crashes) ---
  # Enable OpenGL/Vulkan
  hardware.graphics = {
    enable = true;
    # 1. INTEL MEDIA DRIVERS (Keep these!)
    # Crucial for hardware video decoding (saving battery) on your Kaby Lake CPU
    extraPackages = with pkgs; [
      intel-media-driver   # LIBVA_DRIVER_NAME=iHD
      intel-vaapi-driver   # LIBVA_DRIVER_NAME=i965 (Legacy fallback)
      # vpl-gpu-rt removed (Not supported on Kaby Lake)
    ];
  };

  # Disable Nvidia Graphics & Card
  # 1. Force the use of Intel/Integrated drivers
  services.xserver.videoDrivers = [ "modesetting" ];

  # 2. Blacklist all Nvidia modules to prevent them from loading
  boot.blacklistedKernelModules = [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" ];

  # 4. Physically power down the GPU using udev rules
  # This is the most effective way for 940MX-era laptops to save battery.
  services.udev.extraRules = ''
    # Put NVIDIA GPU into runtime power save (D3Cold)
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="auto"
    ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="auto"
  '';
#   services.udev.extraRules = ''
#     # Remove NVIDIA VGA/3D controller devices
#     ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ATTR{remove}="1"
#     ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", ATTR{remove}="1"
#   '';

  # Kernel parameters for optimization
  boot.kernelParams = [
    "mem_sleep_default=deep"
    "button.lid_init_state=open"
    "intel_pstate=active"
    "zswap.enabled=1"
    "zswap.compressor=zstd"
    "zswap.zpool=zsmalloc"
    "zswap.max_pool_percent=30"
    "resume_offset=4454400" # Ensure this offset is still correct!
    "elevator=bfq"        # Better desktop responsiveness during disk heavy loads
    # Intel Graphics Tuning
    "i915.enable_rc6=1"  # Powers down Render engine when idle
    "i915.enable_fbc=1"   # Framebuffer compression (Saves power)
    "i915.enable_psr=0"   # Explicitly DISABLE PSR (Prevents flickering)
    "i915.panel_use_ssc=1" # Spread Spectrum Clocking (Lowers EMI)
    "i915.enable_dc=1"    # Display Power Management (Deep sleep for screen)
    # Disable Nvidia
    "nouveau.modeset=0"
    "nvidia-drm.modeset=0"
    # Intel CPU
#     "intel_idle.max_cstate=4"
    # Security Hardening (Kernel Level)
    "page_alloc.shuffle=1"    # Security: Randomize page allocator (Makes memory exploits harder)
    "rng_core.default_quality=1000" # Ensure good entropy for encryption
    "slab_nomerge"
  ];

  # Session Variables: Force Wayland and Intel Driver
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";         # Force Electron apps to use Wayland
    LIBVA_DRIVER_NAME = "iHD";    # Force Intel Media Driver (Hardware Decode)
  };

  # Power Management
  # 1. Disable conflicting services
  services.power-profiles-daemon.enable = false;
  services.upower.enable = true; # Added for better battery monitoring in KDE

  # 2. Enable Thermald (Excellent for Intel CPUs)
  services.thermald.enable = true;

  # --- AUTO-CPUFREQ (Intelligent CPU Management) ---
#   services.auto-cpufreq.enable = true;
#   services.auto-cpufreq.settings = {
#     battery = {
#       governor = "powersave";
#       turbo = "never";
#       energy_performance_preference = "balance_power";
#       energy_perf_bias = 8;
#       scaling_max_freq = 2500000;
#
#       # DELL THERMAL PROFILE
#       platform_profile = "balanced";    # Tells BIOS to reduce fan/voltage
#     };
#     charger = {
#       governor = "powersave";
#       turbo = "auto";
#       energy_performance_preference = "balance_performance";
#       energy_perf_bias = 8;
#       scaling_max_freq = 3000000;
#
#       platform_profile = "balanced";  # Max cooling/power from BIOS
#     };
#   };

  # 3. TLP: The industry standard for laptop power
  services.tlp = {
    enable = true;
    settings = {

      # --- 1. GOVERNOR (The Foundation) ---
      # "powersave" is the correct modern default for Intel CPUs.
      # It allows the CPU to idle low but boost high when needed.
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # --- 2. TURBO BOOST (The "Turbo" setting) ---
      # 1 = Enabled (Auto), 0 = Disabled (Never)
      # Disabling turbo on battery creates huge power savings.
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # --- 3. EPP: ENERGY PERFORMANCE PREFERENCE (The "Hardware" Hint) ---
      # This tells the hardware (HWP) how aggressive to be.
      # balance_performance = snappy response
      # balance_power = hesitant to boost (saves battery)
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

      # --- 4. EPB: ENERGY PERFORMANCE BIAS (The "Software" Hint) ---
      # 0-15 scale. 8 is "normal/balanced".
      # Matches your "energy_perf_bias = 8" setting.
      CPU_ENERGY_PERF_BIAS_ON_AC = 8;
      CPU_ENERGY_PERF_BIAS_ON_BAT = 8;

      # --- 5. FREQUENCY LIMITS (The "scaling_max_freq") ---
      # TLP takes values in kHz.
      # 3000000 kHz = 3.0 GHz
      # 2500000 kHz = 2.5 GHz
      CPU_SCALING_MAX_FREQ_ON_AC = 3000000;
      CPU_SCALING_MAX_FREQ_ON_BAT = 2500000;

      # --- 6. PLATFORM PROFILE (The BIOS/Dell Control) ---
      # This controls the fans and voltage limits at the firmware level.
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "balanced";

      # Battery Care (Crucial for Dell Laptops)max_performance
      # Stops charging at 80% to prolong lifespan.
      START_CHARGE_THRESH_BAT0 = 80;
      STOP_CHARGE_THRESH_BAT0 = 90;

      # --- RUNTIME POWER MANAGEMENT ---
      # "auto" = powersave, "on" = performance
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";

      # --- PERIPHERALS ---
      # Disable Wake-on-LAN (Saves power during sleep)
      WOL_DISABLE = "Y";
      USB_AUTOSUSPEND = 1;
#       USB_EXCLUDE_BTUSB = 1; # Fixes Bluetooth Mouse lag/disconnects
      USB_EXCLUDE_PHONE = 1; # Fixes Phone charging drops

      # WiFi Power Saving: Off on AC (Stable gaming/downloads), On for Battery
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";
#       WIFI_PWR_ON_BAT = "off";

      # Aggressive Audio Power Saving
      # 15 minutes * 60 seconds = 900 seconds
      SOUND_POWER_SAVE_ON_AC = 1;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";
      SOUND_POWER_SAVE_TIMEOUT_ON_AC = 1800;
      SOUND_POWER_SAVE_TIMEOUT_ON_BAT = 900; # 15 minutes delay prevents "pop"

      # Storage Power
      DISK_SPINDOWN_TIMEOUT_ON_AC = "240";
      DISK_SPINDOWN_TIMEOUT_ON_BAT = "180"; # Spin down HDD

      # Max power saving for HDD (Spin down aggressively)
      DISK_APM_LEVEL_ON_AC = "192";
      DISK_APM_LEVEL_ON_BAT = "192";

      # SATA Link Power: The safe middle ground for SSDs
      SATA_LINKPWR_ON_AC = "med_power_with_dipm";
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";

      # Platform
#       PCIE_ASPM_ON_AC = "default";
        PCIE_ASPM_ON_AC = "powersave";
#       PCIE_ASPM_ON_BAT = "powersave";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # Disable the watchdog (Saves CPU wakeups)
      NMI_WATCHDOG = 0;
    };
  };

  # Enable networking
  networking.networkmanager.enable = true;

  # Nix Configuration
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 21d";
  };
  nix.settings.auto-optimise-store = true;

  # Set your time zone.
  time.timeZone = "Asia/Kolkata";
  time.hardwareClockInLocalTime = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

    i18n.extraLocaleSettings = {
    # Use en_GB (United Kingdom) for formats to get DD/MM/YYYY and Metric.
    # en_IN causes build failures on NixOS, and en_GB is functionally identical for formats.
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = false;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  # Fixes Lock Screen Resolutin & screen lock
#   services.xserver.displayManager.setupCommands = ''
#     # --- SLEEP FIX ---
#     # Turn off monitor after 60 seconds of inactivity
#     ${pkgs.xorg.xset}/bin/xset dpms 0 0 60
#
#     # --- SCALE FIX (125%) ---
#     # Force the DPI to 120 (96 * 1.25)
#     # This makes fonts and UI elements 25% larger
#     ${pkgs.xorg.xrdb}/bin/xrdb -merge <<EOF
#     Xft.dpi: 120
#     EOF
#   '';

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  services.flatpak.enable = true;


  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nikhil-dhiman = {
    isNormalUser = true;
    description = "Nikhil Dhiman";
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "podman" ];
    packages = with pkgs; [
    #  thunderbird
    git
    google-chrome
    postman
    persepolis
    vscode
    btop
    kdePackages.yakuake
    kdePackages.partitionmanager
    kdePackages.kcalc
    kdePackages.kamoso
    appimage-run
    vlc
    wget
    onlyoffice-desktopeditors
    nodejs_24
    pnpm
    powertop
    podman-desktop
    podman-compose
    docker-compose
    kubectl           # The Kubernetes CLI resource
    kubernetes-helm   # (Optional) Useful if you use Helm charts
    minikube          # (Optional) For a local Kubernetes cluster resource
    # Compilers & Tools
    gcc
    gnumake
    cmake
    ninja
    gdb
    valgrind
    clang-tools
    ];
  };

  # 1. Allow excluding standard packages
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    gwenview      # Image Viewer
    print-manager # If you don't use a printer
    krdc          # Remote Desktop Client
  ];

  # 2. Remove default NixOS tools you might not need
  documentation.nixos.enable = false; # Removes local manual (saves ~300MB)


  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  #  direnv
  #  nix-direnv
#     flatseal # GUI to manage Flatpak permissions
    vulnix   # Tool to scan your NixOS system for known vulnerabilities
    systemdgenie
    distrobox
    boxbuddy
  ];

  # Enable the Podman Socket (Critical for Podman Desktop)
  virtualisation.containers.enable = true;

  # --- VIRTUALISATION (Podman) ---
  # Enable Podman Service
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # Creates 'docker' alias
    dockerSocket.enable = true; # Required for Compose/Kubernetes tools to talk to Podman
    # This is the "Resource" Podman Desktop is looking for
    defaultNetwork.settings.dns_enabled = true;
  };

  # KDE Connect
  programs.kdeconnect.enable = true;

  # Programs & Shell
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      nix-switch = "sudo nixos-rebuild switch --flake ~/nixos-config#nixos-inspiron-7560";
      flake-update = "nix flake update";
      # Fixed escaping for Zsh
      zswap-usage = "sudo perl -E '\$zsw_stored = \`cat /sys/kernel/debug/zswap/stored_pages\` * 4096 / 1024**2; \$zsw_pool = \`cat /sys/kernel/debug/zswap/pool_total_size\` / 1024**2; printf \"Original data size: %.2f MB\\n\", \$zsw_stored; printf \"Compressed size:    %.2f MB\\n\", \$zsw_pool; printf \"Compression Ratio:  %.2f:1\\n\", \$zsw_stored / \$zsw_pool;'";
      swap-offset = "sudo filefrag -v /var/lib/swapfile | awk '\$1 == \"0:\" {print \$4}' | cut -d. -f1";
      disk-rotate = "lsblk -d -o name,model,size,rota";
    };
  };

  # Enable Direnv
  programs.direnv = {
      enable = true;
      nix-direnv.enable = true; # Highly recommended: makes loading faster and prevents GC
    };

  programs.starship = {
    enable = true;
    settings = {
      format = "$all$time$line_break$character";
      time = {
        disabled = false;
        use_12hr = true;
        format = "at 🕙[ $time ]($style) ";
        style = "bright-white";
      };
      add_newline = false;
    };
  };

  # AppImage Support
  programs.appimage = {
    enable = true;
    binfmt = true;
    package = pkgs.appimage-run.override {
      extraPkgs = pkgs: [ pkgs.libthai ];
    };
  };


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # --- SECURITY & KEYRING ---
  # 1. Allow KWallet to unlock automatically when you log in
  security.pam.services.sddm.enableKwallet = true;
  security.pam.services.kdewallet.enableKwallet = true; # Backup service

  # 2. Ensure the "Gnome Keyring" is also available (Chrome sometimes looks for this)
  services.gnome.gnome-keyring.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    dejavu_fonts
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      monospace = [ "FiraCode Nerd Font" "DejaVu Sans Mono" ];
    };
  };

  # Swapfile
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024;
      priority = 1;
    }
  ];
  boot.resumeDevice = "/dev/mapper/luks-fbe2fee1-eba1-414b-98d4-cdfb9af6b45b";

    # Power Button Behavior
  services.logind.settings = {
    Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandlePowerKey = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend-then-hibernate";
    };
  };
  systemd.sleep.extraConfig = ''
    AllowSuspend=yes
    AllowHibernation=yes
    AllowSuspendThenHibernate=yes
    HibernateDelaySec=12h
  '';

  systemd.tmpfiles.rules = [
    # OPTIMIZATION: Shrink the hibernation image size
    # '0' tells the kernel to compress as much as possible to save disk I/O time.
    # This makes hibernation 2x faster and less likely to fail on low battery.
    "w /sys/power/image_size - - - - 0"
  ];

  # Hardware Tweaks
  services.fstrim.enable = true; # SSD health

  # --- MEMORY SAFETY ---
  # Prevents system freezes when you run out of RAM
  services.earlyoom = {
    enable = true;
    enableNotifications = true; # Tells you when it kills something
    freeSwapThreshold = 2;
    freeMemThreshold = 10; # 10% is safer than 5% to prevent lockups
  };

    # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };


  # FIX: Add Portal support for Flatpaks/KDE (Fixes log errors)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  # --- SECURITY & HARDENING ---

  # 1. AppArmor (Mandatory Access Control)
  # Acts as a "firewall" for applications, restricting what they can access.
  security.apparmor = {
    enable = true;
    packages = with pkgs; [ apparmor-profiles ];
  };

  # 2. Kernel Hardening (Sysctl Tweaks)
  # These settings make it much harder for exploits to hijack the kernel.
  boot.kernel.sysctl = {
    # Hide kernel pointers from unprivileged users (prevents memory mapping exploits)
    "kernel.kptr_restrict" = 2;

    # Prevent users from viewing the kernel log (dmesg) without sudo
    "kernel.dmesg_restrict" = 1;

    # Harden the BPF JIT compiler (common attack vector)
    "net.core.bpf_jit_harden" = 2;

    # Randomize memory address space (ASLR) harder
    "vm.mmap_rnd_bits" = 32; # standard for 64-bit systems
    "vm.mmap_rnd_compat_bits" = 16;

    # Network Hardening: Ignore "ping" to broadcast addresses (prevents Smurf attacks)
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

    "kernel.kexec_load_disabled" = 1; # Prevent kernel replacement (Rootkit protection)

    # Log "Martian" Packets (packets claiming to be from impossible IP addresses)
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    # Strict Reverse Path Filter (Prevents IP spoofing)
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;

    "fs.protected_hardlinks" = 1; # Prevent link attacks
    "fs.protected_symlinks" = 1;  # Prevent link attacks

    # Disable IP forwarding (Your laptop is not a router)
#     "net.ipv4.ip_forward" = 0;

  # POWER SAVE: Disable NMI Watchdog (Saves CPU wakeups)
    "kernel.nmi_watchdog" = 0;

    "vm.swappiness" = 60;
  };

  # 3. DNS Security (DNS over TLS)
  # Encrypts your DNS requests so your ISP/Coffee Shop cannot spy on what websites you visit.
  # This replaces standard DNS handling.
  networking.nameservers = [ "8.8.8.8" "1.1.1.1" "8.8.4.4" "1.0.0.1" "9.9.9.9" ]; # Cloudflare & Quad9
  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [ "8.8.8.8" "1.1.1.1" "8.8.4.4" "1.0.0.1" ];
    dnsovertls = "opportunistic";
  };

  # 4. Limit "sudo" powers
  # Requires you to type your password for sudo (Default, but good to ensure)
  security.sudo.execWheelOnly = true; # Only 'wheel' group can use sudo

  # 4. Nix Sandbox (Build Security)
  nix.settings.sandbox = true;
  nix.settings.allowed-users = [ "@wheel" ];

  # 5. Core Dump Limiting (Not disabling, since you are a dev)
  systemd.coredump.extraConfig = ''
    Storage=external
    Compress=yes
    MaxUse=500M  # Don't let core dumps fill your disk
  '';

  # 5. Sandbox Flatpaks
  # You use Flatpaks. Install 'Flatseal' to easily revoke their permissions (Camera, Mic, etc).
  # See in System Packages


  # Post Installation

  # flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  # flatpak install flathub it.mijorus.gearlever

}
