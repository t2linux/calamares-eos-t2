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


def pretty_name():
    return _(name)


def pretty_status_message():
    if custom_status_message is not None:
        return custom_status_message


def run():
    cpu_model = "unknown"
    cpu_vendor = "unknown"
    try:
        with open("/proc/cpuinfo", "r") as cpu_file:
            for line in cpu_file:
                if line.strip().startswith("vendor_id"):
                    cpu_vendor = line.split(":")[1].strip()
                if line.strip().startswith("model name"):
                    cpu_model = line.split(":")[1].strip()
    except KeyError:
        libcalamares.utils.warning("Failed to get CPU drivers")

    libcalamares.globalstorage.insert("cpuModel", cpu_model)
    libcalamares.globalstorage.insert("cpuVendor", cpu_vendor)

    return None
