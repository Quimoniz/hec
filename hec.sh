#!/bin/bash

# HEC - HTML Export Compiler
#     This is essentially just a build script written in BASH-script. It compiles together the HTML export for an OSF document which resides at a ShowPad.
#     In order to do so, it requires a parameter $padname to be specified upon invocation.
#     It invokes the specified pad's content, calls the parser of SimonWaldherr to parse the content, and prepends the HEADER data.
#     Additionally it sorts the resulting file into the shownot.es "podcasts" directory
#     and calls the browser to present the HTML file
# Copyright 2014 Quimoniz
# Contributions
#     from August 2013 to January 2014 entirely by Quimoniz
#         who was too lazy to just put together all the separate parts
#         of an export manually and who wrote himself a script to do
#         the handywork. He was actually so lazy, that he just used to
#         make some changes to this script whenever it was needed to
#         adjust the export.
# License
#     HEC is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, version 3.
#
#     HEC is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. Unfortunately
#     this includes also cases of seizing power in a sinister attempt
#     to take over the world. See the GNU General Public License
#     for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with HEC. If not, see <http://www.gnu.org/licenses/gpl-3.0.html>
#
# The contents of preview-prepend.txt and preview-append.txt are largely courtesy of SimonWaldherr.
# As preview-prepend.txt and preview-append.txt are data files the copyright statement for them is stated herein as "Copyright 2012-2014 SimonWaldherr, Quimoniz" they are also licensed under GPL version 3.
# Kudos to SimonWaldherr's great parser - without it this whole thing would be useless
# Thanks also go to Dr4k3 for pointing out that this script is more than just a tiny little hack, of the sort which to hide in a hidden corner, no one will ever wot of

padname="$1";
is_preview="no";

config_file=".hec_config";

hec_path="./";
out_path="./";
preview_file="parser-preview.html";
showpad_url="http://pad.shownot.es/doc/";
parser_mode="anycast-full";
parser_version="osfregex"
preview_browser="firefox";
write_outpath="";
if test -f "${config_file}"; then
    while read; do
        if grep -qi "^include=" <<< "$REPLY"; then
            hec_path="$(grep -i "^include=" <<< "$REPLY" | tail -n 1 | sed "s/^.\\{8\\}//;")";
        elif grep -qi "^out_dir=" <<< "$REPLY"; then
            out_path="$(grep -i "^out_dir=" <<< "$REPLY" | tail -n 1 | sed "s/^.\\{8\\}//;")";
        elif grep -qi "^preview_file=" <<< "$REPLY"; then
            preview_file="$(grep -i "^preview_file=" <<< "$REPLY" | tail -n 1 | sed "s/^.\\{13\\}//;")";
        elif grep -qi "^preview_browser=" <<< "$REPLY"; then
            preview_browser="$(grep -i "^preview_browser=" <<< "$REPLY" | tail -n 1 | sed "s/^.\\{16\\}//;")";
        elif grep -qi "^showpad_url=" <<< "$REPLY"; then
            showpad_url="$(grep -i "^showpad_url=" <<< "$REPLY" | tail -n 1 | sed "s/^.\\{12\\}//;")";
        elif grep -qi "^parser_version=" <<< "$REPLY"; then
            parser_version="$(grep -i "^parser_version=" <<< "$REPLY" | tail -n 1 | sed "s/^.\\{15\\}//;")";
        elif grep -qi "^parser_mode=" <<< "$REPLY"; then
            parser_mode="$(grep -i "^parser_mode=" <<< "$REPLY" | tail -n 1 | sed "s/^.\\{12\\}//;")";
        elif grep -qi "^write_outpath=" <<< "$REPLY"; then
            write_outpath="$(grep -i "^write_outpath=" <<< "$REPLY" | tail -n 1 | sed "s/^.\\{14\\}//;")";
        fi;
    done < "${config_file}";
fi;
echo $'# Config file for HEC - HTML Export Compiler\n# Please be aware, that upon each invocation the config file will be read\n# and thereafter be rewritten.\n# Values of config lines will only be preserved if the specific keys have been read out.\n# Unknown keys and commentary will be erased.\n# To reset a value to default it is crucial to delete the key' > ".hec_config";
echo "include=${hec_path}" >> ".hec_config";
echo "out_dir=${out_path}" >> ".hec_config";
echo "preview_file=${preview_file}" >> ".hec_config";
echo "# While \"firefox\" is the default value, \"lynx\" is the recommended setting" >> ".hec_config";
echo "preview_browser=${preview_browser}" >> ".hec_config";
echo "showpad_url=${showpad_url}" >> ".hec_config";
echo '# one of "osfregex", "wp-osf-shownotes"' >> ".hec_config";
echo "parser_version=${parser_version}" >> ".hec_config";
echo $'# which parser modes are available\n#   depends on the parser\'s version' >> ".hec_config";
echo $'# - osfregex, one of\n#   - "anycast-full" (default)\n#   - "anycast"\n#   - "chapter"\n#   - "metastyle"\n#   - "metacast"\n#   - "wikigeeks"\n#   - "json"\n#   - "glossary"\n#   - "tagsalphabetical"\n#   - "print_r"' >> ".hec_config";
echo $'# - wp-osf-shownotes, one of\n#   - "block"/"block style"/"button style"\n#   - "list"/"list_style"\n#   - "osf"/"clean osf"\n#   - "shownot.es" (default)\n#   - "glossary"\n#   - "shownoter"\n#   - "podcaster"\n#   - "JSON"\n#   - "Chapter"\n#   - "PSC"' >> ".hec_config";
echo "parser_mode=${parser_mode}" >> ".hec_config";
echo $'# specially write where I wrote' >> ".hec_config";
echo "write_outpath=${write_outpath}" >> ".hec_config";

preview_file="${hec_path}/${preview_file}";
url_cache_path="${hec_path}/url_cache.dat";
if test ! -f "${url_cache_path}"; then
    touch "${url_cache_path}";
fi;

if test "" = "$padname"; then
  echo "You omitted the mandatory pad name parameter. Aborting.";
  exit 1;
elif test "--preview" = "$1"; then
  padname="$2";
  is_preview="yes";
elif test "--preview" = "$2"; then
  is_preview="yes";
fi;


function getpad {
    local padname="$1";
    
    if test "$padname" = ""; then
	echo "";
	false;
    else
	json_data="$(wget -O - "${showpad_url}$padname/text?t=0" 2>/dev/null)";
	data="$(echo "$json_data" | grep "\"text\": " | sed "s/^  \"text\": \"\\(\\([^\"]\\|\\\"\\)*\\)\"/\\1/")";
	echo "$data" | head --bytes=-1;
    fi;
}
function parse_text {
    echo "$(while read line; do printf '%s\\n' "$line"; done <<< "$(echo "$1" | sed "s/\\\\n/\\n/g;" | sed -rf "${hec_path}/replacements.sed")")";
}

function use_parser {
    if test "osfregex" = "${parser_version}"; then
        tmp_file="$(mktemp)";
#one of "anycast-full", "anycast", "chapter", "metastyle", "metacast", "wikigeeks", "json", "glossary", "tagsalphabetical", "print_r"
        local parser_mode="$1";
        local padtext="$2";
        echo -n "exportmode=$parser_mode&shownotes=" > "$tmp_file";
        echo "$padtext" | sed "s/%/%25/g; s/#/%23/g; s/&/%26/g; s/\\\\n/%0A/g; s/\\\\\"/%22/g; s/ /%20/g" >> "$tmp_file";
        echo -n $'&tags=chapter+section+spoiler+topic+embed+video+audio+image+shopping+glossary+source+app+title+quote&amazon=shownot.es-21&thomann=93439&fullmode=true' >> "$tmp_file";
#tradedoubler doesn't work
#&tradedoubler=16248286
        echo "$(wget --post-file="$tmp_file" -O - "http://tools.shownot.es/parsersuite-old/export.php?mode=getpad" 2>/dev/null | sed "s/&#8221;/\\&#8220;/g")";
        rm "$tmp_file" 2>/dev/null;
    elif test "wp-osf-shownotes" = "${parser_version}"; then
        local query_file="$(mktemp)";
#one of "block"/"block style"/"button style", "list"/"list_style", "osf"/"clean osf", "shownot.es", "glossary", "shownoter", "podcaster", "JSON", "Chapter", "PSC"
        local parser_mode="$1";
        local padtext="$2";
        local parsed_text="";
        #assemble query
        echo -n "pad=" > "${query_file}";
        echo "${padtext}" | sed "s/\\\\n/\\n/g;s/\\\\t/\\t/g;s/\\\\\\(.\\)/\\1/g;" | base64 - | tr -d "\\n" >> "${query_file}";
        echo -n "&tags=&amazon=shownot.es-21&thomann=93439&tradedoubler=16248286&mainmode=${parser_mode}&expmode=source" >> "${query_file}";
        #actually do the query
        parsed_text="$(wget -O - --post-file="${query_file}" "http://tools.shownot.es/parsersuite/api.php" 2>/dev/null)";
        if test -f "${query_file}"; then
            rm "${query_file}";
        fi;
        #remove header
        if test "shownot.es" = "${parser_mode}"; then
            parsed_text="$(echo "${parsed_text}" | sed "1,2d;")";
        fi;

        echo "${parsed_text}";
    fi;
}
padtext="$(parse_text "$(getpad "$padname")")";

