s/([ )("'])#q( |$)/\1#quote\2/g;
s/([^ ])((#[a-zA-ZäöüÄÖÜß]+ )*#[a-zA-ZäöüÄÖÜß]+$)/\1 \2/g;
s/\.( (#[a-zA-ZäöüÄÖÜß]+ )*#[a-zA-ZäöüÄÖÜß]+)?$/\1/g;
s/ #q( |$)/ #quote\1/;
s/\\\\/\\/g;

#only match lines containing brokets
/<.*>/ {
#copy pattern space to hold space
#  (so pattern space and hold space contain the same)
h
#do a replacement, match everything, forget everything that is not in brokets
#  thereby keeping only the link in the pattern space
s/^.*<(.*)>.*/\1/;
#run the actual replacement commands on the link
#replace "+" characters with hex escape sequence "%2B"
s/\+/%2B/g;
#prepend "http://" if a link begins with three double-ues
s/^([Ww]{3})\./http:\/\/\1/;

#Replace http with https
s/^[Hh][Tt][Tt][Pp]:\/\/([a-zA-Z]+\.wikipedia\.org.*)/https:\/\/\1/i;
s/^[Hh][Tt][Tt][Pp]:\/\/(www\.)?(youtube\.com.*)/https:\/\/\1\2/i;
s/^[Hh][Tt][Tt][Pp]:\/\/(www\.)?(twitter\.com.*)/https:\/\/\1\2/i;
s/^[Hh][Tt][Tt][Pp]:\/\/([a-zA-Z]+\.)?(app\.net.*)/https:\/\/\1\2/i;
s/^[Hh][Tt][Tt][Pp]:\/\/([a-zA-Z]+\.)?(github\.com.*)/https:\/\/\1\2/i;
s/^[Hh][Tt][Tt][Pp]:\/\/([a-zA-Z]+\.)?(amazon.(de|com).*)/https:\/\/\1\2/i;


#Append the current pattern space to hold space (with a newline in between)
#  so we get into the hold space:
#     the original content of the line
#     + newline 
#     + the replacement link
#  Note:  While usually we don't have a newline in our pattern/pattern-space,
#    since the line delimiter is a newline, we can put a newline into it.
#    This offers the great opportunity of having our own special
#    delimiter character while operating on a string.
H
#exchange pattern and hold space,
#  so to do stuff with the hold space's present content
x
#Now put together the original content and our replacement
#  for that we just have to forget about
#  the old link and put in the replacement link
s/^(.*)<[^>]*>([^\n]*)\n(.*)/\1<\3>\2/;
}