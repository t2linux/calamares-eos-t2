#!/usr/bin/env bash

# New version of cleaner_script
# Made by @fernandomaroto and @manuel
# Any failed command will just be skipped, error message may pop up but won't crash the install process
# Net-install creates the file /tmp/run_once in live environment (need to be transfered to installed system) so it can be used to detect install option
# ISO-NEXT specific cleanup removals and additions (08-2021) @killajoe and @manuel
# 01-2022 passing in online and username as params - @dalto
# 04-2022 small code re-organization - @manuel
# 10-2022 remove unused code and support for dracut/mkinitcpio switch

_c_c_s_msg() {            # use this to provide all user messages (info, warning, error, ...)
    local type="$1"
    local msg="$2"
    echo "==> $type: $msg"
}

_pkg_msg() {            # use this to provide all package management messages (install, uninstall)
    local op="$1"
    local pkgs="$2"
    case "$op" in
        remove | uninstall) op="uninstalling" ;;
        install) op="installing" ;;
    esac
    echo "==> $op $pkgs"
}

_check_internet_connection() {
    case "$_CHROOTED_HAS_CONNECTION" in
        yes) return 0 ;;
        no)  return 1 ;;
        *)   eos-connection-checker && _CHROOTED_HAS_CONNECTION=yes || _CHROOTED_HAS_CONNECTION=no
             _check_internet_connection
             ;;
    esac
}

_is_pkg_installed() {  # this is not meant for offline mode !?
    # returns 0 if given package name is installed, otherwise 1
    local pkgname="$1"
    pacman -Q "$pkgname" >& /dev/null
}

_remove_a_pkg() {
    local pkgname="$1"
    _pkg_msg remove "$pkgname"
    pacman -Rsn --noconfirm "$pkgname"
}

_remove_pkgs_if_installed() {  # this is not meant for offline mode !?
    # removes given package(s) and possible dependencies if the package(s) are currently installed
    local pkgname
    local removables=()
    for pkgname in "$@" ; do
        if _is_pkg_installed "$pkgname" ; then
            _pkg_msg remove "$pkgname"
            removables+=("$pkgname")
        fi
    done
    if [ -n "$removables" ] ; then
        pacman -Rs --noconfirm "${removables[@]}"
    fi
}

_install_needed_packages() {
    if _is_online_mode ; then
        if _check_internet_connection ; then
            _pkg_msg install "if missing: $*"
            pacman -S --needed --noconfirm "$@"
        else
            _c_c_s_msg warning "no internet connection, cannot install packages $*"
        fi
    else
        _c_c_s_msg warning "offline mode, not installing packages $*"
    fi
}


##################################################################
# Virtual machine stuff.
# For virtual machines we assume internet connection exists.
##################################################################

_virt_remove() {
    local pkg
    for pkg in "$@" ; do
        _pkg_msg remove "$pkg"
        pacman -Rns --noconfirm "$pkg"
    done
}

_vm_environment_set1() {
    local varname="$1"
    if [ -z "$(grep "^$varname=" /etc/environment)" ] ; then
        _c_c_s_msg info "adding $varname=1 to /etc/environment"
        echo "$varname=1" >> /etc/environment
    fi
}

_sway_in_vm_settings() {
    # Settings for sway in a virtual machine
    if [ -x /usr/bin/swaybg ] ; then
        # We are using sway here (see also: eos-script-lib-yad, eos_IsSway()).
        _vm_environment_set1 WLR_NO_HARDWARE_CURSORS
        case "$detected_vm" in
            qemu) _vm_environment_set1 WLR_RENDERER_ALLOW_SOFTWARE ;;
        esac
    fi
}