padhtml="$(use_parser "${parser_mode}" "$padtext")";
#set mailto: and bitcoin: links
padhtml="$(echo "$padhtml" | sed "s/<span class=\"\\([^\"]*\\)\"\\( data-tooltip=\"[^\"]*\"\\|\\)>\\(\\([^<&]\\|[^<&][^<l]\\|[^<&][^<l][^<t]\\|[^<&][^<l][^<t][^<;]\\)\\+\\) &lt;[Mm][Aa][Ii][Ll][Tt][Oo]:\\([^@<>]\\+@[^@<>]\\+\\)&gt;<\\/span>/<a href=\"mailto:\\5\" class=\"\\1\"\\2>\\3<\\/a>/g; s/<span class=\"\\([^\"]*\\)\"\\( data-tooltip=\"[^\"]*\"\\|\\)>\\(\\([^<&]\\|[^<&][^<l]\\|[^<&][^<l][^<t]\\|[^<&][^<l][^<t][^<;]\\)\\+\\) &lt;[Bb][Ii][Tt][Cc][Oo][Ii][Nn]:\\([a-zA-Z0-9]\\+\\)&gt;<\\/span>/<a href=\"bitcoin:\\5\" class=\"\\1\"\\2>\\3<\\/a>/g")";

padheader="$(echo "$padtext" | sed "s/\\(\\(^\\|\\\\n\\)[Hh][Ee][Aa][Dd]\\([Ee][Rr]\\)\\?.*\\)/\\1/; s/\\(\\\\n\\/[Hh][Ee][Aa][Dd]\\([Ee][Rr]\\)\\).*$\\?/\\1/;")";

padheader="$(echo "$padheader" | sed "s/\\\\n/\\n/g")";

declare -a english_months;
english_months[0]="";
english_months[1]="Jan";
english_months[2]="Feb";
english_months[3]="Mar";
english_months[4]="Apr";
english_months[5]="May";
english_months[6]="Jun";
english_months[7]="Jul";
english_months[8]="Aug";
english_months[9]="Sep";
english_months[10]="Oct";
english_months[11]="Nov";
english_months[12]="Dec";

declare -a german_months;
german_months[0]="";
german_months[1]="Jan";
german_months[2]="Feb";
german_months[3]="Mär";
german_months[4]="Apr";
german_months[5]="Mai";
german_months[6]="Jun";
german_months[7]="Jul";
german_months[8]="Aug";
german_months[9]="Sep";
german_months[10]="Okt";
german_months[11]="Nov";
german_months[12]="Dez";

declare -A podcast_slugdata;
podcast_slugdata["bluemoon"]="bm";
podcast_slugdata["bluemoon/lateline"]="bmll";
podcast_slugdata["absradio"]="abs";
podcast_slugdata["culinaricast"]="culinaricast";
podcast_slugdata["chaosradio"]="cr";
podcast_slugdata["einschlafen"]="ep"
podcast_slugdata["fanb0ys"]="fan";
podcast_slugdata["freak-show"]="mm";
podcast_slugdata["jobscast"]="jc";
podcast_slugdata["hoaxilla"]="hoaxilla";
podcast_slugdata["lecast"]="lecast";
podcast_slugdata["1337kultur"]="lk";
podcast_slugdata["mobilemacs"]="mm";
podcast_slugdata["netzgesprache"]="ng";
podcast_slugdata["netzgespraeche"]="ng";
podcast_slugdata["nsfw"]="nsfw";
podcast_slugdata["psychotalk"]="psyt";
podcast_slugdata["pubkameraden"]="pp";
podcast_slugdata["quasselstrippen"]="qs";
podcast_slugdata["radio-osm"]="osm"
podcast_slugdata["robotiklabor"]="rl";
podcast_slugdata["schoene-ecken"]="se";
podcast_slugdata["sondersendung"]="dss";
podcast_slugdata["soziopod"]="sozio";
podcast_slugdata["wikigeeks"]="wg";
podcast_slugdata["wir-mussen-reden"]="wmr";
podcast_slugdata["wir-muessen-reden"]="wmr";
podcast_slugdata["wrint"]="wrint";
podcast_slugdata["realitaetsabgleich"]="ra";
podcast_slugdata["wrintheit"]="wrintheit";
podcast_slugdata["flaschen"]="flaschen";

