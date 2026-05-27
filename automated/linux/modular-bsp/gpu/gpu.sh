#!/bin/bash
#
# gpu.sh
#
# Advantech BSP QA – GPU checks
# Ported from test_gpu() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${GPU_COUNT:=1}"
: "${GPU_WAYLAND:=}"
: "${GPU_VA_CODECS:=}"

# ─── GL/GLES/EGL library checks ──────────────────────────────────────────────

for lib in GL; do
    if ldconfig -p 2>/dev/null | grep -q "lib${lib}.so"; then
        report_pass "L-GPU-OPENGL-F"
    else
        report_fail "L-GPU-OPENGL-F"
    fi
done

for lib in EGL GLESv2; do
    if ldconfig -p 2>/dev/null | grep -q "lib${lib}.so"; then
        report_pass "L-GPU-OPENGL-ES-F"
    else
        report_fail "L-GPU-OPENGL-ES-F"
    fi
done

# ─── Wayland compositor ───────────────────────────────────────────────────────

if [ -n "${GPU_WAYLAND}" ]; then
    wayland_ok=0
    case "${GPU_WAYLAND,,}" in
    weston)
        systemctl status weston >/dev/null 2>&1 && wayland_ok=1
        ;;
    mutter)
        pgrep -f mutter >/dev/null 2>&1 && wayland_ok=1
        ;;
    esac
    if [ "${wayland_ok}" -eq 1 ]; then
        report_pass "L-GPU-WAYLAND"
    else
        report_fail "L-GPU-WAYLAND"
    fi
fi

# ─── glmark2 validation ───────────────────────────────────────────────────────

declare -A glm2_cmds
if [ -n "${GPU_WAYLAND}" ]; then
    glm2_cmds[gl]="glmark2-wayland"
    glm2_cmds[gl_es]="glmark2-es2-wayland"
else
    glm2_cmds[gl]="glmark2"
    glm2_cmds[gl_es]="glmark2-es2"
fi

declare -A gl2rid
gl2rid[gl]="L-GPU-OPENGL-F"
gl2rid[gl_es]="L-GPU-OPENGL-ES-F"
gl2rid[gl_es_wayland]="L-GPU-OPENGL-ES-F"
gl2rid[gl_wayland]="L-GPU-OPENGL-F"

for key in gl gl_es; do
    cmd="${glm2_cmds[${key}]}"
    rid="${gl2rid[${key}]}"
    if chk_cmd "${cmd}"; then
        if bash -l -c "${cmd} --validate" > "${OUTPUT}/glmark2_${key}.log" 2>&1; then
            report_pass "${rid}"
        else
            report_fail "${rid}"
        fi
    else
        report_skip "${rid}"
    fi
done

# ─── Vulkan ───────────────────────────────────────────────────────────────────

if chk_cmd vulkaninfo; then
    d=$(vulkaninfo 2>/dev/null | grep "GPU id" | head -1 | xargs)
    if [ -n "${d}" ]; then
        report_pass "L-GPU-VULKAN-DEV"
    else
        report_fail "L-GPU-VULKAN-DEV"
    fi
else
    report_skip "L-GPU-VULKAN-DEV"
fi

# ─── VA-API ───────────────────────────────────────────────────────────────────

if chk_cmd ffmpeg; then
    if ffmpeg -hwaccels 2>/dev/null | grep -q "^vaapi"; then
        report_pass "L-GPU-VA-HW-FFMPEG"
    else
        report_fail "L-GPU-VA-HW-FFMPEG"
    fi
else
    report_skip "L-GPU-VA-HW-FFMPEG"
fi

if [ -n "${GPU_VA_CODECS}" ] && chk_cmd vainfo; then
    for codec_entry in ${GPU_VA_CODECS}; do
        codec=$(echo "${codec_entry}" | awk -F: '{print $1}')
        entry=$(echo "${codec_entry}" | awk -F: '{print $2}')
        te=$(vainfo 2>/dev/null | grep -w "${codec}" | grep -w "${entry}" | xargs)
        if [ -n "${te}" ]; then
            report_pass "L-GPU-VA-HW-CODECS"
        else
            report_fail "L-GPU-VA-HW-CODECS"
        fi
    done
fi

# ─── Per-connector / display checks ──────────────────────────────────────────

