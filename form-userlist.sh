#!/bin/bash

# Copyright 2014 Quimoniz
# License
#     This file is part of HEC
#
#     HEC is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, version 3.
#
#     HEC is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with HEC. If not, see <http://www.gnu.org/licenses/gpl-3.0.html>




#cached links
loaded_cache="FALSE";
cache_updated="FALSE";
declare -A caur; 
cache_path="";
use_cache="FALSE";
current_time="$(date +%s)";
cache_noupdate_age="$(dc -e "5 60 *p")"
cache_update_age="$(dc -e "86400 14 *p")"
cache_discard_age="$(dc -e "86400 60 *p")"
gloret="";

function read_cache {
    if test -f "${cache_path}"; then
        local ele_nam;
        local ele_val;
        while read ele_nam ele_val; do
            caur["${ele_nam}"]="${ele_val}";
        done < "${cache_path}";
    fi;

    loaded_cache="TRUE";
}

function write_cache {
    if test -f "${cache_path}"; then
        local tmp_file="$(mktemp)";
        #run through cache/array and write it to file
        for csu in ${!caur[*]}; do
            echo "$csu ${caur[$csu]}" >> "${tmp_file}";
        done;
        cp "$tmp_file" "${cache_path}";
    fi;
}

#checks if the response from a given url is within the range of OK
function update_url {
#DEBUG
#xmessage "performing lookup on \"$1\"";
    local interesting_lines;
    local last_url="$1";
    local last_status=0;
    local tmp_log="$(mktemp)";
    local str_location="Location: ";
    local str_awaiting="HTTP request sent, awaiting response... ";
    if grep -qi "de_" <<< "$LANG" || grep -qi "de_" <<< "$LANGUAGE"; then
       str_location="Platz: ";
       str_awaiting="HTTP-Anforderung gesendet, warte auf Antwort... ";
    fi;
    wget --verbose --dns-timeout=5 --connect-timeout=5 --read-timeout=2 --tries=3 -O /dev/null "${last_url}" 2> "$tmp_log";
    interesting_lines="$(grep "^\\(${str_location}\\|${str_awaiting}[0-9]\\+\\)" "$tmp_log")";
    saved_ifs="$IFS";
    IFS=$'\n';
    for current_line in $interesting_lines; do
        if [ $(echo "$current_line" | grep -c "^${str_location}[^ ]\\+") -gt 0 ]; then
            last_url="$(echo "$current_line" | sed "s/^${str_location}\\([^ ]\\+\\) .*/\\1/")";
        elif [ $(echo "$current_line" | grep -c "^${str_awaiting}[0-9]\\+") -gt 0 ]; then
            last_status="$(echo "$current_line" | sed "s/^${str_awaiting}\\([0-9]\\+\\).*/\\1/")";
        fi;
    done;
    IFS="$saved_ifs";
    if [ $last_status -gt 199 ] && [ $last_status -lt 300 ]; then
        echo "${last_url}";
    fi;
}

function greater_than {
    dc -e "[FALSE][[TRUE]]Sa$2 $1>ap";
}
function lesser_than {
    dc -e "[FALSE][[TRUE]]Sa$2 $1<ap";
}

#wraps update_url with a cache mechanism
function check_url {
    gloret="";
    local src_url="$1";
    local dst_url="";
    if test "TRUE" = "${use_cache}"; then
        local cache_time="0";
        local cache_age="0"
        local cache_url="";
        if test "FALSE" = "${loaded_cache}"; then
            read_cache;
        fi;
        #consult cache
        if test -n "${caur[${src_url}]}"; then
            read cache_time cache_url <<< "${caur[${src_url}]}";

            cache_age="$(dc -e "${current_time} ${cache_time} - p")";
            if test "TRUE" = "$(lesser_than "${cache_noupdate_age}" "${cache_age}")"; then
                dst_url="${cache_url}";
            else
                if test "TRUE" = "$(greater_than "${cache_age}" "${cache_update_age}")"; then
                    dst_url="$(update_url "${src_url}")";
                    if test -n "${dst_url}"; then
                        caur["{$src_url}"]="${current_time} ${dst_url}";
                        cache_updated="TRUE";
                    elif test "TRUE" = "$(greater_than "${cache_age}" "${cache_discard_age}")"; then
                        unset caur["${src_url}"];
                    fi;
                else
                    dst_url="${cache_url}";
                fi;
            fi;
        else
            dst_url="$(update_url "${src_url}")";
            caur["${src_url}"]="${current_time} ${dst_url}";
            cache_updated="TRUE";
        fi;
    else 
        dst_url="$(update_url "${src_url}")";
    fi;
    if test -n "${dst_url}"; then
        gloret="${dst_url}";
    fi; 
}

