package Pitonyak::DateUtil;

#************************************************************

=head1 NAME

Pitonyak::DateUtil - Format and convert Time/Date strings

=head1 SYNOPSIS

use Pitonyak::DateUtil;


=head1 Formatting

A time is formatted based on a format string.
The number of times that a special character exists indicates the number of digits that will be used.
The format character 'YYYYMMDD.hhmmss' yields a four digit year, two digit month, two digit day,
a period, two digit hour, etc... Characters that are not considered special are inserted verbatim.
Characters that are escaped with a backslash '\' are also inserted verbatim. Use '\\' to insert a backslash.

The special format characters are as follows:

=over 4

=item h = hour (0-24)

=item m = minute (0-59)

=item s = second (0-59)

=item Y = year

In Perl, the earliest year is 1900.

=item M = Month (1-12)

Perl uses (0-11)

=item W = Month (JANUARY, FEBRUARY, ..., DECEMBER)

I really should allow these to be in other languages as well.

=item y = year day (0-364)

=item D = month day (0-30)

=item w = week day (1=Sunday, ..., 7=Saturday)

Perl uses (0=Sunday, ... , 6=Saturday)

=back

=head1 DESCRIPTION

Convert time and date information between different formats.
This can convert between text representations and an integer.

=cut

#************************************************************

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
$VERSION = '1.03';
@ISA     = qw(Exporter);
@EXPORT  = qw(
  time_date_str
  invert_time_date_str
  time_date_str_to_int
  change_time_date_str
  est_str_to_utc_str
  day_in_month
);

@EXPORT_OK = qw(
);

use Carp;
use strict;
use Time::Local;
use Pitonyak::StringUtil qw(num_with_leading_zeros);

#************************************************************

=pod

=head2  time_date_str

=over 4

=item  time_date_str($format_string, [$time_integer])

=back

Ignoring the time to make the call, both of the following calls are equivalent.

time_date_str($format_string);
time_date_str($format_string, time());

This will return a formatted string with the specified time.

=cut

#************************************************************

sub time_date_str {
    if ( $#_ < 0 ) {
        carp( 'Usage: time_date_str($format_string, [$time_integer])'
              . "\nIllegal number of parameters, 1 desired, not $#_" );
        return undef;
    }

    # If called from an object, then simply discard
    if ( $#_ >= 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::DateUtil' ) ) {
        shift;
    }
    my $fmt    = ( scalar(@_) > 0 ) ? shift: "YYYYMMDD.hhmmss";
    my $a_time = ( scalar(@_) > 0 ) ? shift: time();
    my $rv     = "";
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst );
    my $month_word;
    my ( @the_chars, $a_key );
    my @months = (
        'JANUARY',   'FEBRUARY', 'MARCH',    'APRIL',
        'MAY',       'JUNE',     'JULY',     'AUGUST',
        'SEPTEMBER', 'OCTOBER',  'NOVEMBER', 'DECEMBER'
    );
    my %fmtHash = (
        "h" => \$hour,
        "m" => \$min,
        "s" => \$sec,
        "Y" => \$year,
        "M" => \$mon,
        "W" => \$month_word,
        "D" => \$mday,
        "w" => \$wday,
        "y" => \$yday
    );
    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      ( localtime($a_time) );
    $month_word = $months[$mon];
    ++$mon;
    ++$wday;
    $year += 1900;
    @the_chars = split ( //, $fmt );

    while ( scalar(@the_chars) > 0 ) {

        #
        # Remember that $[ is the first array reference. It should be
        # zero unless some evil person changed it, but better safe than
        # sorry, so this is used in substr.
        #
        $a_key = shift @the_chars;
        if ( $a_key eq "\\" ) {
            $rv .= shift @the_chars if scalar(@the_chars) > 0;
        }
        elsif ( exists $fmtHash{$a_key} ) {

            #
            # It is a key char so how many in a row are there?
            #
            my $len = 1;
            while ( scalar(@the_chars) > 0 && $the_chars[0] eq $a_key ) {
                shift @the_chars;
                $len++;
            }
            if ( $a_key ne 'W' ) {
                $rv .= num_with_leading_zeros( $len, ${ $fmtHash{$a_key} } );
            }
            else {
                $rv .=
                  Pitonyak::StringUtil::trim_fmt( $len, ${ $fmtHash{$a_key} } );
            }
        }
        else {
            $rv .= $a_key;
        }
    }
    return $rv;
}

