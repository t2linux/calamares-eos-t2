#!/usr/bin/env python3

import subprocess

import libcalamares
from libcalamares.utils import gettext_path, gettext_languages

import gettext

_translation = gettext.translation("calamares-python",
                                   localedir=gettext_path(),
                                   languages=gettext_languages(),
                                   fallback=True)
_ = _translation.gettext
_n = _translation.ngettext

custom_status_message = None
name = "Hardware detection"
user_output = False


def pretty_name():
    return _(name)


def pretty_status_message():
    if custom_status_message is not None:
        return custom_status_message


def clean_key(key):
    """
    Strips the positional info json key
    :param key: The original data from the inxi json
    :return: The key without the position information
    """
    return re.sub("^[0-9]*#[0-9]*#[0-9]*#", "", key)


def run():
    cpu_model = ""
    cpu_vendor = ""
    gpu_drivers = []
    try:
        with open("/proc/cpuinfo", "r") as cpu_file:
            for line in cpu_file:
                if line.strip().startswith("vendor_id"):
                    cpu_vendor = line.split(":")[1].strip()
                if line.strip().startswith("model name"):
                    cpu_model = line.split(":")[1].strip()
    except KeyError:
        return "Failed to get CPU info"

    try:
        lspci_output = subprocess.run("LANG=C lspci -k | grep -EA3 'VGA|3D|Display'",
                                      capture_output=True, shell=True, text=True)

        for line in lspci_output.stdout.split("\n"):
            if line.strip().startswith("Kernel driver in use:"):
                gpu_drivers.append(line.split(":")[1].strip())
    except subprocess.CalledProcessError as cpe:
        libcalamares.utils.warning(f"Failed to get GPU drivers with error: {gpu_drivers}")
        return "Failed to get GPU drivers"
    except KeyError:
        return "Failed to parse GPU driver string"

    if cpu_model and gpu_drivers and cpu_vendor:
        libcalamares.globalstorage.insert("cpuModel", cpu_model)
        libcalamares.globalstorage.insert("cpuVendor", cpu_vendor)
        libcalamares.globalstorage.insert("gpuDrivers", gpu_drivers)
    else:
        return "Failed to locate CPU and GPU driver information"

    return None
