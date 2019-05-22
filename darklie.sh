#!/usr/bin/env bash

# This script was written to display the weather conditions on the command line using the darksky.net api


# strict mode
set -Eeuo pipefail
IFS=$'\n\t'

# debug mode
#set -o verbose

# define global variables

# script name
readonly script_name=$( echo ${0##*/} | sed 's/\.sh*$//' )

# geographic coordinates
readonly coordinates="41.85003,-87.65005"

# api host
readonly api_host="api.darksky.net"

# api protocol
readonly api_protocol="https"

# api auth token file
readonly auth_token_file=${script_name}".token"

# api auth token (get your own here --> https://darksky.net/dev/register)
readonly auth_token=`cat ~/bin/${auth_token_file}`

# api uri
readonly api_uri=${api_protocol}"://"${api_host}"/forecast/"${auth_token}"/"${coordinates}

# tool name
readonly tool_name="Weather"

# get logname
readonly logname=$( logname )


# function to catch error messages
# ${1} = error message
# ${2} = exit code
function __throw_error() {

    # validate arguments
    if [ ${#} -eq 2 ]; then
        local message=${1}
        local exit_code=${2}

        # log specific error message to syslog and write to STDERR
        logger -s -p user.err -t ${script_name}"["${logname}"]" -- ${message}

        exit ${exit_code}

    else

        # log generic error message to syslog and write to STDERR
        logger -s -p user.err -t ${tool_name}"["${logname}"]" -- "an unknown error occured"

        exit 255

    fi

}


# validate api connectivity
# ${1} = api host
# ${2} = api protocol
function __validate_api_connectivity() {
    if [ ${#} -eq 2 ]; then
        # test tcp connectivity on specified host and port
        ( >/dev/tcp/${1}/${2} ) >/dev/null 2>&1
        return ${?}

    else
        return 1

    fi
    
}


function __get_summary() {
    # query api for current summary
    local current_summary=$( curl -s "${api_uri}" | jq -r '.currently.summary' )

    echo ${current_summary}

}


function __get_temperature() {
    # query api for current temperature
    local current_temperature=$( curl -s "${api_uri}" | jq -r '.currently.temperature' | awk '{print int($1+0.5)}' )

    echo ${current_temperature}

}


# check for dependancies
# ${1} = dependancy
function __check_dependancy() {
    if [ ${#} -eq 1 ]; then
        local dependancy=${1}
        local exit_code=${null:-}

        type ${dependancy} &>/dev/null; exit_code=${?}
        
        if [ ${exit_code} -ne 0 ]; then
            return 255

        fi

    else
        return 1
        
    fi
    
}


####################
### main program ###
####################

# validate dependancies
readonly -a dependancies=( 'awk' 'jq' 'logger' )
declare -i dependancy=0

while [ "${dependancy}" -lt "${#dependancies[@]}" ]; do
    __check_dependancy ${dependancies[${dependancy}]} || __throw_error ${dependancy}" required" ${?}

    (( ++dependancy ))

done

unset dependancy

# make sure we're using least bash 4 for proper support of associative arrays
[ $( echo ${BASH_VERSION} | grep -o '^[0-9]' ) -ge 4 ] || __throw_error "Please upgrade to at least bash version 4" ${?}

# make sure we have an api token
[ -s ${auth_token} ] && __throw_error "Token file not found" ${?}

# make sure we can reach the api
__validate_api_connectivity ${api_host} ${api_protocol} || __throw_error "Unable to establish tcp connection to "${api_host} ${?}

# get the current temperature
current_temperature=$( __get_temperature ) || __throw_error "Unable to get temperature" ${?}

# get the current temperature
current_summary=$( __get_summary ) || __throw_error "Unable to get summary" ${?}

echo ${current_temperature}"° "${current_summary}