declare -A podcast_logodata;
podcast_logodata["bm"]="<img src=\"http://shownot.es/img/logos/bm_logo.png\" width=\"150\" height=\"150\" alt=\"Blue Moon Logo (Foto: Ainhoa Pcb l flickr.com, CC: BY)\" title=\"Blue Moon Logo (Foto: Ainhoa Pcb l flickr.com, CC: BY)\">";
podcast_logodata["bmll"]="<img src=\"http://shownot.es/img/logos/bmll_logo.png\" width=\"150\" height=\"150\" alt=\"Blue Moon/LateLine Logo (Foto des Blue Moons von Ainhoa Pcb l, CC: BY)\" title=\"Blue Moon/LateLine Logo (Foto des Blue Moons von Ainhoa Pcb l, CC: BY)\">";
podcast_logodata["ll"]="<img src=\"http://shownot.es/img/logos/ll_logo.png\" width=\"150\" height=\"150\" alt=\"LateLine Logo\">";
podcast_logodata["abs"]="<img src=\"http://shownot.es/img/logos/abs_logo.png\" width=\"150\" height=\"150\" alt=\"ABSradio Logo\">";
podcast_logodata["culinaricast"]="<img src=\"http://shownot.es/img/logos/culinaricast_logo.png\" width=\"150\" height=\"150\" alt=\"Culinaricast Logo, Verwendung mit freundlicher Genehmigung von @culinaricast\">";
podcast_logodata["cr"]="<img src=\"http://shownot.es/img/logos/cr_logo.png\" width=\"150\" height=\"150\" alt=\"Chaosradio Logo, Verwendung mit freundlicher Genehmigung von @chaosradio\">";
podcast_logodata["ep"]="<img src=\"http://shownot.es/img/logos/ep_logo.png\" width=\"150\" height=\"150\" alt=\"Einschlafen Podcast Logo\">";
podcast_logodata["fan"]="<img src=\"http://shownot.es/img/logos/fan_logo.png\" width=\"150\" height=\"150\" alt=\"Fanb0ys Logo\">";
podcast_logodata["hoaxilla"]="<img src=\"http://shownot.es/img/logos/hoaxilla_logo.png\" width=\"150\" height=\"150\" alt=\"Hoaxilla Logo\">";
podcast_logodata["jc"]="<img src=\"http://shownot.es/img/logos/jc_logo.png\" width=\"150\" height=\"150\" alt=\"Jobscast Logo\">";
podcast_logodata["lecast"]="<img src=\"http://shownot.es/img/logos/lecast_logo.png\" width=\"150\" height=\"150\" alt=\"LeCast Logo\">";
podcast_logodata["lk"]="<img src=\"http://shownot.es/img/logos/lk_logo.png\" width=\"150\" height=\"150\" alt=\"1337kultur Logo cc-by-sa von 1337kultur.de\" title=\"1337kultur Logo cc-by-sa von 1337kultur.de\">";
podcast_logodata["mm"]="<img src=\"http://shownot.es/img/logos/fs_logo.png\" width=\"150\" height=\"150\" alt=\"Freak Show Logo\">";
podcast_logodata["ng"]="<img src=\"http://shownot.es/img/logos/ng_logo.png\" width=\"150\" height=\"150\" alt=\"Netzgespräche Logo\">";
podcast_logodata["nsfw"]="<img src=\"http://shownot.es/img/logos/nsfw_logo.png\" width=\"150\" height=\"150\" alt=\"NSFW Logo\">";
podcast_logodata["pp"]="<img src=\"http://shownot.es/img/logos/pp_logo.png\" width=\"150\" height=\"150\" alt=\"Pubkameraden Logo\">";
podcast_logodata["psyt"]="<img src=\"http://shownot.es/img/logos/psyt_logo.png\" width=\"150\" height=\"150\" alt=\"Psychotalk Logo\">";
podcast_logodata["qs"]="<img src=\"http://shownot.es/img/logos/qs_logo.png\" width=\"150\" height=\"150\" alt=\"Quasselstrippen Logo\">";
podcast_logodata["osm"]="<img src=\"http://shownot.es/img/logos/osm_logo.png\" width=\"150\" height=\"150\" alt=\"Radio OSM Logo.\">"
podcast_logodata["rl"]="<img src=\"http://shownot.es/img/logos/rl_logo.png\" width=\"150\" height=\"150\" alt=\"Robotiklabor Logo\">";
podcast_logodata["dss"]="<img src=\"http://shownot.es/img/logos/sz_logo.png\" width=\"150\" height=\"150\" alt=\"Die Sondersendung Logo\">";
podcast_logodata["se"]="<img src=\"http://shownot.es/img/logos/se_logo.png\" width=\"150\" height=\"150\" alt=\"Schöne Ecken Logo\">";
podcast_logodata["sozio"]="<img src=\"http://shownot.es/img/logos/sozio_logo.png\" width=\"150\" height=\"150\" alt=\"Soziopod Logo\">";
podcast_logodata["wg"]="<img src=\"http://shownot.es/img/logos/wg_logo.png\" width=\"150\" height=\"150\" alt=\"Wikigeeks Logo\">";
podcast_logodata["wmr"]="<img src=\"http://shownot.es/img/logos/wmr_logo.png\" width=\"150\" height=\"150\" alt=\"Wir. Müssen Reden Logo\">";
podcast_logodata["wrint"]="<img src=\"http://shownot.es/img/logos/wr_logo.png\" width=\"150\" height=\"150\" alt=\"WRINT Logo\" title=\"WRINT Logo, Verwendung mit freundlicher Genehmigung von Holger Klein, Lizenz: CC BY-NC-SA, siehe http://creativecommons.org/licenses/by-nc-sa/3.0/\">";
podcast_logodata["ra"]="<img src=\"http://shownot.es/img/logos/ra_logo.png\" width=\"150\" height=\"150\" alt=\"WRINT Realitaetsabgleich Logo\" title=\"WRINT Realitätsabgleich Logo, Verwendung mit freundlicher Genehmigung von Holger Klein, Lizenz: CC BY-NC-SA, siehe http://creativecommons.org/licenses/by-nc-sa/3.0/\">";
podcast_logodata["wrintheit"]="<img src=\"http://shownot.es/img/logos/wrint_logo.png\" width=\"150\" height=\"150\" alt=\"WRINT Wrintheit Logo\" title=\"WRINT Wrintheit Logo, Verwendung mit freundlicher Genehmigung von Holger Klein, Lizenz: CC BY-NC-SA, siehe http://creativecommons.org/licenses/by-nc-sa/3.0/\">";
podcast_logodata["flaschen"]="<img src=\"http://shownot.es/img/logos/fl_logo.png\" width=\"150\" height=\"150\" alt=\"WRINT Flaschen Logo\" title=\"WRINT Flaschen Logo, Verwendung mit freundlicher Genehmigung von Holger Klein, Lizenz: CC BY-NC-SA, siehe http://creativecommons.org/licenses/by-nc-sa/3.0/\">";


declare -A podcast_urldata;
podcast_urldata["bm"]="http://www.fritz.de/media/podcasts/sendungen/blue_moon.html";
podcast_urldata["bmll"]="CONCAT:bm,ll";
podcast_urldata["ll"]="http://www.lateline.de/";
podcast_urldata["abs"]="http://absradio.de/";
podcast_urldata["culinaricast"]="http://culinaricast.de/";
podcast_urldata["cr"]="http://chaosradio.ccc.de/";
podcast_urldata["ep"]="http://einschlafen-podcast.de/";
podcast_urldata["ep"]="http://fanboys.fm/";
podcast_urldata["jc"]="http://www.jobscast.de/";
podcast_urldata["hoaxilla"]="http://www.hoaxilla.com/";
podcast_urldata["lecast"]="http://bullosamedia.de/";
podcast_urldata["lk"]="http://1337kultur.de/";
podcast_urldata["mm"]="http://freakshow.fm/";
podcast_urldata["ng"]="http://www.netzgespräche.de/";
podcast_urldata["nsfw"]="http://not-safe-for-work.de/";
podcast_urldata["pp"]="http://www.pubkameraden.de/";
podcast_urldata["psyt"]="http://www.psycho-talk.de/";
podcast_urldata["qs"]="http://die-quasselstrippen.de/";
podcast_urldata["osm"]="http://blog.openstreetmap.de/radio-osm/";
podcast_urldata["rl"]="http://www.robotiklabor.de/";
podcast_urldata["dss"]="http://die-sondersendung.de/";
podcast_urldata["se"]="http://schoene-ecken.de/";
podcast_urldata["sozio"]="http://soziopod.de/";
podcast_urldata["wg"]="http://wikigeeks.de/";
podcast_urldata["wmr"]="http://wir.muessenreden.de/";
podcast_urldata["wrint"]="http://www.wrint.de/";
podcast_urldata["ra"]="http://www.wrint.de/category/realitaetsabgleich";
podcast_urldata["wrintheit"]="http://www.wrint.de/category/wrintheit";
podcast_urldata["flaschen"]="http://www.wrint.de/category/flaschen";

declare -A podcast_namedata;
podcast_namedata["bm"]="Blue Moon";
podcast_namedata["bmll"]="CONCAT:bm,ll";
podcast_namedata["ll"]="LateLine";
podcast_namedata["abs"]="ABSradio";
podcast_namedata["culinaricast"]="Culinaricast";
podcast_namedata["cr"]="Chaosradio";
podcast_namedata["ep"]="Einschlafen Podcast";
podcast_namedata["fan"]="Fanb0ys";
podcast_namedata["jc"]="Jobscast";
podcast_namedata["hoaxilla"]="Hoaxilla";
podcast_namedata["lecast"]="LeCast";
podcast_namedata["lk"]="1337@kultur:~\$";
podcast_namedata["mm"]="Freak Show";
podcast_namedata["ng"]="Netzgespr&auml;che";
podcast_namedata["nsfw"]="Not Safe For Work";
podcast_namedata["pp"]="Pubkameraden";
podcast_namedata["psyt"]="Psychotalk";
podcast_namedata["qs"]="Quasselstrippen";
podcast_namedata["osm"]="Radio OSM";
podcast_namedata["rl"]="Robotiklabor";
podcast_namedata["dss"]="Die Sondersendung";
podcast_namedata["se"]="Schöne Ecken";
podcast_namedata["sozio"]="Soziopod";
podcast_namedata["wg"]="Wikigeeks";
podcast_namedata["wmr"]="Wir. M&uuml;ssen Reden";
podcast_namedata["wrint"]="WRINT";
podcast_namedata["ra"]="WRINT";
podcast_namedata["wrintheit"]="WRINT";
podcast_namedata["flaschen"]="WRINT";


