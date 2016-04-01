#! /bin/bash
#
# LTP-DDT Test wrapper
#
# Copyright (C) 2015, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
#

usage() 
{
    cat <<-EOF >&2

    usage: ./${0##*/} [-p LTP_PATH] [-f CMD_FILES(,...)] [-s PATTERNS(,...)]
    -f CMDFILES     Execute user defined list of testcases (separate with ',')
    -h              Help. Prints all available options.
    -p LTP_PATH     Default path for ltp-ddt. Default path is /opt/ltp
    -P PLATFORM     Platform to run tests on. Used to filter device driver tests (ddt)
    -s PATTERNS      Only run test cases which match PATTERNS. Patterns seperated by ','

    example: ./${0##*/} -p /home/test/ltp -f ddt/memtest -s IN_ALL_BANK,OUT_ALL_BANK

EOF
exit 0
}

main()
{
    # Absolute path to this script. /home/user/bin/foo.sh
    SCRIPT=$(readlink -f $0)
    # Absolute path this script is in. /home/user/bin
    SCRIPTPATH=`dirname $SCRIPT`
    echo "Script path is: $SCRIPTPATH"

    CMD_FILES=""
    PATTERNS=""
    PATTERNS_OPTION=""
    PLATFORM=""
    #default path for ltp-ddt
    LTP_PATH="/opt/ltp"
    LOG_FILE="default"

    while getopts p:f:s:P:h arg
    do
        case $arg in
            p) LTP_PATH="$OPTARG";;
            P) PLATFORM="-P $OPTARG";;
            f)
               CMD_FILES="$OPTARG"
               LOG_FILE=`echo $OPTARG| sed 's,\/,_,'`;;
            s) PATTERNS="-s $OPTARG";;
            h) usage;;
        esac
        echo $arg
    done
    if [ -z "$CMD_FILES" ]; then
        echo "WARNING: Will run all ltp-ddt testcases or all those that match PATTERNS"
    fi

    if [ -n "$PATTERNS" ]; then
        PATTERNS_OPTION="-s $PATTERNS"
    fi

    ## Second parameter is used as a path to LTP installation
    cd $LTP_PATH
    ./runltp -p -q -f ${CMD_FILES} $PLATFORM $PATTERNS -l $SCRIPTPATH/LTP_${LOG_FILE}.log     \
    -C $SCRIPTPATH/LTP_${LOG_FILE}.failed | tee $SCRIPTPATH/LTP_${LOG_FILE}.out
    tar -czvf $SCRIPTPATH/LTP_${LOG_FILE}.tar.gz $SCRIPTPATH/LTP*
    lava-test-case-attach LTP_$1 $SCRIPTPATH/LTP_${LOG_FILE}.tar.gz
    exit 0
}
main "$@"