_virtual_machines() {
    local detected_vm="$1"
    local pkgs_common="xf86-video-vmware"
    local pkgs_remove_from_vm="power-profiles-daemon"
    local pkgs_vbox="virtualbox-guest-utils"
    local pkgs_qemu="qemu-guest-agent spice-vdagent"
    local pkgs_vmware="open-vm-tools xf86-input-vmmouse"

    [ -n "$detected_vm" ] || detected_vm="$(device-info --vm)"

    case "$detected_vm" in               # 2021-Sep-30: device-info may output one of: "virtualbox", "qemu", "kvm", "vmware" or ""
        virtualbox)
            _c_c_s_msg info "VirtualBox VM detected."
            _virt_remove $pkgs_qemu $pkgs_vmware $pkgs_remove_from_vm
            _install_needed_packages $pkgs_vbox $pkgs_common
            _sway_in_vm_settings           # Note: sway requires enabling 3D support for the vbox virtual machine!
            ;;
        vmware)
            _c_c_s_msg info "VmWare VM detected."
            _virt_remove $pkgs_qemu $pkgs_vbox $pkgs_remove_from_vm
            _install_needed_packages $pkgs_vmware $pkgs_common
            _sway_in_vm_settings
            ;;
        qemu)
            # common pkgs ??
            _c_c_s_msg info "Qemu VM detected."
            _virt_remove $pkgs_vmware $pkgs_vbox $pkgs_common $pkgs_remove_from_vm
            _install_needed_packages $pkgs_qemu
            _sway_in_vm_settings
            ;;
        kvm)
            _c_c_s_msg info "Kvm VM detected."
            if [ -n "$(lspci -vnn | grep -iw "qemu virtual machine")" ] ; then
                $FUNCNAME qemu
            else
                 _virt_remove $pkgs_remove_from_vm
                _install_needed_packages $pkgs_qemu $pkgs_vbox $pkgs_common   # ???
                _sway_in_vm_settings
            fi
            ;;
        *)
            _c_c_s_msg info "VM not detected."
            _virt_remove $pkgs_vbox $pkgs_qemu $pkgs_vmware $pkgs_common
            ;;
    esac
}

_sed_stuff(){

    # Journal for offline. Turn volatile (for iso) into a real system.
    sed -i 's/volatile/auto/g' /etc/systemd/journald.conf 2>>/tmp/.errlog
    sed -i 's/.*pam_wheel\.so/#&/' /etc/pam.d/su
}