#************************************************************

=pod

=head2 invert_time_date_str

=over 4

=item invert_time_date_str($format_string, $formatted_time_date_string)

=back

Convert a formatted time/date string to the same output as timelocal().

returns ($sec, $min, $hours, $mday, $mon, $year) where the $year will be -1 on error.
December is mapped to 11 and the year 1900 is mapped to 0. One digit years are always
mapped to 200y and two digit years are windowed so that 00-79 map to 20xx and 80-99 map to 19xx.
Three digit years are obvious

=cut

#************************************************************

sub invert_time_date_str {
    if ( $#_ != 1 ) {
        carp('Usage: invert_time_date_str($format_string, $formatted_time_date_string)'
              . "\nIllegal number of parameters, 2 desired, not $#_" );
        return undef;
    }
    my $fmt    = shift;
    my $a_time = shift;
    my ( @the_chars, $a_key );
    my ( $tmp,       $len );
    my $sec      = 0;
    my $min      = 0;
    my $hour     = 0;
    my $mday     = 0;
    my $mon      = 0;
    my $year     = 0;
    my $tmp_time = $a_time;

    my %fmtHash = (
        "h" => \$hour,
        "m" => \$min,
        "s" => \$sec,
        "Y" => \$year,
        "M" => \$mon,
        "W" => \$mon,
        "D" => \$mday
    );

    my ( $aKey, $aVal );

    @the_chars = split ( //, $fmt );
    while ( scalar(@the_chars) > 0 ) {

        #
        # Find the next character
        #
        $a_key = shift @the_chars;
        if ( exists $fmtHash{$a_key} ) {

            #
            # It is a key char so how many in a row there are...
            #
            $len = 1;
            while ( scalar(@the_chars) > 0 && $the_chars[0] eq $a_key ) {
                shift @the_chars;
                $len++;
            }

            #
            # Now we know how many characters make up this value
            # ie, mmm means that we have three digits for minute
            # strip them out and set the value in the hash and then
            # shorten the time string.
            #
            if ( $len > length($a_time) ) {
                carp "Time string too short in invert_time_date_str($fmt, $tmp_time)";
                undef @the_chars;
            }
            else {
                if ( $a_key eq 'W' ) {
                    my @months = (
                        'JANUARY',   'FEBRUARY', 'MARCH',    'APRIL',
                        'MAY',       'JUNE',     'JULY',     'AUGUST',
                        'SEPTEMBER', 'OCTOBER',  'NOVEMBER', 'DECEMBER'
                    );
                    my $fnd = -1;
                    my $match_str = substr $a_time, $[, $len;
                    for ( my $i = 0 ; $fnd == -1 && $i < 12 ; ++$i ) {
                        $fnd = $i if $months[$i] =~ /^$match_str/;
                    }
                    ${ $fmtHash{$a_key} } = $fnd unless $fnd == -1;

                }
                else {
                    ${ $fmtHash{$a_key} } = scalar( substr $a_time, $[, $len );
                }
                $a_time = substr $a_time, $[ + $len;
                if ( $a_key eq "M" ) {

                    #
                    # It is the month which is stored as a zero offset
                    #
                    --${ $fmtHash{$a_key} };

                }
                elsif ( $a_key eq "Y" ) {

                    #
                    # What if we do not have ALL the digits then try windowing?
                    # where pre 1980 means the century is 2000.
                    #
                    if ( $len < 4 ) {

                        #
                        # We did not get all the year digits so attempt to do some
                        # intelligent processing. Less than 80 means year 20xx.
                        # Two digits between 80 and 99 inclusive are 19xx.
                        # Greater than 899 means 1xxx and otherwise we have 2xxx
                        #
                        if ( ${ $fmtHash{$a_key} } < 80 ) {
                            ${ $fmtHash{$a_key} } += 2000;
                        }
                        elsif ( $len == 2 ) { ${ $fmtHash{$a_key} } += 1900; }
                        elsif ( ${ $fmtHash{$a_key} } > 899 ) {
                            ${ $fmtHash{$a_key} } += 1000;
                        }
                        else { ${ $fmtHash{$a_key} } += 2000; }
                    }

                    #
                    # We should now have the year to full accuracy. Perl stores the
                    # year as 0 means 1900, so a current value less than 1900 should
                    # indicate an error.
                    #
                    if ( ${ $fmtHash{$a_key} } >= 1900 ) {
                        ${ $fmtHash{$a_key} } -= 1900;
                    }
                    else {
                        ${ $fmtHash{$a_key} } = -1;
                        carp "Invalid year in invert_time_date_str($fmt, $tmp_time)";
                    }
                }
            }
        }
        else {

            #
            # Eat escape character
            #
            if ( $a_key eq "\\" ) {
                shift @the_chars;
            }

            #
            # Eat a character from time string
            #
            ($a_time) = ( $a_time =~ /^.(.*)$/ );
        }
    }
    return ( $sec, $min, $hour, $mday, $mon, $year );
}

#************************************************************

=pod

=head2 time_date_str_to_int

=over 4

=item time_date_str_to_int($format_string, $formatted_time_date_string)

=back

Convert a formatted time/date string to an integer. -1 is returned on error.
The integer can be used as input to other routines.

=cut

#************************************************************

sub time_date_str_to_int {
    if ( $#_ != 1 ) {
        carp(
'Usage: time_date_str_to_int($format_string, $formatted_time_date_string)'
              . "\nIllegal number of parameters, 2 desired, not $#_" );
        return undef;
    }
    my @tda = invert_time_date_str( $_[0], $_[1] );
    my $rc  = -1;

    eval { $rc = timelocal(@tda); };
    if ( $@ || $rc < 0 ) {
        carp
"error $@ with rc = $rc Calling timelocal($tda[0], $tda[1], $tda[2], $tda[3], $tda[4], $tda[5])\nin time_date_str_to_int($_[0], $_[1])";
        $rc = -1;
    }
    return $rc;
}

#************************************************************

=pod

=head2 change_time_date_str

=over 4

=item change_time_date_str($desired_format, $current_format, $formatted_time_date_string)

=back

Change a formatted time/date string to a different format.

This is nothing more than a shortcut to using time_date_str($desired_format, time_date_str_to_int($current_format, $formatted_time_date_string));

=cut

#************************************************************

sub change_time_date_str {
    if ( $#_ != 2 ) {
        carp(
'Usage: change_time_date_str($desired_format, $current_format, $formatted_time_date_string)'
              . "\nIllegal number of parameters, 3 desired, not $#_" );
        return undef;
    }
    return time_date_str( $_[0], time_date_str_to_int( $_[1], $_[2] ) );
}


#************************************************************

=pod

=head2 day_in_month

Return a date object corresponding to a specified instance of a specific week day
in a given year and month.

=over 4

=item C<< day_in_month($year, $month, $day_of_month, $instance) >>

An example is worth a thousand words.
The call C<< day_in_month(2007, 3, 1, 2) >>
returns the second Monday in March 2007. The day of the month must be in the
range 0=Sunday to 6=Saturday. No error checking is performed to verify that
there are two Mondays in March.

=back

=cut

#************************************************************
sub day_in_month {
    if ( $#_ != 3 ) {
        carp ('Usage: day_in_month(2007, 3, 1, 2) finds second (2) Monday (1) in March (3) for 2007.');
        return undef;
    }
    if ( $_[2] < 0 || $_[2] > 6 ) {
        carp ('The desired day must be in the range of 0=Sunday to 6=Saturday.');
        return undef;
    }

    if ( $_[3] < 0 || $_[2] > 5 ) {
        carp ('The desired instance must at least be a positive number less than 6.');
        return undef;
    }

    my @days = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
    my ( $sec, $min, $hour, $mday, $month, $year ) = (0, 0, 0, 1, $_[1], $_[0]);
    my ( $wday, $yday, $isdst );
    my $desired_day = $_[2];
    my $desired_instance = $_[3];

    --$month;
    $year -= 1900;
    my $time = timelocal( $sec, $min, $hour, $mday, $month, $year );
    ($sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst) = localtime($time);
    my $day_offset = (($desired_day - $wday + 7) % 7) + ($desired_instance - 1) * 7;
    if ($day_offset + $mday > 31)
    {
        carp ("Month $month in $year does not have $desired_instance instances of day number $desired_day");
        return undef;
    }
    return timelocal( $sec, $min, $hour, $mday + $day_offset, $month, $year );
}

#************************************************************

=pod

=head2 est_str_to_utc_str

Convert a date/time string in EST to a date/time string in UTC.

=over 4

=item C<< est_str_to_utc_str($date_time, $input_fmt, $output_fmt) >>

=back

=cut

#************************************************************
sub est_str_to_utc_str
{
    my $provided_time = time_date_str_to_int($_[1], $_[0]);
    $provided_time += is_int_time_in_dst($provided_time) ? 14400 : 18000;
    time_date_str($_[2], $provided_time);
}

#************************************************************

=pod

=head2 is_int_time_in_dst

=over 4

=item C<< is_int_time_in_dst($date_time_int) >>

Return 1 if the specified date/time value is during daylight savings time in EST.
most of the U.S. will begin Daylight Saving Time at 2:00 a.m. on the second
Sunday in March and revert to standard time on the first Sunday in November.
In the U.S., each time zone switches at a different time.

At 2:00 AM on the second Sunday in March, the time immediately turns into 3:00 AM.
It is, therefore, easy to determine if these times use DST.
It is more difficult to determine when the time ends. Times from 1:00 AM until
2:00 AM are repeated, which is a very real problem. Luckily, this routine
is based on the number of seconds since a specific point in time.

=back

=cut

#************************************************************
sub is_int_time_in_dst
{
    # most of the U.S. will begin Daylight Saving Time at 2:00 a.m. on the second
    # Sunday in March and revert to standard time on the first Sunday in November.
    # In the U.S., each time zone switches at a different time.
    my ($sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst) = localtime($_[0]);

    return 0 if $month < 2 || 10 < $month;  # Before March or after Novermber is easy.
    return 1 if 2 < $month && $month < 10;  # Between April and October (inclusive) is easy.

    my $break_point;
    if ($month == 2)
    {
        # Second Monday in March.
        $break_point = day_in_month($year+1900, 3, 0, 2);
        # 3600 seconds in an hour
        # 2 hours = 7200 seconds
        # At 2:00 AM, the time moves forward one hour so we should never
        # see this time.

        return ($break_point + 7200 <= $_[0]) ? 1 : 0;
    }
    # First Sunday in November
    $break_point = day_in_month($year+1900, 11, 0, 1);

    # 3600 seconds in an hour
    # 2 hours = 7200 seconds
    # At 2:00 AM, the time moves back one hour so we should
    # see this time twice.

    return ($break_point + 7200 <= $_[0]) ? 0 : 1;
}

#************************************************************

=pod

=head1 COPYRIGHT

Copyright 1998-2012, Andrew Pitonyak

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

Version 1.01 Changed internal documentation to POD documentation. Added parameter checking.

=head2 January 24, 2012

Version 1.03 Updated copyrights. Noticed I did not document changes for 1.02.

=cut

#************************************************************

1;
