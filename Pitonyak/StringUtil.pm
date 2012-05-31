package Pitonyak::StringUtil;

#************************************************************

=head1 NAME

Pitonyak::StringUtil - General string utilities.

String module created by Andrew Pitonyak for his personal use
to format strings for pretty output.

=head1 SYNOPSIS

The subroutines in this module are intended to be used as methods, not as
calls on an object. Therefore, you should call all methods directly.

Many of the subroutines modify the arguments. For example, when you trim space
from a string, the argument is modified.

Methods are not available unless they are specifically imported. So, to use
the C<< smart_printer_default >> routine, you must first import it. For example,

=begin html
<table BORDER='1' CELLPADDING="10"><TR><TD><code>
use Pitonyak::StringUtil qw(smart_printer_default);        <br/>
my %hash2 = ('a' => 'A', 'b' => 'B');                      <br/>
my @strings = ('123456789', '123', \%hash2);               <br/>
my %hash1 = ('one' => 1, 'two' => 2, 'ary' => \@strings);  <br/>
print smart_printer_default(\%hash1);                      <br/>
</code>
</TD></TR></table>

=end html

=head1 DESCRIPTION

=cut

#************************************************************

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = '1.05';
@ISA    = qw(Exporter);
@EXPORT = qw(
);

@EXPORT_OK = qw(
  array_width
  center_fmt
  compact_space
  delimited_values
  substr_no_space
  hash_key_width
  hash_val_width
  left_fmt
  num_int_digits
  num_with_leading_zeros
  trans_blank
  trim_fmt
  trim_space
  right_fmt
  smart_printer
  smart_printer_default
);

use Carp;
use strict;

#************************************************************

=pod

=head2 array_width

Return the length of the longest string in an array.

Arguments are not modified.

=over 4

=item C<< array_width([arg1], [arg2], ... [argn]) >>

Each argument or array element should be a scalar or a reference to an array.
The primary usage is to print a group of strings in a fixed width field.
For example:

=begin html

<table BORDER='1' CELLPADDING="10"><TR><TD><code>
use Pitonyak::StringUtil qw(array_width right_fmt);    <br/>
                                                          <br/>
my @strings = ('one', 'two', 'three', 'four');            <br/>
foreach (right_fmt(array_width(@strings), @strings)) {    <br/>
&nbsp;  print "$_\n";                                     <br/>
}                                                         <br/>
</code></TD></TR></table>

=end html

produces:

=begin html

<table BORDER='1' CELLPADDING="10"><TR><TD><code>

&nbsp;&nbsp;one  <br/>
&nbsp;&nbsp;two  <br/>
three            <br/>
&nbsp;four       <br/>

</code></TD></TR></table>

=end html

=back

=cut

#************************************************************

sub array_width
{
  my $width = 0;
  my $this_width;
  foreach (@_)
  {
    $this_width = ( ref($_) ne 'ARRAY' ) ? length($_) : array_width(@$_);
    $width = $this_width if $this_width > $width;
  }
  return $width;
}

#************************************************************

=pod

=head2 center_fmt

Modify the arguments to be strings centered in the specified width.
A string that is longer than the specified width is truncated.

In array context, return the entire array.

In scalar context, return only the first string.

=over 4

=item C<< center_fmt($width_to_use, @strings_to_format) >>

Modify the arguments to be strings centered in the specified width.

=begin html

<UL>
  <LI>Modify the arguments to be strings centered in C<< $width_to_use >>.   </LI>
  <LI>The strings are left and right padded to use the entire width.         </LI>
  <LI>The strings are truncated to fit into the space if they are too long.  </LI>
</UL>

<br/>
<table BORDER='1' CELLPADDING="10"> <TR><TD> <code>
use Pitonyak::StringUtil qw(center_fmt);         <br/>
                                                    <br/>
my $long_str = 'I am really long';                  <br/>
my @strings = ('one', 'two', 'three', 'four');      <br/>
foreach (center_fmt(8, @strings, $long_str)) {      <br/>
&nbsp;&nbsp;print "$_\n";                           <br/>
}
</code></TD></TR></table>

=end html

produces:

=begin html

<table BORDER='1' CELLPADDING="10"><TR><TD><code>

&nbsp;&nbsp;one  <br/>
&nbsp;&nbsp;two  <br/>
&nbsp;three      <br/>
&nbsp;&nbsp;four <br/>
I am rea         <br/>