n=0
while [ "${n}" -lt "${GPU_COUNT}" ]; do
    eval "dri_dev=\${GPU${n}_DRI_KMS_DEV}"
    eval "bl_dev=\${GPU${n}_BACKLIGHT_DEV}"
    eval "lvds_mod=\${GPU${n}_LVDS_MOD}"
    eval "lvds_dev=\${GPU${n}_LVDS_DEV}"
    eval "drm_conn=\${GPU${n}_DRM_CONNECTOR}"
    eval "drm_enc=\${GPU${n}_DRM_CONNECTOR_ENCODER}"
    eval "resolution=\${GPU${n}_RESOLUTION}"
    eval "refresh=\${GPU${n}_REFRESH_RATE}"

    # DRI/KMS device node
    if [ -n "${dri_dev}" ]; then
        if chk_rw_cdev "${dri_dev}"; then
            report_pass "L-GPU-DRI-KMS-DEV-gpu${n}"
        else
            report_fail "L-GPU-DRI-KMS-DEV-gpu${n}"
        fi
    fi

    # LVDS kernel module
    if [ -n "${lvds_mod}" ]; then
        if lsmod 2>/dev/null | grep -q "${lvds_mod}"; then
            report_pass "L-GPU-DRM-LVDS-MODULE-gpu${n}"
        else
            report_fail "L-GPU-DRM-LVDS-MODULE-gpu${n}"
        fi
    fi

    # LVDS device sysfs
    if [ -n "${lvds_dev}" ]; then
        if [ -e "${lvds_dev}/device" ]; then
            report_pass "L-GPU-DRM-LVDS-DEV-gpu${n}"
        else
            report_fail "L-GPU-DRM-LVDS-DEV-gpu${n}"
        fi
        e=$(cat "${lvds_dev}/enabled" 2>/dev/null)
        if [ "${e}" = "enabled" ]; then
            report_pass "L-GPU-DRM-LVDS-ENABLED-gpu${n}"
        else
            report_fail "L-GPU-DRM-LVDS-ENABLED-gpu${n}"
        fi
    fi

    # DRM connector (modetest)
    if [ -n "${drm_conn}" ] && chk_cmd modetest; then
        con_id=$(modetest -c 2>/dev/null | grep "${drm_conn}" | awk '{print $1}' | head -1)
        if [ "$((con_id + 0))" -gt 0 ] 2>/dev/null; then
            report_pass "L-GPU-DRM-CONNECTOR-gpu${n}"
        else
            report_fail "L-GPU-DRM-CONNECTOR-gpu${n}"
        fi

        if [ -n "${drm_enc}" ]; then
            if modetest -e 2>/dev/null | awk '{print $3}' | grep -q "${drm_enc}"; then
                report_pass "L-GPU-DRM-CONNECTOR-ENCODER-gpu${n}"
            else
                report_fail "L-GPU-DRM-CONNECTOR-ENCODER-gpu${n}"
            fi
        fi
    fi

    # Display resolution (hwinfo)
    if [ -n "${resolution}" ] && chk_cmd hwinfo; then
        wht=$(hwinfo --monitor 2>/dev/null |
              sed -n '/Detailed Timings #0/,/Frequencies/p' |
              grep -E 'Resolution' | awk '{print $NF}')
        if [ "${resolution}" = "${wht}" ]; then
            report_pass "L-GPU-DRM-CONNECTOR-RESOLUTION-gpu${n}"
        else
            report_fail "L-GPU-DRM-CONNECTOR-RESOLUTION-gpu${n}"
        fi
    fi

    # Refresh rate (hwinfo)
    if [ -n "${refresh}" ] && chk_cmd hwinfo; then
        ft=$(hwinfo --monitor 2>/dev/null |
             sed -n '/Detailed Timings #0/,/Frequencies/p' |
             grep -E 'Frequencies' | awk -F, '{print $NF}' |
             awk -F. '{print $1}' | xargs)
        if [ "${refresh}" = "${ft}" ]; then
            report_pass "L-GPU-DRM-CONNECTOR-REFRESH-RATE-gpu${n}"
        else
            report_fail "L-GPU-DRM-CONNECTOR-REFRESH-RATE-gpu${n}"
        fi
    fi

    # Backlight device
    if [ -n "${bl_dev}" ]; then
        if [ -e "${bl_dev}/device" ]; then
            report_pass "L-GPU-BACKLIGHT-DEV-gpu${n}"
        else
            report_fail "L-GPU-BACKLIGHT-DEV-gpu${n}"
            n=$((n + 1))
            continue
        fi

        b0=$(cat "${bl_dev}/brightness"     2>/dev/null)
        mb=$(cat "${bl_dev}/max_brightness" 2>/dev/null)
        b=$((b0 + 0))
        mb=$((mb + 0))

        if [ "${mb}" -gt 0 ] && [ -n "${b0}" ] && \
           [ "${b}" -ge 0 ] && [ "${b}" -le "${mb}" ]; then
            report_pass "L-GPU-BACKLIGHT-F-gpu${n}"

            # Sweep brightness 0 → max → restore
            for val in 0 $((mb / 3)) $((2 * (mb / 3))) "${mb}"; do
                echo "${val}" > "${bl_dev}/brightness" 2>/dev/null
                sleep 1
            done
            echo "${b}" > "${bl_dev}/brightness" 2>/dev/null
            b2=$(cat "${bl_dev}/brightness" 2>/dev/null)
            if [ "${b}" = "${b2}" ]; then
                report_pass "L-GPU-BACKLIGHT-RESTORE-F-gpu${n}"
            else
                report_fail "L-GPU-BACKLIGHT-RESTORE-F-gpu${n}"
            fi
        else
            report_fail "L-GPU-BACKLIGHT-F-gpu${n}"
        fi
    fi

    n=$((n + 1))
done
