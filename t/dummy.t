BEGIN { print "1..1\n" }

eval { require awe::Controller };
if ( $@ ) {
 print "not ";
}
print "ok\n";