function host_to_desc {
    local host_of_addr="";
    local host_desc="";

    host_of_addr="$(echo "$1" | sed "s/^[a-zA-Z0-9]\\+:\\/\\{0,2\\}//; s/\\(\\.[-_%a-zA-Z0-9]\\+\\)\\(:[0-9]\\+\\)\\?\\(\\/[^/#]*\\)*\\(#.*\\)\\?$/\\1/")";
    if $(echo "$host_of_addr" | grep -q "^#"); then
	host_of_addr="";
    else
	#strip leading "www."
	if $(echo "$host_of_addr" | grep -qi "^www\\."); then
	    host_of_addr="$(echo "$host_of_addr" | sed "s/^....//")";
            host_desc="${host_of_addr}";
        else
            host_desc="${host_of_addr}";
	fi;
	if true; then
            #have a list of dns addresses which are so well known, that the country level code ".de" or ".com" for example can be omitted
            known_webaddresses=("youtube\\.com" "flattr\\.com" "wiki.openstreetmap.org");
            alternate_names=("YouTube" "Flattr" "OpenStreetMap Wiki");
            entry_count=3;
            for i in $(seq 0 $((${entry_count} - 1))); do
                if grep -qi "${known_webaddresses[$i]}" <<< "$host_of_addr" ; then
		    host_desc="${alternate_names[$i]}";
		    break;
		fi;
            done;
	else
            #remove trailing .com .de .tk or .org
            #  only if second level domain name > 5 chars
	    if test $(echo -n "$host_of_addr" | grep -o "[-_a-zA-Z0-9]\\+\\.[-_a-zA-Z0-9]\\+$" | sed "s/^\\([-_a-zA-Z0-9]\\+\\)\\.[-_a-zA-Z0-9]\\+$/\\1/" | wc --chars) -gt 5; then
		host_desc="Auf $(echo "$host_of_addr" | sed "s/\\.\\([Cc][Oo][Mm]\\|[Dd][Ee]\\|[Tt][Kk]\\|[Oo][Rr][Gg]\\)$//")";
	    fi;
	fi;
	#make first letter uppercase
	if $(echo "$host_of_addr" | grep -q "\\."); then
	    false;
	else
	    host_of_addr="$(echo "$host_of_addr" | head --bytes=1 | tr "[:lower:]" "[:upper:]")$(echo "$host_of_addr" | tail --bytes=$(($(echo "$host_of_addr" | wc --bytes) - 1)))";
            host_desc="Auf ${host_of_addr}";
	fi;
    fi;
    echo "${host_desc}";
}

usernames="";

if test -n "$2"; then
    if grep -qi "^cache=" <<< "$1";
        then
        cache_path="$(sed -r "s/^.{6}//;" <<< "$1")";
        if test -f "${cache_path}"; then
            use_cache="TRUE";
        fi;
    fi;
    usernames="$2";
else
    usernames="$1";
fi;


#DEBUG
#xmessage "$(printf "\$cache_path:${cache_path}\\n\$usernames:${usernames}")";
#exit 0;


declare -a userlist;

saved_ifs="$IFS";
IFS=$'\n';
i=0;
#separate each entry into its own line, and process one after another
for cur_user in $(echo "$usernames" | grep -o $'[^<>)(,]*\\(\\(\\(([^<>)(,]*\\(<[^>]*>\\)\\?[^<>)(,]*)\\|<[^>]*>\\)[\t ]*\\(,\\|&\\|[uUaA][nN][dD]\\)\\?\\)\\|[\t ]*\\(,\\|&\\| [uUaA][nN][dD]\\)\\?\\)' | sort); do

    #strip delimiter part
    cur_user="$(echo "$cur_user" | sed "s/^\\([^<>)(,]*\\)\\(\\(\\(([^<>)(,]*\\(<[^>]*>\\)\\?[^<>)(,]*)\\|<[^>]*>\\)[\\t ]*\\(,\\|&\\|[uUaA][nN][dD]\\)\\?\\)\\|\\(\\(\\)\\)[\\t ]*\\(,\\|&\\| [uUaA][nN][dD]\\)\\?\\)$/\\1\\4/")";

    #strip leading whitespace
    cur_user="$(echo "$cur_user" | sed "s/^[ \\t]//")";

    #needs to contain at least one non-space character to be added
    if $(echo "$cur_user" | grep -q "[^ ]"); then
	userlist[$i]="$(echo "$cur_user" | sed "s/^[\\t\\n ]*//;")";
	let i++;
    fi;