</code></TD></TR></table>

=end html

=back

=cut

#************************************************************

sub center_fmt
{
  # No parameter, return undef
  if ( $#_ < 1 )
  {
    carp("Usage: center_fmt(<len>, <strings to format>)");
    return undef;
  }

  my $len     = $_[0];
  my @strings = trim_fmt(@_);
  my @rc;
  foreach my $str (@strings)
  {
    my $slop        = $len - length($str);
    my $left_space  = int( $slop / 2 );
    my $right_space = $slop - $left_space;
    $str = " " x $left_space . $str . " " x $right_space if $slop > 0;
    push ( @rc, $str );
  }
  return wantarray ? @strings : $strings[0];
}

#************************************************************

=pod

=head2 compact_space

Modify each argument to change runs of white space to a single space.

=over 4

=item C<< compact_space(@list_of_strings) >>

Modify each argument to change runs of white space to a single space.

=begin html

<UL>
  <LI>Arguments are modified.                         </LI>
  <LI>Continuous spaces are changed to a single space.</LI>
  <LI>Leading and trailing spaces are removed.        </LI>
<UL>
<br/>
<table BORDER='1' CELLPADDING="10"><TR><TD><code>
use Pitonyak::StringUtil qw(compact_space); <br/>
                                               <br/>
my $test_str = '  one  two  ';                 <br/>
compact_space($test_str);                      <br/>
print "($test_str)\n";
</code>
</TD></TR></table>

=end html

=back

=cut

#************************************************************

sub compact_space
{
  # No parameter, return undef
  if ( $#_ < 0 )
  {
    carp("Usage: compact_space(<strings to compact>");
    return undef;
  }

  for (@_)
  {
    #
    # This new method is about four times faster
    # than the split and join
    # $_ = join ' ', split /\s+/, $_;     # split then join
    #
    tr/ //s;

    #
    # Save a call to trim_space() at the end!
    #
    s/^\s*//;    # Remove spaces from front
    s/\s*$//;    # Remove spaces from end
  }
  return wantarray ? @_ : $_[0];
}

#************************************************************

=pod

=head2 delimited_values

=over 4

=item C<< delimited_values($delimiter, @values) >>

For each string in C<< @values >>, split it based on the delimiter.
White space is trimmed from the front and rear.
An array of values is returned.

C<< delimited_values(',', '1, 2, 3, 4'); >>

=back

=cut

#************************************************************

sub delimited_values
{
  my @values;
  my $delimiter = shift if ($#_ >= 0);
  foreach my $arg (@_)
  {
    push @values, map {trim_space($_)} split($delimiter, $arg);
  }
  return @values;
}

#************************************************************

=pod

=head2 substr_no_space

=over 4

=item C<< substr_no_space($line, $start, $len) >>

Extract text from C<< $line >> starting at the zero based
location C<< $start >>, with length C<< $len >>.

Leading and trailing spaces are removed.

Bounds are checked to avoid errors.

=back

=cut

#************************************************************

sub substr_no_space
{
  if ( $#_ != 2 )
  {
    carp("Usage: substr_no_space(<line>, <start>, <length>");
    return undef;
  }
  my $llen  = length($_[0]);
  return '' if ($llen <= $_[1]);
  my $rc = ($llen <= ($_[1] + $_[2])) ? substr($_[0], $_[1]) : substr($_[0], $_[1], $_[2]);
  return trim_space($rc);
}

#************************************************************

=pod

=head2 hash_key_width

=over 4

=item C<< hash_key_width($hash_reference) >>

Determine the maximum width of the keys in a hash reference.
Usually used to right justify hash keys. For example:

=begin html

<table BORDER='1' CELLPADDING="10">
<TR><TD>
<code>
use Pitonyak::StringUtil qw(hash_key_width right_fmt); <br/>
my %map = ('one'=>1, 'two'=> 2, 'three'=>3, 'four'=>4);   <br/>
my $width = hash_key_width(%map);                         <br/>
while ( my ($key, $value) = each(%map) ) {                <br/>
&nbsp;&nbsp;print right_fmt($width, $key)." => $value\n"; <br/>
}
</code>
</TD></TR></table>

=end html

produces

=begin html

<table BORDER='1' CELLPADDING="10">
<TR><TD>
<code>
three => 3            <br/>
&nbsp;&nbsp;one => 1  <br/>
&nbsp;&nbsp;two => 2  <br/>
&nbsp;four => 4       <br/>
</code>
</TD></TR></table>

=end html

The function is defined as C<< sub hash_key_width(\%) >>,
so Perl automatically uses a hash reference for the call;
in the example above, C<< %map >> is used rather than C<< \%map >>.

=back

=cut

#************************************************************

sub hash_key_width(\%)
{
  # No parameter, return 0
  if ( $#_ < 0 || !UNIVERSAL::isa( $_[0], 'HASH' ) )
  {
    carp("Usage: hash_key_width(<hash_reference>)");
    return 0;
  }

  my $hash_ref = shift;
  my $ref_type = ref($hash_ref);
  my $width    = 0;
  foreach my $key ( keys %$hash_ref )
  {
    $width = length($key) if length($key) > $width;
  }
  return $width;
}

#************************************************************

=pod

=head2 hash_val_width

=over 4

=item C<< hash_val_width($hash_reference) >>

Determine the maximum width of the values in a hash.
The usage is the same as C<< hash_key_width >>.

=back

=cut

#************************************************************

sub hash_val_width(\%)
{
  # No parameter, return 0
  if ( $#_ < 0 || !UNIVERSAL::isa( $_[0], 'HASH' ) )
  {
    carp("Usage: hash_val_width(<hash_reference>)");
    return 0;
  }

  my $hash_ref = shift;
  my $ref_type = ref($hash_ref);
  my $width    = 0;
  foreach my $key ( keys %$hash_ref )
  {
    $width = length( $hash_ref->{$key} )
    if length( $hash_ref->{$key} ) > $width;
  }
  return $width;
}

#************************************************************

=pod

=head2 left_fmt

Modify the arguments by appending space to force them to be the specified length.

=over 4

=item left_fmt($width_to_use, @strings_to_format)

Modify the arguments by appending space to force them to be the specified length.

=begin html

<UL>
  <LI>Arguments are modified.                                     </LI>
  <LI>Append spaces so that each argument is the requested width. </LI>
  <LI>Do not truncate arguments even if they are too long.        </LI>
</UL>
<br/>
<table BORDER='1' CELLPADDING="10">
<TR><TD>
<code>
use Pitonyak::StringUtil qw(hash_key_width left_fmt);  <br/>
my %map = ('one'=>1, 'two'=> 2, 'three'=>3, 'four'=>4);   <br/>
my $width = hash_key_width(%map);                         <br/>
while ( my ($key, $value) = each(%map) ) {                <br/>
&nbsp;&nbsp;print left_fmt($width, $key)." => $value\n"; <br/>
}
</code>
</TD></TR></table>

=end html

produces

=begin html

<table BORDER='1' CELLPADDING="10">
<TR><TD>
<code>
three => 3            <br/>
one&nbsp;&nbsp; => 1  <br/>
two&nbsp;&nbsp; => 2  <br/>
four&nbsp; => 4       <br/>
</code>
</TD></TR></table>

=end html

=back

=cut

#************************************************************

sub left_fmt
{
  # No parameter, return undef
  if ( $#_ < 1 )
  {
    carp("Usage: left_fmt(<len>, <strings to format>)");
    return undef;
  }

  my $len = shift;
  my @rc;
  foreach my $str (@_)
  {
    my $slop = $len - length($str);
    $str = $str . " " x $slop if $slop > 0;
    push ( @rc, $str );
  }
  return wantarray ? @rc : $rc[0];
}

#************************************************************

=pod

=head2 num_int_digits

=over 4

=item C<< num_int_digits($integer_number) >>

Return the number of digits in this integer.
This method fails if the number is not an integer.
For example, consider the following example:

=back

=begin html

<table BORDER='1' CELLPADDING="10">
<TR><TD>
<code>
use Pitonyak::StringUtil qw(num_int_digits right_fmt);              <br/>
my @numbers = (7, '00554', '+32', '-677', '123.456', 3.1415, 1.9e23);  <br/>
foreach my $num (@numbers) {                                           <br/>
&nbsp;&nbsp;print right_fmt(9, $num)." = ".num_int_digits($num)." = ".right_fmt(9, 0+$num)." = ".right_fmt(4, sprintf( "%d", $num ))."\n"; <br/>
}
</code>
</TD></TR></table>

=end html

produces

=begin html

<table BORDER='1' CELLPADDING="10">
<TR><TD><code>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;7 = 1 =&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;7 =&nbsp;&nbsp;&nbsp;&nbsp;7 <br/>
&nbsp;&nbsp;&nbsp;&nbsp;00554 = 3 =&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;554 =&nbsp;&nbsp;554 <br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; +32 = 2 =&nbsp;&nbsp; &nbsp; &nbsp; &nbsp;32 =&nbsp;&nbsp;&nbsp;32 <br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-677 = 4 =&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-677 = -677           <br/>
&nbsp;&nbsp;123.456 = 3 =&nbsp;&nbsp;&nbsp;123.456 =&nbsp;&nbsp;123 <br/>
&nbsp;&nbsp;&nbsp;3.1415 = 1 =&nbsp;&nbsp;&nbsp;&nbsp;3.1415 =&nbsp;&nbsp;&nbsp;&nbsp;3 <br/>
&nbsp;1.9e+023 = 2 =&nbsp;&nbsp;1.9e+023 =&nbsp;&nbsp;&nbsp;-1 <br/>
</code></TD></TR></table>

=end html

Make special note of the results for numbers with decimals, and especially
for numbers that are very large in magnitude (as in much larger than an integer).

=cut

#************************************************************

sub num_int_digits
{
  # No parameter, return undef
  if ( $#_ < 0 )
  {
    carp("Usage: num_int_digits(<number>");
    return undef;
  }
  return length( sprintf( "%d", $_[0] ) );
}

#************************************************************

=pod

=head2 num_with_leading_zeros

Format numbers to contain leading zeros.

=over 4

=item num_with_leading_zeros(($width_to_use, @numbers_to_format)

Return N-digit strings representing the number with leading zeros.

=begin html

<UL>
  <LI>Arguments are <B>NOT</B> modified.                             </LI>
  <LI>Negative signs are not returned unless the width is negative.  </LI>
  <LI>Prepend the number with leading zeros to force the string to the specified length.</LI>
  <LI>Numbers are printed as integers, and really large numbers are a problem (see example).</LI>
</UL>
<br/>
<table BORDER='1' CELLPADDING="10"><TR><TD><code>
use Pitonyak::StringUtil qw(num_with_leading_zeros);                <br/>
my @numbers = (7, '00554', '+32', '-677', '123.456', 3.1415, 1.9e23);  <br/>
foreach my $num (@numbers) {                                           <br/>
&nbsp;&nbsp;print num_with_leading_zeros(-5, $num)." <= $num\n";       <br/>
}
</code></TD></TR></table>

=end html

produces

=begin html

<table BORDER='1' CELLPADDING="10"><TR><TD><code>
00007 <= 7          <br/>
00554 <= 00554      <br/>
00032 <= +32        <br/>
-0677 <= -677       <br/>
00123 <= 123.456    <br/>
00003 <= 3.1415     <br/>
-0001 <= 1.9e+023   <br/>
</code></TD></TR></table>

=end html

=back

=cut

#************************************************************

sub num_with_leading_zeros
{
  # No parameter, return undef
  if ( $#_ < 1 )
  {
    carp("Usage: num_with_leading_zeros(<length>, <list of numbers>");
    return undef;
  }

  my $desired_digits = shift;
  my @rc;
  my $negative = 0;
  if ($desired_digits < 0)
  {
    $desired_digits = -$desired_digits;
    $negative = 1;
  }
  foreach (@_)
  {
    my $num_digits = $desired_digits;
    my $num = sprintf "%d", $_;
    my $rvalue = "";
    if ( $num < 0 )
    {
      $num = -$num;
      if ($negative)
      {
        --$num_digits;
        $rvalue = '-';
      }
    }
    if ( $num_digits != 0 )
    {
      my $tmp = $num;
      my $lead_zero = $num_digits - length($tmp);
      if ( $lead_zero > 0 )
      {
        $rvalue .= "0" x $lead_zero . $tmp;
      }
      else
      {
        $rvalue .= substr $tmp, $[ - $lead_zero;
      }
    }
    push ( @rc, $rvalue );
  }
  return wantarray ? @rc : $rc[0];
}

#************************************************************

=pod

=head2 trans_blank

=over 4

=item C<< trans_blank($value) >>

Return C<< $value >> if it is defined, and an empty string if it is not.
The C<< trans_blank >> method is roughly equivalent to:

C<< return defined($value) ? $value : ''; >>

The primary purpose is to avoid warnings such as
"Use of uninitialized value in concatenation (.) or string at...".

=begin html

<table BORDER='1' CELLPADDING="10"><TR><TD><code>
use Pitonyak::StringUtil qw(trans_blank); <br/>
my $x;                                       <br/>
my $y = '7';                                 <br/>
                                             <br/>
print "($x)\n";&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;#Casues a warning message.   <br/>
print '('.trans_blank($x).")\n"; #No warning message.  <br/>
print '('.trans_blank($y).")\n"; #No warning message.  <br/>
</code></TD></TR></table>
<br/>

=end html

=item C<< trans_blank($value, $default) >>

Returns $value if it is defined with length greater than zero and C<< $default >> if it is not.
In other words, a string of length zero is treated the same as an undefined value.
A typical value for C<< $default >> is the empty string, which means C<< trans_blank >>
is rarely called with two arguments.

Return C<< $value >> if it is defined, and C<< $default >> if it is not.
The C<< trans_blank >> method is roughly equivalent to:

C<< return defined($value) ? $value : $default; >>

The primary purpose is to avoid warnings such as
"Use of uninitialized value in concatenation (.) or string at...".

=begin html

<table BORDER='1' CELLPADDING="10"><TR><TD><code>
use Pitonyak::StringUtil qw(trans_blank);  <br/>
my $x;                                        <br/>
my $y = '7';                                  <br/>
                                              <br/>
print '('.trans_blank($x, '&lt;empty&gt;').")\n"; # Print (&lt;empty&gt;)  <br/>
print '('.trans_blank($y, '&lt;empty&gt;').")\n"; # Print (7)        <br/>
</code></TD></TR></table>

=end html

=back

=cut

#************************************************************

sub trans_blank
{
  # No parameter, return undef
  if ( $#_ < 0 )
  {
    carp("Usage: trans_blank(<string>, [<return if undef>])");
    return undef;
  }

  my $default_value = "";
  $default_value = $_[1] if $#_ > 0;
  $default_value = $_[0] if defined( $_[0] ) && length( $_[0] ) > 0;
  return $default_value;
}

#************************************************************

=pod

=head2 trim_fmt

=over 4

=item C<< trim_fmt($width_to_use, @strings_to_format) >>

Trim all strings so that their length is not greater than
C<< $width_to_use >>. Strings that are too long are truncated.
The string arguments are modified.

=begin html

<table BORDER='1' CELLPADDING="10"><TR><TD><code>
use Pitonyak::StringUtil qw(trim_fmt); <br/>
my @strings = ('123456789', '123');       <br/>
trim_fmt(5, @strings);                    <br/>
print '('.join('), (', @strings).")\n";   <br/>
</code></TD></TR></table>

=end html

produces

=begin html

<table BORDER='1' CELLPADDING="10"><TR><TD><code>
(12345), (123)
</code></TD></TR></table>

=end html

=back

=cut

#************************************************************

sub trim_fmt
{
  # No parameter, return undef
  if ( $#_ < 1 )
  {
    carp("Usage: trim_fmt(<len>, <strings to format>)");
    return undef;
  }

  my $len = shift;
  my @rc;
  foreach my $str (@_)
  {
    my $slop = $len - length($str);
    $str = substr( $str, $[, $len ) if $slop < 0;
    push ( @rc, $str );
  }
  return wantarray ? @rc : $rc[0];
}

#************************************************************

=pod

=head2 trim_space

=over 4

=item C<< trim_space(@strings_to_format) >>

Remove leading and trailing white space.
The parameters are modified.

=back

=cut

#************************************************************

sub trim_space
{
  # No parameter, return undef
  if ( $#_ < 0 )
  {
    carp("Usage: trim_space(<strings to compact>");
    return undef;
  }

  for (@_)
  {
    s/^\s*//;    # Remove spaces from front
    s/\s*$//;    # Remove spaces from end
                 #
                 # The following takes longer:
                 #
                 #($_) = ($_ =~ /^\s*(.*?)\s*$/);
  }
  return wantarray ? @_ : $_[0];
}

#************************************************************

=pod

=head2 right_fmt


Modify the arguments by prepending space to force them to be the specified length.

=over 4

=item C<< right_fmt($width_to_use, @strings_to_format) >>

Modify the arguments by prepending space to force them to be the specified length.

=begin html

<UL>
  <LI>Arguments are modified.                                      </LI>
  <LI>Prepend spaces so that each argument is the requested width. </LI>
  <LI>Do not truncate arguments even if they are too long.         </LI>
</UL>
<br/>
<table BORDER='1' CELLPADDING="10">
<TR><TD>
<code>
use Pitonyak::StringUtil qw(hash_key_width right_fmt); <br/>
my %map = ('one'=>1, 'two'=> 2, 'three'=>3, 'four'=>4);   <br/>
my $width = hash_key_width(%map);                         <br/>
while ( my ($key, $value) = each(%map) ) {                <br/>
&nbsp;&nbsp;print right_fmt($width, $key)." => $value\n"; <br/>
}
</code>
</TD></TR></table>

=end html

produces

=begin html

<table BORDER='1' CELLPADDING="10">
<TR><TD>
<code>
three => 3            <br/>
&nbsp;&nbsp;one => 1  <br/>
&nbsp;&nbsp;two => 2  <br/>
&nbsp;four => 4       <br/>
</code>
</TD></TR></table>

=end html

=back

=cut

#************************************************************

sub right_fmt
{
  # No parameter, return undef
  if ( $#_ < 1 )
  {
    carp("Usage: right_fmt(<len>, <strings to format>)");
    return undef;
  }

  my $len = shift;
  my @rc;
  foreach my $str (@_)
  {
    my $slop = $len - length($str);
    $str = " " x $slop . $str if $slop > 0;
    push ( @rc, $str );
  }
  return wantarray ? @rc : $rc[0];
}

#************************************************************
#**                                                        **
#**  Input: left indent to print                           **
#**         how to grow left indent for recursive printing **
#**         Separator for items (generally "\n")           **
#**         list of things to print                        **
#**                                                        **
#**  Output: String you desire to print                    **
#**                                                        **
#**  Notes:                                                **
#**  Apart from being stuck with the output format,        **
#**  this has problems with references to references       **
#**  printing only the text REF rather than simply         **
#**  recursing the references which would not be           **
#**  that difficult.                                       **
#**                                                        **
#************************************************************

#************************************************************

=pod

=head2 smart_printer

=over 4

=item C<< smart_printer($left, $left_grow, $separator, @Things_to_print) >>

Print the argument in a pleasing way depending on the type.
The arguments are not modified. The first three arguments direct how
items are printed.

=begin html

<OL>
  <LI>Left margin when an item is printed.                 </LI>
  <LI>How to grow the left indent for recursive printing.  </LI>
  <LI>Separator used for items.                            </LI>
</OL>
<br/>
</code>

=end html

An item is printed based on its type.

=begin html

<UL>
  <LI>Left margin when an item is printed.                 </LI>
  <LI>How to grow the left indent for recursive printing.  </LI>
  <LI>Separator used for items.                            </LI>
  <LI>A scalar is printed directly.                        </LI>
  <LI>A Hash is printed as { key =&gt; value ... }.
      Each key value pair is separated by the item separator (usually a new line). </LI>
  <LI>An Array is printed as ( value ... ).
      Each value is separated by the item separator (usually a new line). </LI>
  <LI>Keys and values can also be references.              </LI>
</UL>

=end html

See C<< smart_printer_default >> to see a typical example.

=back

=cut

#************************************************************

sub smart_printer
{
  if ( $#_ < 3 )
  {
    carp("usage: smart_printer(<left>, <left_grow>, <item_seperator>, <things to print>)");
    return undef;
  }

  my $indent         = shift;
  my $indent_grow    = shift;
  my $item_separator = shift;
  my $txt            = '';
  foreach my $thing_to_print (@_)
  {
    if ( !defined($thing_to_print) )
    {
      $txt .= $indent . 'undef' . $item_separator;
    }
    else
    {
      my $ref_type = ref $thing_to_print;
      if ( !$ref_type )
      {
          $txt .= "$indent$thing_to_print$item_separator";
      }
      elsif ( $ref_type eq 'SCALAR' )
      {
        $txt .= smart_printer( $indent, $indent_grow, $item_separator,
            $$thing_to_print );
      }
      elsif ( $ref_type eq 'ARRAY' )
      {
        $txt .= "$indent($item_separator";
        foreach my $array_thing (@$thing_to_print)
        {
          $txt .= smart_printer(
              $indent . $indent_grow, $indent_grow,
              $item_separator,        $array_thing
            );
        }
        $txt .= "$indent)$item_separator";
      }
      elsif ( UNIVERSAL::isa( $thing_to_print, 'HASH' ) )
      {
        my $width = hash_key_width(%$thing_to_print);

        #
        # Remember that each hash has one universal iterator
        # recursive nesting will therefore cause stranger
        # results than a simple infinite loop.
        #
        $txt .= "$indent\{$item_separator";
        my ( $key, $value );
        while ( ( $key, $value ) = each %$thing_to_print )
        {
            $txt .= $indent
              . $indent_grow
              . left_fmt( $width, $key ) . ' => ';
            $value = '' if !defined($value);
            if ( !ref($value) )
            {
              $txt .= "$value$item_separator";
            }
            elsif ( ref($value) eq 'SCALAR' )
            {
              $txt .= smart_printer( '', $indent_grow, $item_separator, $value );
            }
            else
            {
              $txt .= $item_separator;
              $txt .= smart_printer( $indent . $indent_grow . $indent_grow,
                  $indent_grow, $item_separator, $value );
            }
        }
        $txt .= "$indent}$item_separator";
      }
      else
      {
        $txt .= "$indent$ref_type$item_separator";

        $txt .= "$indent<$item_separator";
        $txt .= smart_printer(
          $indent . $indent_grow, $indent_grow,
          $item_separator,        $$thing_to_print
        );
        $txt .= "$indent>$item_separator";
      }
    }
  }
  return $txt;
}

#************************************************************

=pod

=head2 smart_printer_default

=over 4

=item smart_printer_default(Things to print)

Simple wrapper to call C<< smart_printer >>.

=begin html
<UL>
  <LI>Items are printed with no initial left indent. </LI>
  <LI>Recursive indents using two extra spaces.      </LI>
  <LI>A new line is the item separator.              </LI>
</UL>
<br/>
<table BORDER='1' CELLPADDING="10"><TR><TD><code>
use Pitonyak::StringUtil qw(smart_printer_default);     <br/>
my %hash2 = ('a' => 'A', 'b' => 'B');                      <br/>
my @strings = ('123456789', '123', \%hash2);               <br/>
my %hash1 = ('one' => 1, 'two' => 2, 'ary' => \@strings);  <br/>
print smart_printer_default(\%hash1);                      <br/>
}
</code>
</TD></TR></table>

=end html

produces

=begin html

<table BORDER='1' CELLPADDING="10"><TR><TD><code>
{                                                       <br/>
&nbsp;&nbsp;one => 1                                    <br/>
&nbsp;&nbsp;two => 2                                    <br/>
&nbsp;&nbsp;ary =>                                      <br/>
&nbsp;&nbsp;&nbsp;&nbsp;(                               <br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;123456789           <br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;123                 <br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;{                   <br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;a => A  <br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;b => B  <br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;}                   <br/>
&nbsp;&nbsp;&nbsp;&nbsp;)                               <br/>
}
</code></TD></TR></table>

=end html

=back

=cut

#************************************************************

sub smart_printer_default
{
  return smart_printer( '', '  ', "\n", @_ );
}

#************************************************************

=pod

=head1 COPYRIGHT

Copyright 1998-2012, Andrew Pitonyak (andrew@pitonyak.org)

I Andrew Pitonyak wrote this code for my own use and I own it.
That said, you may do as you desire with this code. Use it,
change it, whatever, just don't claim that it is your own.

Also, what ever you do with the code is your own problem.
Although many of my libraries are in production use, I make
no claims to usability, suitability, or reliability.

Although you may do as you desire with the code, I do
appreciate knowing what was done with my code and
interesting changes made by you may be incorporated into
my own copies if you provide them to me.

=head1 Modification History

=head2 March 13, 1998

Version 1.00 First release

=head2 September 10, 2002

Version 1.01 Changed internal documentation to POD

=head2 January 24, 2007

Version 1.02 Updated POD and package name for use in CEFM project.
Fixed a bug where each negative number caused the
width to become smaller for the next iteration if multiple numbers
were passed at the same time.

=head2 September 16, 2008

Version 1.03 Updated POD for minor corrections.

=cut

#************************************************************

1;