#check if a header exists, if we don't find a properly denoted header
#  we will do nothing at all
if $(echo "$padheader" | grep "." | head -n 1 | grep -qi "head\\(er\\)\\?") &&  $(echo "$padheader" | tail -n 1 | grep -qi "/head\\(er\\)\\?"); then
    #we begin by putting value of each header line we need into variables
    podcast_name="$(echo "$padheader" | grep -i "^podcast:" | tail -n 1 | sed "s/^.\\{8\\} *//;s/[\\t ]*$//;")";
    episode="$(echo "$padheader" | grep -i "^episode:" | tail -n 1  | sed "s/^.\\{8\\} *//;s/[\\t ]*$//;")";
    starttime="";
    if grep -qi "^actual-starttime" <<< "$padheader"; then
        starttime="$(echo "$padheader" | grep -i "^actual-starttime:" | tail -n 1  | sed "s/^.\\{17\\} *//;s/[\\t ]*$//;")";
    else
        starttime="$(echo "$padheader" | grep -i "^starttime:" | tail -n 1  | sed "s/^.\\{10\\} *//;s/[\\t ]*$//;")";
    fi;
    podcaster="$(echo "$padheader" | grep -i "^podcaster:" | tail -n 1  | sed "s/^.\\{10\\} *//;s/[\\t ]*$//;")";
    shownoter="$(echo "$padheader" | grep -i "^shownoter:" | tail -n 1  | sed "s/^.\\{10\\} *//;s/[\\t ]*$//;")";
    webseite="$(echo "$padheader" | grep -i "^webseite:" | tail -n 1  | sed "s/^.\\{9\\} *//;s/[\\t ]*$//;")";
    sendungsseite="";
    if grep -qi "^episodepage:\\?" <<< "$padheader"; then
	sendungsseite="$(echo "$padheader" | grep -i "^episodepage:\\?" | tail -n 1  | sed "s/^.\\{11\\}:\\? *//;s/[\\t ]*$//;")";
    else
        #deprecated
	sendungsseite="$(echo "$padheader" | grep -i "^sendungsseite:\\?" | tail -n 1  | sed "s/^.\\{13\\}:\\? *//;s/[\\t ]*$//;")";
    fi;
    episodetitle="$(echo "$padheader" | grep -i "^episodetitle:" | tail -n 1  | sed "s/^.\\{13\\} *//;s/[\\t ]*$//;")";
    chatlog="$(echo "$padheader" | grep -i "^chatlogs\\?:\\?" | tail -n 1  | sed "s/^[Cc][Hh][Aa][Tt][Ll][Oo][Gg][Ss]\\?:\\? *//;s/[\\t ]*$//;")";
    sendungstitel="$(echo "$episode" | tail -n 1 | sed "s/-/ /g; s/0\\+\\([0-9]\\+\\)$/\\1/;s/[\\t ]*$//;")";
    sendungstitel="$(echo "$sendungstitel" | grep -o "^." | tr "[:lower:]" "[:upper:]")$(echo "$sendungstitel" | tail --bytes=$(($(echo "$sendungstitel" | wc --chars) - 1)))";
    description_titel="Aus dem Pad";


    #strip leading and trailing brokets
    webseite="$(echo "$webseite" | sed "s/^<//; s/>$//")";
    sendungsseite="$(echo "$sendungsseite" | sed "s/^<//; s/>$//")";

    chatlog="$(echo "$chatlog" | sed "s/^<//; s/>$//")";

    tmp_name="$(echo "$podcast_name" | tr "[:upper:]" "[:lower:]")";
    podcast_slug="${podcast_slugdata["$tmp_name"]}";

    #TODO make this nicer
    if $(echo "$podcast_name" | grep -qi "wrintheit"); then
	podcast_name="wrint";
	podcast_slug="wrint";
    fi;



    #extract the date, so that we'll arrive
    #  at just three integers
    broadcast_year=0;
    broadcast_month=0;
    broadcast_day=0;
    has_proper_date="no";

    broadcast_timestamp="0";

    #only parse something like Tue Jul 02 2013 20:00:00 GMT+0200 (CEST)
    if echo "$starttime" | grep -qi "\\(Sun\\|Mon\\|Tue\\|Wed\\|Thu\\|Fri\\|Sat\\) \\(Jan\\|Feb\\|Mar\\|Apr\\|May\\|Jun\\|Jul\\|Aug\\|Sep\\|Oct\\|Nov\\|Dec\\) \\([0-2][0-9]\\|3[01]\\) [0-9]\\{4\\} [0-9][0-9]:[0-9][0-9]:[0-9][0-9] GMT+[0-9]\\{4\\} ([A-Z]\\{3,5\\})"; then
	broadcast_year="$(echo "$starttime" | sed "s/^.\\{11\\}\\([0-9]\\{4\\}\\).*/\\1/")";
	broadcast_month="$(echo "$starttime" | sed "s/^.\\{4\\}\\(.\\{3\\}\\).*/\\1/")";
	broadcast_day="$(echo "$starttime" | sed "s/^.\\{8\\}0\\?\\([0-9]\\{1,2\\}\\).*/\\1/")";
	
	for i in $(seq 1 12); do
	    if test "${english_months[$i]}" = $broadcast_month; then
		broadcast_month=$i;
		break;
	    fi;
	done;
	has_proper_date="yes";
        broadcast_timestamp="$(date --date="$starttime" +%s)";
    #only parse something like 2013-05-08 12:02:00
    elif echo "$starttime" | grep -qi "^[0-9]\\{4\\}-\\(0[1-9]\\|1[0-2]\\)-\\(0[1-9]\\|[12][0-9]\\|3[01]\\) \\([01][0-9]\\|2[0-3]\\):[0-5][0-9]:[0-5][0-9]"; then
	broadcast_year="$(echo "$starttime" | grep -o "^[0-9]\\{4\\}" | head -n 1)";
	broadcast_month="$(echo "$starttime" | sed "s/^.\\{5\\}0\\?\\([0-9]\\{1,2\\}\\).*/\\1/")";
	broadcast_day="$(echo "$starttime" | sed "s/^.\\{8\\}0\\?\\([0-9]\\{1,2\\}\\).*/\\1/")";
	has_proper_date="yes";
        broadcast_timestamp="$(date --date="$starttime" +%s)";
    #only parse something like 22.04.2013 21:10:16
    elif echo "$starttime" | grep -qi "^\\(0[1-9]\\|[12][0-9]\\|3[01]\\)\\.\\(0[1-9]\\|1[0-2]\\)\\.[0-9]\\{4\\} \\([01][0-9]\\|2[0-3]\\):[0-5][0-9]:[0-5][0-9]"; then
	broadcast_year="$(echo "$starttime" | sed "s/^.\\{6\\}\\([0-9]\\{4\\}\\).*/\\1/" | head -n 1)";
	broadcast_month="$(echo "$starttime" | sed "s/^.\\{3\\}0\\?\\([0-9]\\{1,2\\}\\).*/\\1/")";
	broadcast_day="$(echo "$starttime" | sed "s/^0\\?\\([0-9]\\{1,2\\}\\).*/\\1/")";
	has_proper_date="yes";
        broadcast_timestamp="$(date --date="${broadcast_year}-${broadcast_month}-${broadcast_day} $(echo "$starttime" | sed "s/^.\\{10\\} *//;")" +%s)";
    fi;




    #strip leading characters, also those that are null, dashes or underscores
    episode_number="$(echo "$episode" | grep -o "[-_0-9]\\+$")";
    if $(echo "$episode_number" | grep -q "^[-_]\\+"); then
	episode_number="$(echo "$episode_number" | sed "s/^[-_]\\+//")";
    fi;
    episode_number="$(echo "$episode_number" | sed "s/^0\\+//")";






    #special treatment for Blue Moon
    #  - it might be a Blue Moon/Lateline combination,
    #    or a falsely labeled Lateline
    if test "$podcast_slug" = "bm"; then
	day_of_week=$(date --date="@$broadcast_timestamp" +%w);
	#lateline is only aired from monday to thursday
	if test $day_of_week -gt 0 && test $day_of_week -lt 5; then
	    if $(echo "$podcaster" | grep -qi "holgi\\|Holger Klein\\|Böhmermann\\|Caroline Korneli") || $(echo "$podcaster" | grep $'^[ \t]*$'); then 
		#check wether it might be Lateline without Blue Moon
		if test $(date --date="@$broadcast_timestamp" +%H) -eq 23; then
		    podcast_slug="ll";
		else
		    podcast_slug="bmll";
		fi;
	    fi;
	fi;
    fi;

    archive_path="${out_path}podcasts/";
    archive_number=0;
    archive_filename="";
    archivable="no";
    #only used for wrint/ra/wrintheit
    chaptermarks_file="";

    #getting the archive data correct mandates a heavy bunch of code,
    #  it's far from being beautifull
    if test "$podcast_slug" = "bm" || test "$podcast_slug" = "ll" || test "$podcast_slug" = "bmll"; then
	archive_path+="bm";
	archive_highest_number=0;
	built_date="$(echo "$broadcast_day" | sed "s/^\\([0-9]\\)$/0\\1/")";
	built_date+='_';
	built_date+="$(echo "$broadcast_month" | sed "s/^\\([0-9]\\)$/0\\1/")";
	built_date+='_';
	built_date+="$(echo "$broadcast_year" | sed "s/^[0-9]\\{2\\}\\([0-9]\\{2\\}\\)$/\\1/")";
	for curf in $(ls -1 "$archive_path"); do
	    if test -f "$archive_path/$curf"; then
		if $(echo "$curf" | grep -q "^[0-9]\\{1,5\\}\\.[0-9]\\{2\\}_[0-9]\\{2\\}_[0-9]\\{2\\}\\.html$"); then
		    cur_number=$(echo "$curf" | sed "s/^\\([0-9]\\{1,5\\}\\)\\.[0-9]\\{2\\}_[0-9]\\{2\\}_[0-9]\\{2\\}\\.html$/\\1/");
		    if test $cur_number -gt $archive_highest_number; then
			archive_highest_number=$cur_number;
		    fi;

		    file_date="$(echo "$curf" | sed "s/^[0-9]\\{1,5\\}\\.\\([0-9]\\{2\\}_[0-9]\\{2\\}_[0-9]\\{2\\}\\)\\.html$/\\1/")";

		    if test "$file_date" = "$built_date"; then
			archive_number=$(echo "$curf" | sed "s/^\\([0-9]\\{1,5\\}\\)\\.[0-9]\\{2\\}_[0-9]\\{2\\}_[0-9]\\{2\\}\\.html$/\\1/");
			archive_filename="$curf";
		    fi;
		fi;
	    fi;
	done;
	if test 0 -eq $archive_number && test "" = "$archive_filename"; then
	    archive_number=$(($archive_highest_number + 1));
	    archive_filename="$archive_number.$built_date.html";
	fi;

	if test "$podcast_slug" = "bm"; then
	    sendungstitel="Blue Moon ";
	elif test "$podcast_slug" = "ll"; then
	    sendungstitel="LateLine ";
	elif test "$podcast_slug" = "bmll"; then
	    sendungstitel="Blue Moon/LateLine ";
	fi;
	sendungstitel+="$(echo "$built_date" | sed "s/_/./g")";
	description_titel="Automatisch generiert";


	archivable="yes";
    #podcasts always using three-digit-numbering
    elif test "$podcast_slug" = "qs" || test "$podcast_slug" = "rl" || test "$podcast_slug" = "abs" || test "$podcast_slug" = "ng" || test "$podcast_slug" = "wmr" || test "$podcast_slug" = "jc" || test "$podcast_slug" = "mm" || test "$podcast_slug" = "osm" || test "$podcast_slug" = "lecast" || test "$podcast_slug" = "culinaricast"; then
	archive_path+="$podcast_slug";
	archive_number=$episode_number;
	archive_number="$(echo "$archive_number" | sed "s/^\\([0-9]\\)$/00\\1/; s/^\\([0-9]\\{2\\}\\)$/0\\1/;")";
        if test "mm" = "$podcast_slug"; then
            archive_filename="$archive_number.FS-$archive_number.html";
        elif test "lecast" = "$podcast_slug"; then
            archive_filename="$archive_number.LeCast-$archive_number.html";
	else
            archive_filename="$archive_number.$(echo "$podcast_slug" | tr "[:lower:]" "[:upper:]")-$archive_number.html";
	fi;
        if test "osm" = "$podcast_slug"; then
            sendungstitel="OSMDE${archive_number} Radio OSM ${episode_number}";
        else
	    sendungstitel="${podcast_namedata[$podcast_slug]} $archive_number";
        fi;
	description_titel="Automatisch generiert";
	archivable="yes";
    elif test "$podcast_slug" = "cr" || test "$podcast_slug" = "sozio"; then
	archive_path+="$podcast_slug";
	archive_number=$episode_number;
	archive_number="$(echo "$archive_number" | sed "s/^\\([0-9]\\)$/00\\1/; s/^\\([0-9]\\{2\\}\\)$/0\\1/;")";
        if test "$podcast_slug" = "cr"; then
            archive_filename="$archive_number.Chaosradio-$archive_number.html";
            sendungstitel="${podcast_namedata[$podcast_slug]} $archive_number";
        elif test "$podcast_slug" = "sozio"; then
            archive_filename="$archive_number.Soziopod-$archive_number.html";
            sendungstitel="${podcast_namedata[$podcast_slug]} #$archive_number";
        fi;
	description_titel="Automatisch generiert";
	archivable="yes";
    elif test "$podcast_slug" = "lk"; then
	archive_path+="lk";
	archive_number=$episode_number;
	archive_number="$(echo "$archive_number" | sed "s/^\\([0-9]\\)$/00\\1/; s/^\\([0-9]\\{2\\}\\)$/0\\1/;")";
	archive_filename="$archive_number.Folge-$episode_number.html";
	sendungstitel="Folge $episode_number";
	description_titel="Automatisch generiert";
	archivable="yes";
    elif test "$podcast_slug" = "psyt"; then
	archive_path+="$podcast_slug";
	archive_number=$episode_number;
	archive_number="$(echo "$archive_number" | sed "s/^\\([0-9]\\)$/00\\1/; s/^\\([0-9]\\{2\\}\\)$/0\\1/;")";
        if test -z "$episodetitle"; then
	    sendungstitel="$(tr "[:lower:]" "[:upper:]" <<< "$podcast_slug")${archive_number}";
	else
	    sendungstitel="$(head --bytes=1 <<< "$episodetitle" | tr "[:lower:]" "[:lower:]")$(tail --bytes=+2 <<< "$episodetitle")";
        fi;
	archive_filename="$archive_number.$sendungstitel.html";
	description_titel="Automatisch generiert";
	archivable="yes";
    elif test "$podcast_slug" = "nsfw" || test "$podcast_slug" = "ep" || test "$podcast_slug" = "pp" || test "$podcast_slug" = "se"; then
	archive_path+="$podcast_slug";
	archive_number=$episode_number;
	archive_number="$(echo "$archive_number" | sed "s/^\\([0-9]\\)$/00\\1/; s/^\\([0-9]\\{2\\}\\)$/0\\1/;")";
	archive_filename="$archive_number.$(echo "$podcast_slug" | tr "[:lower:]" "[:upper:]")-$episode_number.html";
        if test "$podcast_slug" = "se"; then
            sendungstitel="$(echo "$podcast_slug" | tr "[:lower:]" "[:upper:]") $episode_number";
        else
            sendungstitel="${podcast_namedata[$podcast_slug]} $episode_number";
        fi;
	description_titel="Automatisch generiert";
	archivable="yes";
    elif test "$podcast_slug" = "hoaxilla" || test "$podcast_slug" = "fan"; then
	archive_path+="$podcast_slug";
	archive_number=$episode_number;
	archive_number="$(echo "$archive_number" | sed "s/^\\([0-9]\\)$/00\\1/; s/^\\([0-9]\\{2\\}\\)$/0\\1/;")";
        if test "$podcast_slug" = "hoaxilla"; then
            archive_filename="$archive_number.$(echo "$podcast_slug" | head --bytes=1 | tr "[:lower:]" "[:upper:]")$(echo "$podcast_slug" | sed "s/^.//")-$episode_number.html";
            sendungstitel="${podcast_namedata[$podcast_slug]} #$episode_number";
        elif test "$podcast_slug" = "fan"; then
            archive_filename="$archive_number.$(echo "$podcast_slug" | tr "[:lower:]" "[:upper:]")${archive_number}.html";
            sendungstitel="Episode #$episode_number";
        fi;

	description_titel="Automatisch generiert";
	archivable="yes";

    elif test "$podcast_slug" = "wrint"; then
	archive_path+="wrint";
	archive_number=$episode_number;
	archive_number="$(echo "$archive_number" | sed "s/^\\([0-9]\\)$/00\\1/; s/^\\([0-9]\\{2\\}\\)$/0\\1/;")";
	archive_filename="$archive_number.WRINT-$episode_number.html";
	found_archive_file="no";
	#scan archive for wether we already have archived a file with the given episode_number
	#  if we find one, we don't have to generate it/guess it
	for curf in $(ls -1 "$archive_path"); do
	    if test -f "$archive_path/$curf"; then
		if $(echo "$curf" | grep -q "^[0-9]\\{1,5\\}\\.[^.]\\+\\.html$"); then
		    if test $(echo "$curf" | grep -o "^[0-9]\\{1,5\\}") -eq $episode_number; then
			archive_filename="$curf";
			wrint_name="$(echo "$curf" | sed "s/^[0-9]\\+\\.//; s/\\.[Hh][Tt][Mm][Ll]$//;")";
			wrint_number="$(echo "$wrint_name" | sed "s/.*-\\([0-9]\\+\\)$/\\1/")";
			wrint_name="$(echo "$wrint_name" | sed "s/-[0-9]\\+$//")";