done;
IFS="$saved_ifs";


realname="";
nickname="";
linkaddr="";
tmp_url="";
tmp_name="";
titletext="";
j=0;
#run through entries
for cur_user in "${userlist[@]}"; do
    realname="";
    nickname="";
    linkaddr="";
    tmp_url="";
    tmp_name="";
    titletext="";

    if $(echo "$cur_user" | grep -q "[^<>)(,]*([^<>)(,]*\\(<[^>]*>\\)\\?[^<>)(,]*)"); then
	#extract the three strings
	realname="$(echo "$cur_user" | sed "s/\\([^<>)(,]*\\)([^<>)(,]*\\(<[^>]*>\\)\\?[^<>)(,]*)/\\1/")";
	nickname="$(echo "$cur_user" | sed "s/[^<>)(,]*(\\([^<>)(,]*\\)\\(<[^>]*>\\)\\?[^<>)(,]*)/\\1/")";
	linkaddr="$(echo "$cur_user" | sed "s/[^<>)(,]*([^<>)(,]*\\(\\(<[^>]*>\\)\\?\\)[^<>)(,]*)/\\1/")";
    else
	#extract the two strings
	nickname="$(echo "$cur_user" | sed "s/\\([^<>)(,]*\\)\\(<[^>]*>\\)\\?/\\1/")";
	if $(echo "$cur_user" | grep -qi "[^<>)(,]*<@[^>]*>"); then
	    tmp_nick="$nickname";
	    nickname="$(echo "$cur_user" | sed "s/[^<>)(,]*\\(\\(<[^>]*>\\)\\?\\)/\\1/")";
	    nickname="$(echo "$nickname" | sed "s/^[\\t ]*<//; s/>[\\t ]*$//")";
	    if test "$(echo "$tmp_nick" | tr "[:upper:]" "[:lower:]" | sed "s/^[\\t ]*//; s/[\\t ]*$//")" != "$(echo "$nickname" | tr "[:upper:]" "[:lower:]" | sed "s/^@//; s/^[\\t ]*//; s/[\\t ]*$//")"; then
		realname="$tmp_nick";
	    fi;
	elif $(echo "$cur_user" | grep -qi "[^<>)(,]*<[a-zA-Z][-_a-zA-Z0-9]*:[^>]*>"); then
	    linkaddr="$(echo "$cur_user" | sed "s/[^<>)(,]*\\(\\(<[^>]*>\\)\\?\\)/\\1/")";

	fi;
