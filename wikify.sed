/^Rule:[[:space:]*][[:digit:]+]/ {
   s/^/*'''/
   s/$/'''/
}

s/^[[:space:]+]/**/

/^\*\*.* =/ {
   s/=/'''='''/
}

s/^\*\*description '''=''' (.*)/**<pre>\1<\/pre>/

#s/^(\*\*\([[:digit:]+]\) [[:alpha:]+]) ([[:alpha:]+]) (.*)/\1 '''\2''' \3/

#Add color to rule-specific constraints
/^\*\*\([[:digit:]+]/ !{
   /^\*\*<pre>/ !{
      s/^\*\*/**<span style='color:#FF6600'>/
      s/^(\*\*.*)/\1<\/span>/
   }
}