#			sendungstitel="$(echo "$curf" | sed "s/^[0-9]\\+\\.//; s/\\.[Hh][Tt][Mm][Ll]$//; s/-\\([0-9]\\+\\)$/ \\1/")";
			sendungstitel="$wrint_name $wrint_number";
			description_titel="Uebernommen aus dem Archiv";
			found_archive_file="yes";

			chaptermarks_file="$wrint_name-$wrint_number.txt";
			break;
		    fi;
		fi;
	    fi;
	done;
	#try to determine whether it's a wrintheit or a realitaetsabgleich
	if test "$podcast_slug" = "wrint"; then
	    day_of_week=$(date --date="@$broadcast_timestamp" +%w);
	    # if it's wednesday or friday odds are very likely it's a Realitaetsabgleich
	    if test $day_of_week -eq 3 || test $day_of_week -eq 5; then
		if $(echo "$sendungsseite" | grep -qi "flaschen\\|wein\\|whisk\\|gespr"); then
		    false;
		else
                    #if field podcaster isn't empty, we will assume
                    #  that it was filled in completly,
                    #  which means one of the two hosts "toby" wil be mentioned
                    #  if he isn't mentioned, then it's probably not a
                    #    realitaetsabgleich
                    if ! (grep -q "[^ ]" <<< "$podcaster") || grep -qi "toby" <<< "$podcaster"; then
			podcast_slug="ra";
			if test "$found_archive_file" = "no"; then
			    sendungstitel="Realitaetsabgleich";
			    description_titel="Automatisch generiert";
			fi;
		    fi;
		fi;
	    #if it's sunday, it will probably be a Wrintheit
            # 
	    elif test $day_of_week -eq 0; then
                #if field podcaster isn't empty, we will assume
                #  that it was filled in completly,
                #  which means one of the two hosts "alexandra" wil be mentioned
                #  if she isn't mentioned, then it's probably not a
                #    wrintheit
                if ! (grep -q "[^ ]" <<< "$podcaster") || grep -qi "alexandra\\|tobor\\|silenttiffy" <<< "$podcaster"; then
                    podcast_slug="wrintheit";
		    if test "$found_archive_file" = "no"; then
		        sendungstitel="Wrintheit";
		        description_titel="Automatisch generiert";
		    fi;
                fi;
	    fi;
            #check again for the name of specific podcasters
	    if $(echo "$podcaster" | grep -qi "tobor\\|silenttify"); then
		podcast_slug="wrintheit";
		if test "$found_archive_file" = "no"; then
		    sendungstitel="Wrintheit $episode_number";
		    description_titel="Automatisch generiert";
		fi;
	    fi;
	    if $(echo "$podcaster" | grep -qi "christoph\\|raffelt\\|overkorkt"); then
		podcast_slug="flaschen";
		if test "$found_archive_file" = "no"; then
		    sendungstitel="Wrint Flaschen";
		    description_titel="Automatisch generiert";
		fi;
	    fi;
	    if $(echo "$podcaster" | grep -qi "toby"); then
		podcast_slug="ra";
		if test "$found_archive_file" = "no"; then
		    sendungstitel="Realitaetsabgleich";
		    description_titel="Automatisch generiert";
		fi;
	    fi;
	fi;
	#very specific code to figure out the specific count of a new wrintheit or realitaetsabgleich episode
	if (test "$podcast_slug" = "ra" || test "$podcast_slug" = "wrintheit") && test "$found_archive_file" = "no"; then
	    wrint_number=0;
	    wrint_wrint=0;
	    wrint_name="";
	    wrint_first_regex="";
	    wrint_second_regex="";
	    wrint_third_regex="";
	    if test "$podcast_slug" = "ra"; then
		wrint_name="Realitaetsabgleich";
		wrint_first_regex="^[0-9]\\+\\.Realit\\(ae\\|ä\\)tsabgleich-[0-9]\\+\\.html$";
		wrint_second_regex="s/^[0-9]\\+\\..\\{18,19\\}-\\([0-9]\\+\\)\\.[Hh][Tt][Mm][Ll]/\\1/";
		wrint_third_regex="^[0-9]\\+\\.\\(.*realit\\(ae\\|ä\\)tsabgleich.*\\)\\.html$";
	    elif test "$podcast_slug" = "wrintheit"; then
		wrint_name="Wrintheit";
		wrint_first_regex="^[0-9]\\+\\.Wrintheit-[0-9]\\+\\.html$";
		wrint_second_regex="s/^[0-9]\\+\\..\\{9\\}-\\([0-9]\\+\\)\\.[Hh][Tt][Mm][Ll]/\\1/";
		wrint_third_regex="^[0-9]\\+\\.\\(.*Wrintheit.*\\)\\.html$";
	    fi;
	    #run through archive and note the number of the last episode of either wrintheit or realitaetsabgleich
	    for curf in $(ls -1 "$archive_path"); do
		if test -f "$archive_path/$curf" && $(echo "$curf" | grep -qi "$wrint_first_regex"); then
		    tmp_number=$(echo "$curf" | sed "$wrint_second_regex");

		    if test $tmp_number -gt $wrint_number; then
			wrint_number=$tmp_number;
			wrint_wrint=$(echo "$curf" | grep -o "^[0-9]\\+" | sed "s/^\\([0-9]\\+\\)/\\1/");
		    fi;
		fi;
	    done;
	    #check if there have been unnumbered episodes been after the last numbered one
	    # if we find some, we will then note the preceding-wrint-number of them (iteratively)
	    wrint_add=0;
	    for curf in $(ls -1 "$archive_path"); do
		if test -f "$archive_path/$curf" && $(echo "$curf" | grep -qi "$wrint_third_regex"); then
		    tmp_number=$(echo "$curf" | grep -o "^[0-9]\\+" | sed "s/^\\([0-9]\\+\\)/\\1/");
 		    if test -n "$tmp_number" && test $tmp_number -gt $wrint_wrint; then
			let wrint_add++;
		    fi;
		fi;
	    done;
	    #compile our findings into $sendungstitel
	    if test $wrint_number -gt 0; then
		let wrint_number+=$wrint_add;
		let wrint_number++;
		archive_filename="$archive_number.$wrint_name-$wrint_number.html";
		sendungstitel="$wrint_name $wrint_number";
		description_titel="Generiert auf Basis des Archivs";
		chaptermarks_file="$wrint_name-$wrint_number.txt";
	    else
		archive_filename="$archive_number.$wrint_name.html";
		sendungstitel="$wrint_name";
		description_titel="Generiert auf Basis des Archivs";
	    fi;
	fi;
	archivable="yes";
    fi;


