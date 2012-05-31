#!/usr/bin/perl -w
use strict;

#
# Little test script that creates a hash and then calls smart_printer_default.
# There are also some tests that show how to defail with defined and undefined hash entries.
# Finally, some tests with regular expressoins to test for repeated \ characters.
#
use Pitonyak::StringUtil qw(smart_printer_default);

my %x = ('a', 'A', 'b', 'B', 'c', 'C', 'd', 'D');
undef ($x{'a'});
delete ($x{'b'});
$x{'c'} = undef;
#%x = ();
print "\n";
print smart_printer_default(\%x);

foreach my $y(keys(%x))
{
  if (! exists($x{$y})) {
    print "$y does not exist in the hash.\n";
  } elsif (! defined($x{$y})) {
    print "$y exists but the stored value is undef.\n";
  } else {
    print "$y => $x{$y}\n";
  }
}

print "\n";

my @xx = ('x${one}', 'x\\${one}  ', 'x\\\\${one}  ', 'x\\\\\\${one}  ', 'x\\\\\\\\${one}  ', 'x\\\\\\\\\\${one}  ');
foreach (@xx)
{
  my $y = $_;
  if (/(?<!\\)((\\\\)*)\${(.*?)}/)
  {
    my $parens = $1;
    my $subst_name = $2;
    my $subst_value = 'ABC';
    s/(?<!\\)(?:(\\\\)*)(\${.*?})/$parens$subst_value/;
    print "matched ($y) => ($_)\n";
  }
  else
  {
    print "xxxxxxx ($_)\n";
  }

}

#s/(?<!\\)(?:(\\\\)*)\s*$//;
#$x =~ s/(.*?(?<!\\)(?:(\\\\)*))\s*$/$1/;