_clean_archiso(){

    local _files_to_remove=(
        /etc/sudoers.d/g_wheel
        /var/lib/NetworkManager/NetworkManager.state
        /etc/systemd/system/getty@tty1.service.d/autologin.conf
        /etc/systemd/system/getty@tty1.service.d
        /etc/systemd/system/multi-user.target.wants/*
        /etc/systemd/journald.conf.d
        /etc/systemd/logind.conf.d
        /etc/mkinitcpio-archiso.conf
        /etc/initcpio
        /root/{,.[!.],..?}*
        /etc/motd
        /{gpg.conf,gpg-agent.conf,pubring.gpg,secring.gpg}
        /version
    )

    local xx

    for xx in ${_files_to_remove[*]}; do rm -rf $xx; done

    find /usr/lib/initcpio -name archiso* -type f -exec rm '{}' \;

}

_clean_offline_packages(){

    local packages_to_remove=(

        # BASE

        ## Base system
        edk2-shell

        # SOFTWARE

        # ISO

        ## Live iso specific
        arch-install-scripts
        memtest86+
        mkinitcpio
        mkinitcpio-archiso
        mkinitcpio-busybox
        pv
        syslinux

        ## Live iso tools
        clonezilla
        gpart
	gparted
        grsync
        hdparm
        partitionmanager

        # ENDEAVOUROS REPO

        ## General
        rate-mirrors

        ## Calamares EndeavourOS
        $(pacman -Qq | grep calamares)        # finds calamares related packages
        ckbcomp

    )

    pacman -Rsn --noconfirm "${packages_to_remove[@]}"

}

_is_offline_mode() {
    if [ "$INSTALL_TYPE" = "online" ] ; then
        return 1           # online install mode
    else
        return 0           # offline install mode
    fi
}
_is_online_mode() { ! _is_offline_mode ; }


_check_install_mode(){

    if _is_online_mode ; then
        local INSTALL_OPTION="ONLINE_MODE"
    else
        local INSTALL_OPTION="OFFLINE_MODE"
    fi

    case "$INSTALL_OPTION" in
        OFFLINE_MODE)
                _clean_archiso
                chown $NEW_USER:$NEW_USER /home/$NEW_USER/.bashrc
                _sed_stuff
                _clean_offline_packages
            ;;

        ONLINE_MODE)
                # not implemented yet. For now run functions at "SCRIPT STARTS HERE"
                :
                # all systemd are enabled - can be specific offline/online in the future
            ;;
        *)
            ;;
    esac
}

_remove_ucode(){
    local ucode="$1"
    _remove_a_pkg "$ucode"
}

_manage_other_graphics_drivers() {
    local graphics="$(device-info --graphics)"
    local amd=no

    # remove AMD graphics driver if it is not needed
    if [ -n "$(echo "$graphics" | grep "Advanced Micro Devices")" ] ; then
        amd=yes
    elif [ -n "$(echo "$graphics" | grep "AMD/ATI")" ] ; then
        amd=yes
    elif [ -n "$(echo "$graphics" | grep "Radeon")" ] ; then
        amd=yes
    fi
    case "$amd" in
        no)
            _remove_a_pkg xf86-video-amdgpu
            _remove_a_pkg xf86-video-ati
            ;;
        yes)
            # _install_needed_packages vulkan-radeon   # vulkan is beyond scope here...
            ;;
    esac
}

_remove_broadcom_wifi_driver_old() {
    local pkgname=broadcom-wl-dkms
    local wifi_pci
    local wifi_driver

    # _is_pkg_installed $pkgname && {
        wifi_pci="$(lspci -k | grep -A4 " Network controller: ")"
        if [ -n "$(lsusb | grep " Broadcom ")" ] || [ -n "$(echo "$wifi_pci" | grep " Broadcom ")" ] ; then
            return
        fi
        wifi_driver="$(echo "$wifi_pci" | grep "Kernel driver in use")"
        if [ -n "$(echo "$wifi_driver" | grep "in use: wl$")" ] ; then
            return
        fi
        _remove_a_pkg $pkgname
    # }
}

_remove_broadcom_wifi_driver() {
    local pkgname=broadcom-wl-dkms
    local file=/tmp/$pkgname.txt
    if [ "$(cat $file 2>/dev/null)" = "no" ] ; then
        _remove_a_pkg $pkgname
    fi
}

_install_extra_drivers_to_target() {
    # Install special drivers to target if needed.
    # The drivers exist on the ISO and were copied to the target.

    local dir=/opt/extra-drivers
    local pkg

    # Handle the r8168 package.
    if [ -r /tmp/r8168_in_use ] ; then
        # We must install r8168 now.
        if _is_offline_mode ; then
            # Install using the copied r8168 package.
            pkg="$(/usr/bin/ls -1 $dir/r8168-*-x86_64.pkg.tar.zst)"
            if [ -n "$pkg" ] ; then
                _pkg_msg install "r8168 (offline)"
                pacman -U --noconfirm $pkg
            else
                _c_c_s_msg error "no r8168 package in folder $dir!"
            fi
        else
            # Install r8168 package from the mirrors.
            _install_needed_packages r8168
	    # Handle the r8168-lts package if LTS is installed.
            [[ $(pacman -Q linux-lts  2</dev/null) ]] &&  _install_needed_packages r8168-lts
        fi
    fi
}

_install_more_firmware() {
    # Install possibly missing firmware packages based on detected hardware

    if [ -n "$(lspci -k | grep "Kernel driver in use: mwifiex_pcie")" ] ; then    # e.g. Microsoft Surface Pro
        _install_needed_packages linux-firmware-marvell
    fi
}

_nvidia_remove() {
    _pkg_msg remove "$*"
    pacman -Rsc --noconfirm "$@"
}

_remove_nvidia_drivers() {
    local remove="pacman -Rsc --noconfirm"

    if _is_offline_mode ; then
        # delete packages separately to avoid all failing if one fails
        [ -r /usr/share/licenses/nvidia/LICENSE ]      && _nvidia_remove nvidia
        [ -x /usr/bin/nvidia-modprobe ]                     && _nvidia_remove nvidia-utils
        [ -x /usr/bin/nvidia-settings ]                     && _nvidia_remove nvidia-settings
        [ -x /usr/bin/nvidia-inst ]                         && _nvidia_remove nvidia-inst
        [ -r /usr/share/libalpm/hooks/eos-nvidia-fix.hook ] && _nvidia_remove nvidia-hook
        true
    fi
}

_manage_nvidia_packages() {
    local file=/tmp/nvidia-info.bash        # nvidia info from livesession
    local nvidia_card=""                    # these two variables are defined in $file
    local nvidia_driver=""

    _remove_nvidia_drivers
}

_run_if_exists_or_complain() {
    local app="$1"

    if (which "$app" >& /dev/null) ; then
        _c_c_s_msg info "running $*"
        "$@"
    else
        _c_c_s_msg warning "program $app not found."
    fi
}

#_RunUserCommands() {
#    local usercmdfile=/tmp/user_commands.bash
#    if [ -r $usercmdfile ] ; then
#        _c_c_s_msg info "running script ${usercmdfile##*/}"
#        # ad hoc validity check
#        case "$NEW_USER" in
#            -* | offline | online | community) _c_c_s_msg warning "${usercmdfile##*/} called with parameter '$NEW_USER'" ;;
#        esac
#        bash $usercmdfile $NEW_USER
#    fi
#}

_misc_cleanups() {
    # /etc/resolv.conf.pacnew may be unnecessary, so delete it

    local file=/etc/resolv.conf.pacnew
    if [ -z "$(grep -Pv "^[ ]*#" $file 2>/dev/null)" ] ; then
        _c_c_s_msg info "removing file $file"
        rm -f $file                                            # pacnew contains only comments
    fi
}

_clean_up(){
    local xx

    # install or remove nvidia graphics stuff
    _manage_nvidia_packages

    # install or remove AMD and Intel graphics stuff if needed
    _manage_other_graphics_drivers

    # remove broadcom-wl-dkms if it is not needed

    _install_extra_drivers_to_target
    _install_more_firmware

    _misc_cleanups

    # on the target, select file server based on country
    xx=/usr/bin/eos-select-file-server
    if [ -x $xx ] ; then
        _c_c_s_msg info "running $xx"
        local fileserver="$($xx)"
        if [ "$fileserver" != "gitlab" ] ; then
            _c_c_s_msg info "file server configured to '$fileserver'"
        fi
    else
        _c_c_s_msg warning "program $xx was not found"
    fi

    # change log file permissions
    [ -r /var/log/Calamares.log ]         && chown root:root /var/log/Calamares.log

    # run possible user-given commands
    # _RunUserCommands     # this is in calamares directly now
}

_show_info_about_installed_system() {
    local cmd
    local cmds=( "lsblk -f -o+SIZE"
                 "fdisk -l"
               )

    for cmd in "${cmds[@]}" ; do
        _c_c_s_msg info "$cmd"
        $cmd
    done
}

_run_hotfix_end() {
    local file=hotfix-end.bash
    local type=""
    if ! _check_internet_connection ; then
        _is_offline_mode && type=info || type=warning
        _c_c_s_msg $type "cannot fetch $file, no connection."
        return
    fi
    local url=$(eos-github2gitlab https://raw.githubusercontent.com/endeavouros-team/ISO-hotfixes/main/$file)
    wget --timeout=60 -q -O /tmp/$file $url && {
        _c_c_s_msg info "running script $file"
        bash /tmp/$file
    }
}

Main() {
    local filename=chrooted_cleaner_script.sh

    local _CHROOTED_HAS_CONNECTION=""

    _c_c_s_msg info "$filename started, parameters: $*"

    local i
    local NEW_USER="" INSTALL_TYPE="" BOOTLOADER=""

    # parse the options
    for i in "$@"; do
        case $i in
            --user=*)
                NEW_USER="${i#*=}"
                shift
                ;;
            --online)
                INSTALL_TYPE="online"
                shift
                ;;
            --bootloader=*)
                BOOTLOADER="${i#*=}"
                ;;
        esac
    done
    if [ -z "$NEW_USER" ] ; then
        _c_c_s_msg error "new username is unknown!"
    fi

    _check_install_mode
    _virtual_machines
    _clean_up
    _run_hotfix_end
    _show_info_about_installed_system

    # Remove pacnew files
    find /etc -type f -name "*.pacnew" -exec rm {} \;

    rm -rf /etc/calamares /opt/extra-drivers

    # Remove device-info & eos-connection-checker if they aren't installed
    [[ $(pacman -Q eos-bash-shared  2</dev/null) ]] || rm /bin/device-info /bin/eos-connection-checker

    _c_c_s_msg info "$filename done."
}


########################################
########## SCRIPT STARTS HERE ##########
########################################

Main "$@"