#	echo "\$realname: $realname";
#	echo "\$nickname: $nickname";
#	echo "\$linkaddr: $linkaddr";
    fi;

    #strip leading and trailing whitespace/brokets
    realname="$(echo "$realname" | sed "s/^[\\t ]*//; s/[\\t ]*$//")";
    nickname="$(echo "$nickname" | sed "s/^[\\t ]*//; s/[\\t ]*$//")";
    linkaddr="$(echo "$linkaddr" | sed "s/^[\\t ]*<//; s/>[\\t ]*$//")";

    #skip empty entries
    if test "" = "$nickname" && test "" = "$realname" && test "" = "$linkaddr"; then
	continue;
    fi;

    #In case a nickname containing a space was given
    #  and the given link doesnt contain that name
    #  we will assume that it is actually the real name
    if test "$realname" = "" && $(echo "$nickname" | grep -q " "); then
	tmp_link="$(echo "$linkaddr" | tr "[:upper:]" "[:lower:]")";
	tmp_name="$(echo "$nickname" | tr "[:upper:]" "[:lower:]")";
	tmp_name="$tmp_name\\|$(echo "$tmp_name" | sed "s/[-+_., ]/[-+_., ]/g")";
	if $(echo "$tmp_link" | grep -q "$tmp_name"); then
	    true;
	else
	    realname="$nickname";
	    nickname="";
	fi;
    fi;



    #unescape the \"
    realname="$(echo "$realname" | sed "s/\\\\\"/\"/g; s/\\([\\t ]\\|^\\)\"\\([^\\t ]\\)/\\1\\&#8222;\\2/g; s/\\([^\\t ]\\)\"\\([\\t ]\\|$\\)/\\1\\&#8220;\\2/g;")";


    #do twitter mumbo jumbo with linkaddr and nickname
    if $(echo "$nickname" | grep -q "^@"); then
	if $(echo "$linkaddr" | grep -qi "twitter\\|app\\.net"); then
            check_url "$linkaddr";
	    linkaddr="$gloret";
	    if test "" = "$linkaddr"; then
		nickname="$(echo "$nickname" | sed s/^@//)";
	    fi;
	elif test "" != "$linkaddr"; then
	    nickname="$(echo "$nickname" | sed s/^@//)";
	    check_url "$linkaddr";
	    linkaddr="$gloret";
	else
	    #check if an app.net or twitter.com user with given nickname exists
	    tmp_name="$(echo "$nickname" | sed "s/^@//")";
            check_url "https://alpha.app.net/$tmp_name";
	    tmp_url="$gloret";
	    if test "" = "$tmp_url"; then
                check_url "https://twitter.com/$tmp_name";
		tmp_url="$gloret";
		if test "" = "$tmp_url"; then
		    linkaddr="";
		    nickname="$tmp_name";
		else
		    linkaddr="$tmp_url";
		fi;
	    else
		linkaddr="$tmp_url";
	    fi;

	fi;
    else
	#prepend an '@'
        #  only when linkaddr contains twitter or app.net
        #  and the nickname is contained in the url
	if test "" != "$linkaddr"; then
            check_url "$linkaddr";
	    linkaddr="$gloret";
	    if $(echo "$linkaddr" | grep -qi "twitter\\|app\\.net"); then
		if test "" != "$nickname"; then
		    tmp_link="$(echo "$linkaddr" | tr "[:upper:]" "[:lower:]")";
		    tmp_name="$(echo "$nickname" | tr "[:upper:]" "[:lower:]")";
		    tmp_name="$tmp_name\\|$(echo "$tmp_name" | sed "s/[-+_., ]/[-+_., ]\\\\?/g")";
		    if $(echo "$tmp_link" | grep -q "$tmp_name"); then
			nickname="@$nickname";
		    fi;
		fi;
	    fi;
	fi;

    fi;
    if $(echo "$linkaddr" | grep -qi "twitter"); then
	titletext=" title=\"auf Twitter\"";
    elif $(echo "$linkaddr" | grep -qi "app\\.net"); then
	titletext=" title=\"auf ADN\"";
    else
	titletext=" title=\"auf $(host_to_desc "$linkaddr")\"";
    fi;

    #print out author line in html
    if test "" != "$realname"; then
	if test "" = "$linkaddr"; then
	    if test "" = "$nickname"; then
		echo -n "$realname";
	    else
		echo -n "$realname ($nickname)";
	    fi;
	else
	    if test "" = "$nickname"; then
		echo -n "<a href=\"$linkaddr\"$titletext>$realname</a>";
	    else
		echo -n "$realname (<a href=\"$linkaddr\"$titletext>$nickname</a>)";
	    fi;

	fi;
    else
	if test "" = "$linkaddr"; then
	    echo -n "$nickname";
	else
	    if test "" = "$nickname"; then
		echo -n "<a href=\"$linkaddr\"$titletext>$(host_to_desc "$linkaddr")</a>";
	    else
		echo -n "<a href=\"$linkaddr\"$titletext>$nickname</a>";
	    fi;
	fi;
    fi;

    #add a delimiter
    if test $(($i - $j)) -gt 1; then
	echo ",";
    else
	echo "";
    fi;
    let j++;
done;


if test "TRUE" = "${use_cache}" && test "TRUE" = "${cache_updated}"; then
    write_cache;
fi;

exit 0;
