#!/system/bin/sh

dir_res="/data/local/tmp"
f_proc_mem="${dir_res}/proc-meminfo.txt"
f_dumpsys_mem="${dir_res}/dumpsys-meminfo.txt"

get_proc_meminfo(){
    cat /proc/meminfo>${f_proc_mem}

    while read line; do
        line=$(echo ${line}|tr ': ' ','|tr -s ',')
        unit=$(echo $line|cut -d, -f3)
        if [ -n "${unit}" ]; then
            echo "${line},pass"
        else
            echo ${line}
        fi
    done < ${f_proc_mem}
}

get_dumpsys_meminfo(){
    dumpsys meminfo >${f_dumpsys_mem}
    while read line; do
        #Total RAM: 914468 kB (status normal)
        if echo "${line}"|grep -q "Total RAM:"; then
            local total_size=$(echo "${line}"|tr -d ':'|tr -s ' '|tr ' ' ','|cut -d, -f3)
            local total_unit=$(echo "${line}"|tr -d ':'|tr -s ' '|tr ' ' ','|cut -d, -f4)
            echo "dumpsys_total_ram,${total_size},${total_unit},pass"
        fi
        # Free RAM: 481904 kB (76380 cached pss + 313040 cached kernel + 92484 free)
        #,Free,RAM,481904,kB,76380,cached,pss,313040,cached,kernel,92484,free
        if echo "${line}"|grep -q "Free RAM:"; then
            local unit=$(echo "${line}"|tr -d ':+()'|tr -s ' '|tr ' ' ','|cut -d, -f4)
            local free_total_size=$(echo "${line}"|tr -d ':+()'|tr -s ' '|tr ' ' ','|cut -d, -f3)
            local free_cached_pss_size=$(echo "${line}"|tr -d ':+()'|tr -s ' '|tr ' ' ','|cut -d, -f5)
            local free_cached_kernel_size=$(echo "${line}"|tr -d ':+()'|tr -s ' '|tr ' ' ','|cut -d, -f8)
            local free_free_size=$(echo "${line}"|tr -d ':+()'|tr -s ' '|tr ' ' ','|cut -d, -f11)
            echo "dumpsys_free_total_ram,${free_total_size},${unit},pass"
            echo "dumpsys_free_cached_pss_ram,${free_cached_pss_size},${unit},pass"
            echo "dumpsys_free_cached_kernel_ram,${free_cached_kernel_size},${unit},pass"
            echo "dumpsys_free_free_ram,${free_free_size},${unit},pass"
        fi
        # Used RAM: 368777 kB (313469 used pss + 55308 kernel)
        if echo "${line}"|grep -q "Used RAM:"; then
            local unit=$(echo "${line}"|tr -d ':+()'|tr -s ' '|tr ' ' ','|cut -d, -f4)
            local used_total_size=$(echo "${line}"|tr -d ':+()'|tr -s ' '|tr ' ' ','|cut -d, -f3)
            local used_pss_size=$(echo "${line}"|tr -d ':+()'|tr -s ' '|tr ' ' ','|cut -d, -f5)
            local used_kernel_size=$(echo "${line}"|tr -d ':+()'|tr -s ' '|tr ' ' ','|cut -d, -f8)
            echo "dumpsys_used_total_ram,${used_total_size},${unit},pass"
            echo "dumpsys_used_pss_ram,${used_pss_size},${unit},pass"
            echo "dumpsys_used_kernel_ram,${used_kernel_size},${unit},pass"
        fi
        # Lost RAM: 63787 kB
        if echo "${line}"|grep -q "Lost RAM:"; then
            local lost_size=$(echo "${line}"|tr -d ':'|tr -s ' '|tr ' ' ','|cut -d, -f3)
            local lost_unit=$(echo "${line}"|tr -d ':'|tr -s ' '|tr ' ' ','|cut -d, -f4)
            echo "dumpsys_lost_ram,${lost_size},${lost_unit},pass"
        fi
    done < ${f_dumpsys_mem}
}

main(){
    get_proc_meminfo
    get_dumpsys_meminfo
}

main "$@"