####DEBUG:
#    echo "$archive_path/$archive_filename";
#    echo "\$archivable: $archivable";
#    archivable="no";
#    exit 0;

    #nsfw has a guessable $sendungsseite
    if test "$podcast_slug" = "nsfw" && $(echo "$sendungsseite" | grep -q "^ *$"); then
	sendungsseite="http://not-safe-for-work.de/nsfw$archive_number/";
    fi;

    if test -n "$episodetitle" && $(echo -n "$episodetitle" | grep -q $'.\\+'); then
	sendungstitel="$episodetitle";
        description_titel="Entnommen aus dem Feld \"episodetitle\" im Pad";
    else
       #try to fetch $sendungsseite and use it's title to determine $sendungstitel
	if test "$podcast_slug" != "ra" && test "$podcast_slug" != "wrintheit" && $(echo "$sendungsseite" | grep -qi "https\\?://"); then
	    sendungstitel="$(wget -O - "$sendungsseite" 2>/dev/null | grep -o "<title[^>]*>.*</title>" | head -n 1 | sed "s/<title[^>]*>\\(\\.*\\)/\\1/; s/<\\/title>.*//")";
            description_titel="Extrahiert aus dem title-Element der Seite fuer die spezifische Episode";
            #check if the double->-character (&#187;) was used to separate episode title form the title of the content-management-system
            if echo "$sendungstitel" | grep -q "^LateLine &#187; Blog Archive &#187;"; then
		sendungstitel="$(echo "$sendungstitel" | sed "s/^LateLine &#187; Blog Archive &#187;//")";
	    #check if the double-<-character (&laquo;) was used to separate episode title from content-management-system title
	    elif echo "$sendungstitel" | grep -q "&laquo;"; then
		sendungstitel="$(echo "$sendungstitel" | sed "s/ \\?&laquo;.*//")";
	    #check if "|" was used for separating
	    elif echo "$sendungstitel" | grep -q "|"; then
		sendungstitel="$(echo "$sendungstitel" | sed "s/ \\?|.*//")";
	    #check if "-" was used for separating
	    elif echo "$sendungstitel" | grep -q " - "; then
	    #in case the page's title contains multiple dashes "-", we shall check,
	    #  whether the first dash was used to separate episode number from it's title
		if test $(echo "$sendungstitel" | grep -o " - " | grep -c " - ") -gt 1; then
		    if $(echo "$sendungstitel" | grep -qi "^ *\\($podcast_slug[-_ ]\\?\\)\\? *\\(0*$archive_number\\|$episode_number\\)[-_ ]*"); then
			sendungstitel="$(echo "$sendungstitel" | sed "s/^\\([^-]*-[^-]*\\)-.*$/\\1/; s/[-_ ]$//")";

		    else
			sendungstitel="$(echo "$sendungstitel" | sed "s/ \\?-.*//")";
		    fi;
		else
		    sendungstitel="$(echo "$sendungstitel" | sed "s/ \\?-.*//")";
		fi;

	    fi;
	fi;
    fi;


    #we dump to stdout and to a temporaty file
    #  so that we can save it as preview and possibly also into archive
    touch "$preview_file";
    cat "${hec_path}/preview-prepend.txt" > "$preview_file";
    shownotes_header_tmp="$(mktemp)";

    #now we are generating the header's HTML
    echo $'<div class="info">\n  <div class="thispodcast">\n    <div class="podcastimg">' | tee -a "$shownotes_header_tmp";
    echo -n $'      ' | tee -a "$shownotes_header_tmp";
    echo "${podcast_logodata[$podcast_slug]}" | tee -a "$shownotes_header_tmp";
    echo $'    </div>\n<?php\n' | tee -a "$shownotes_header_tmp";
    echo $'include "./../episodeselector.php";\ninsertselector();\n\n?>\n  </div>' | tee -a "$shownotes_header_tmp";
    echo $'  <div class="episodeinfo">\n    <table>\n      <tr>' | tee -a "$shownotes_header_tmp";
    echo -n $'        <td>Podcast' | tee -a "$shownotes_header_tmp";
    if $(echo "${podcast_urldata[$podcast_slug]}" | grep -qi "^CONCAT:") || $(echo "${podcast_namedata[$podcast_slug]}" | grep -qi "^CONCAT:"); then
	echo -n $'s</td>\n        <td>\n' | tee -a "$shownotes_header_tmp";
	
	declare -a podcast_line_arr_name;
	declare -a podcast_line_arr_url;
	podcast_line_count_name=0;
	podcast_line_count_url=0;
	saved_ifs="$IFS";
	IFS=",";
	if $(echo "${podcast_namedata[$podcast_slug]}" | grep -qi "^concat:"); then
	    for cur_slug in $(echo "${podcast_namedata[$podcast_slug]}" | tr "[A-Z]" "[a-z]"| sed "s/^concat://"); do
		podcast_line_arr_name[$podcast_line_count_name]="$cur_slug";
		let podcast_line_count_name++;
	    done;
	else
		podcast_line_arr_name[0]="${podcast_namedata[$podcast_slug]}";
		podcast_line_count_name=1;
	fi;
	if $(echo "${podcast_urldata[$podcast_slug]}" | grep -qi "^concat:"); then
	    for cur_slug in $(echo "${podcast_urldata[$podcast_slug]}" | tr "[A-Z]" "[a-z]"| sed "s/^concat://"); do
		podcast_line_arr_url[$podcast_line_count_url]="$cur_slug";
		let podcast_line_count_url++;
	    done;
	else
		podcast_line_arr_url[0]="${podcast_urldata[$podcast_slug]}";
		podcast_line_count_url=1;
	fi;
	IFS="$saved_ifs";

	i=0;
	is_first_podcast="yes";
	while test $i -lt $podcast_line_count_name || test $i -lt $podcast_line_count_url; do
	    indexname="";
	    indexurl="";
	    if test $i -lt $podcast_line_count_name; then
		cur_slug="${podcast_line_arr_name[$i]}";
		indexname="${podcast_namedata[$cur_slug]}";
	    fi;
	    if test $i -lt $podcast_line_count_url; then
		cur_slug="${podcast_line_arr_url[$i]}";
		indexurl="${podcast_urldata[$cur_slug]}";
	    fi;

	    if test "" != "$indexname" || test "" != "$indexurl"; then
		if test "$is_first_podcast" = "yes"; then
		    is_first_podcast="no";
		else
		    echo "," | tee -a "$shownotes_header_tmp";
		fi;
	    fi;

	    if test "" != "$indexname" && test "" != "$indexurl"; then
		echo -n "          <a href=\"$indexurl\">$indexname</a>" | tee -a "$shownotes_header_tmp";
	    elif test "" != "$indexname" && test "" = "$indexurl"; then
		echo -n "          $indexname" | tee -a "$shownotes_header_tmp";
	    elif test "" = "$indexname" && test "" != "$indexurl"; then
		indexname="$(echo "$indexurl" | sed "s/^\\([hH][tT][tT][pP][sS]:\\/\\/\\)\\?\\(www\\.//\\)\\?")";
		echo -n "          <a href=\"$indexurl\">$indexname</a>" | tee -a "$shownotes_header_tmp";
	    fi;
	    let i++;
	done;
	if test "$is_first_podcast" = "no"; then
	    echo "" | tee -a "$shownotes_header_tmp";
	fi;
	echo "        </td>" | tee -a "$shownotes_header_tmp";
    else
	echo -n $'</td><td><a href="' | tee -a "$shownotes_header_tmp";
        if test -n "$webseite"; then
            echo -n "$webseite" | tee -a "$shownotes_header_tmp";
        else
            echo -n "${podcast_urldata[$podcast_slug]}" | tee -a "$shownotes_header_tmp";
        fi;
	echo -n $'">' | tee -a "$shownotes_header_tmp";
	echo -n "${podcast_namedata[$podcast_slug]}" | tee -a "$shownotes_header_tmp";
	echo  "</a></td>" | tee -a "$shownotes_header_tmp";
    fi;


    echo  $'      </tr>\n      <tr>' | tee -a "$shownotes_header_tmp";
    echo -n $'        <td>Episode</td><td' | tee -a "$shownotes_header_tmp";
    if test -n "$description_titel"; then
	echo -n " title=\"$description_titel\"><a href=\"" | tee -a "$shownotes_header_tmp";
    else
	echo -n "><a href=\"" | tee -a "$shownotes_header_tmp";
    fi;
    if test "" = "$sendungsseite"; then
	echo -n "#" | tee -a "$shownotes_header_tmp";
    else
	echo -n "$sendungsseite" | tee -a "$shownotes_header_tmp";
    fi;
    echo -n $'">' | tee -a "$shownotes_header_tmp";
    echo -n "$sendungstitel" | tee -a "$shownotes_header_tmp";
    echo $'</a></td>' | tee -a "$shownotes_header_tmp";
    if test "$has_proper_date" = "yes"; then
	echo $'      </tr>' | tee -a "$shownotes_header_tmp";
	if test -n "$broadcast_timestamp"; then
	    echo "      <tr>" | tee -a "$shownotes_header_tmp";
            echo "        <td title=\"Beginn der Sendung bzw. des Livestreams\">Sendung vom</td>" | tee -a "$shownotes_header_tmp";
            echo "        <td title=\"Unix-Timestamp:$broadcast_timestamp\">" | tee -a "$shownotes_header_tmp";
	else
	    echo "      <tr>" | tee -a "$shownotes_header_tmp";
            echo "        <td title=\"Beginn der Sendung bzw. des Livestreams\">Sendung vom</td>" | tee -a "$shownotes_header_tmp";
	fi;
	echo "          $broadcast_day. ${german_months[$broadcast_month]}. $broadcast_year" | tee -a "$shownotes_header_tmp";
	echo -n $'        </td>\n' | tee -a "$shownotes_header_tmp";
	echo $'      </tr>\n' | tee -a "$shownotes_header_tmp";
    fi;
    echo $'      <tr>\n        <td title="In alphabetischer Reihenfolge">Podcaster</td>\n        <td>' | tee -a "$shownotes_header_tmp";
    bash "${hec_path}/form-userlist.sh" cache="${url_cache_path}" "$podcaster" | sed "s/^\\(.*\\)/          \\1/" | tee -a "$shownotes_header_tmp";
    echo '        </td>';
    echo $'      </tr>\n      <tr>\n        <td title="In alphabetischer Reihenfolge">Shownoter</td>\n        <td>' | tee -a "$shownotes_header_tmp";
    bash "${hec_path}/form-userlist.sh" cache="${url_cache_path}" "$shownoter" | sed "s/^\\(.*\\)/          \\1/" | tee -a "$shownotes_header_tmp";
    echo $'	</td>\n      </tr>' | tee -a "$shownotes_header_tmp";
    if test -n "$chatlog"; then
	echo $'      <tr>' | tee -a "$shownotes_header_tmp";
	host_of_chatlog="$(echo "$chatlog" | sed "s/^[a-zA-Z0-9]\\+:\\/\\{0,2\\}//; s/\\(\\.[-_%a-zA-Z0-9]\\+\\)\\(:[0-9]\\+\\)\\?\\(\\/[^/#]*\\)*\\(#.*\\)\\?$/\\1/")";
	if $(echo "$host_of_chatlog" | grep -q "^#"); then
	    host_of_chatlog="";
	else
	    host_of_chatlog="$(echo "$host_of_chatlog" | sed "s/\\.\\([Cc][Oo][Mm]\\|[Dd][Ee]\\|[Tt][Kk]\\|[Oo][Rr][Gg]\\)$//")";
	fi;
	echo $'        <td title="Bei Verletzung der eigenen Privatsphäre bitte uns kontaktieren, wir werden uns dann darum bemühen denjenigen rauszufiltern">Chatlog</td>' | tee -a "$shownotes_header_tmp";
	echo -n $'        <td>\n          <a href="' | tee -a "$shownotes_header_tmp";
	echo "$chatlog" | tee -a "$shownotes_header_tmp";
	echo -n '">' | tee -a "$shownotes_header_tmp";
	if test -n "$host_of_chatlog"; then
	    echo -n "&lt;$host_of_chatlog&gt;" | tee -a "$shownotes_header_tmp";
	elif test -n "$chatlog"; then
	    echo -n "&lt;$chatlog&gt;" | tee -a "$shownotes_header_tmp";
	else
	    echo -n "keines" | tee -a "$shownotes_header_tmp";
	fi;
        echo $'</a>\n        </td>' | tee -a "$shownotes_header_tmp";
	echo $'      </tr>' | tee -a "$shownotes_header_tmp";
    fi;
    echo $'    </table>\n  </div>\n</div>' | tee -a "$shownotes_header_tmp";

    if test "yes" = "$is_preview"; then
#red label
#        echo -n "<div style=\"clear: both; border-radius: 15px; box-shadow: 2px 2px 3px #303030; text-align: center; text-shadow: 0px 1px 1px #e0a0a0; font-size: 26pt; line-height: 46px; padding: 9px 5px 7px 16px; background: white linear-gradient(to bottom, rgb(255, 208, 208) 0%, rgb(240, 128, 128) 80%, rgb(240, 112, 112) 100%) repeat scroll 0% 0%;\">" | tee -a "$shownotes_header_tmp";
#yellow label
        echo -n "<div style=\"clear: both; text-align: center; padding: 40px 0px 0px 0px;\"><div id=\"warning_label\" style=\"margin: 0px auto 0px auto; width: 576pt; padding: 9px 5px 7px 5px; text-align: center; font-family: Sans, Sans-Serif; font-size: 26pt; line-height: 33pt; border-radius: 15px; box-shadow: 2px 2px 3px #303030; text-shadow: 0px 1px 1px #e0e090; background: white linear-gradient(to bottom, rgb(255, 255, 176) 0%, rgb(255, 244, 112) 38%, rgb(255, 248, 96) 83%,  rgb(232, 232, 96) 96%, rgb(208, 208, 112) 100%) repeat scroll 0% 0%;\" title=\"Dies ist kein Button\" onclick=\"if(!confirm('Nein, wirklich kein Button.')) {var text='', label=document.getElementById('warning_label'), cur, parent; parent=label.parentNode; for (var i in label.childNodes) { cur=label.childNodes[i]; if (3 == cur.nodeType) { if (cur.nodeValue) { text += cur.nodeValue; } else if (cur.data) { text += cur.data; } else if (cur.innerText) { text+=cur.innerText; } text+='\n';} } parent.removeChild(label); label=document.createElement('input'); label.type='button'; label=parent.appendChild(label); label.value=text; label.title='Ich hoffe du bist jetzt zufrieden.'; label.onclick=function () { alert('Selber Schuld, jetzt bist du in einer Klickstrecke.'); if(confirm('Magst du weitergeleitet werden?')) { switch (Math.floor(Math.random() * 4)) { case 0: location.href='/podcasts/'; break; case 1: location.href='http://hoersuppe.de/'; break; case 2: location.href='http://podcascription.de/'; break; case 3: location.href='http://podunion.com'; break; } } if(confirm('Stehst du auf Endlosschleifen?')) { var i = 0; while (++i) { if (0 == (i%10)) { if(confirm('War genug, oder?')) { break; } } else { alert('Das geht jetzt so weiter');} } }  }; }\">" | tee -a "$shownotes_header_tmp";
        echo "Dies ist eine Voransicht,<br/>die Shownotes sind noch in &Uuml;berarbeitung<!--<div style=\"margin: 0pt 0pt 0pt 483pt; height: 0px; overflow: visible; font-size: 9pt; color: #a0a0a0; line-height: 30pt; text-shadow: none;\">Dies ist kein Button</div>--></div></div>" | tee -a "$shownotes_header_tmp";
    fi;

    #funny how few lines it takes to actually print out the parsed body
    #  kudos (thanks) to Simon Waldherr for writing the OSF parser
    #  really an awesome thing that parser
    #  takes some OSF, abstracts it internally to a data heap in a few arrays
    #  then weaves nice bubbles of hypertext
    #  thanks again
    cat "$shownotes_header_tmp" >> "$preview_file";
    echo "$padhtml" | tee -a "$preview_file";

    if test "$archivable" = "yes"; then
	cat "$shownotes_header_tmp" > "$archive_path/$archive_filename";
	echo "$padhtml" >> "$archive_path/$archive_filename";
	if test -n "$chaptermarks_file"; then
	    use_parser "chapter" "$padtext" > "$archive_path/$chaptermarks_file";
	fi;
    fi;

    cat "${hec_path}/preview-append.txt" >> "$preview_file";

    rm  "$shownotes_header_tmp";

    # display file in browser
    # note: for some reason firefox doesn't like paths which contain two consecutive "//"
    #     while bash just ignores the second slash character
    #     so we'll remove any double dashes
    #     Anyway, they occur here mainly because we append a slash to
    #     config variable "$hec_path"
    if test -n "${preview_browser}"; then
        if grep -qi "lynx" <<< "${preview_browser}"; then
            # lynx doesn't fork upon invocation
            ${preview_browser} "$(sed "s/\\/\\+/\\//g;" <<< "$preview_file")" 2>/dev/null
        else
            ${preview_browser} "$(sed "s/\\/\\+/\\//g;" <<< "$preview_file")" 2>/dev/null &
        fi;
    fi;
#DEBUG
#    echo "$podcast_slug";
#    echo "$episode_number"
#    echo "$podcast_name - $episode";
#    echo "$sendungstitel";
#    echo "$broadcast_day.$broadcast_month.$broadcast_year";
#    echo "$webseite";
#    echo "$sendungsseite";
#    echo "$podcaster"
#    echo "$shownoter";
    echo "$archive_path/$archive_filename" > "${hec_path}/${write_outpath}";
    exit 0;
else
    echo "" > "${hec_path}/${write_outpath}";
    exit 1;
fi;
