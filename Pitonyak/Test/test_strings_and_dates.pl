
=head1 NAME

test_strings_and_dates.pl - Test the StringUtil and DateUtil packages.

=head1 SYNOPSIS

Test the Pitonyak::StringUtil and Pitonyak::DateUtil packages.
From the command line, type the following:

perl -w test_strings_and_dates.pl

This should indicate that it passed.


=head1 COPYRIGHT

Copyright 1998-2002, Andrew Pitonyak (perlboy@pitonyak.org)

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 Modification History

=head2 March 13, 1998

Version 1.00 First release

=head2 September 10, 2002

Version 1.01 Changed internal documentation to POD documentation.

=cut

use Pitonyak::StringUtil
  qw(num_int_digits num_with_leading_zeros compact_space trim_space trans_blank);
use Pitonyak::DateUtil;
use strict;

#************************************************************
#**                                                        **
#**  Input: None                                           **
#**                                                        **
#**  Output: 0 if test fails, non-zero otherwise.          **
#**                                                        **
#**  Notes:                                                **
#**                                                        **
#************************************************************

sub test_StringUtil {
    my $rc = 1;
    my ( @data1, @data2, @data3, @data4, @tmp1 );
    my $index;
    my $moduleOK = 1;
    my $tmp;
    my $i;
    my $day1;

    print "(" . Pitonyak::StringUtil::trans_blank( "",  "" ) . ")";
    print "(" . Pitonyak::StringUtil::trans_blank( "",  "X" ) . ")";
    print "(" . Pitonyak::StringUtil::trans_blank( "X", "Y" ) . ")";
    print "(" . Pitonyak::StringUtil::trans_blank( "",  "00" ) . ")\n";

    if (   Pitonyak::StringUtil::trans_blank( "", "" ) ne ""
        || Pitonyak::StringUtil::trans_blank( "",  "X" )  ne "X"
        || Pitonyak::StringUtil::trans_blank( "X", "Y" )  ne "X"
        || Pitonyak::StringUtil::trans_blank( "",  "00" ) ne "00" )
    {
        $rc = 0;
        print "Pitonyak::StringUtil::trans_blank() failed\n";
    }
    else {
        print "passed Pitonyak::StringUtil::trans_blank()\n";
    }

    $moduleOK = 1;
    @data1    = (
        "here", " there ", " here and there ",
        "but  not", "   over     there    today"
    );
    @data2 =
      ( "here", "there", "here and there", "but not", "over there today" );
    compact_space(@data1);
    for ( $i = 0 ; $i < scalar(@data2) ; ++$i ) {
        if ( $data1[$i] ne $data2[$i] ) {
            $rc       = 0;
            $moduleOK = 0;
            print
"compact_space() failed at index $i data1 = ($data1[$i]), data2 = ($data2[$i])\n";
        }
    }
    if ( $moduleOK == 1 ) {
        print "passed compact_space()\n";
    }
    $moduleOK = 1;

    @data1 = (
        "here", " there ", " here and there ",
        "but  not", "   over     there    today"
    );
    @data2 = (
        "here", "there", "here and there",
        "but  not", "over     there    today"
    );
    trim_space(@data1);
    for ( $i = 0 ; $i < scalar(@data2) ; ++$i ) {
        if ( $data1[$i] ne $data2[$i] ) {
            $rc       = 0;
            $moduleOK = 0;
            print "trim_space() failed at index $i data1 = ($data1[$i]), data2 = ($data2[$i])\n";
        }
    }
    if ( $moduleOK == 1 ) {
        print "passed trim_space()\n";
    }
    $moduleOK = 1;

    @data1 = (
        -10001, -10000, -9999, -5000, -101, -100, -99,  -1,
        0,      1,      9,     10,    11,   999,  1000, 1001
    );
    @data2 = ( 6, 6, 5, 5, 4, 4, 3, 2, 1, 1, 1, 2, 2, 3, 4, 4 );
    for ( $i = 0 ; $i < scalar(@data2) ; ++$i ) {
        if ( num_int_digits( $data1[$i] ) != $data2[$i] ) {
            $rc       = 0;
            $moduleOK = 0;
            print "num_int_digits() failed at index $i data1 = ($data1[$i]), data2 = ($data2[$i])\n";
        }
    }
    if ( $moduleOK == 1 ) {
        print "passed num_int_digits()\n";
    }
    $moduleOK = 1;

    @data1 = ( -5, -4, -3, -2, -1, 5, 4, 3, 2, 1, 0, 4, 3, 2, 1 );
    @data2 = (
        -101, -103, -199, -201, -100, -101, -103, -199,
        -201, -100, 2,    103,  199,  201,  100
    );
    @data3 = (
        "-0101", "-103", "-99", "-1", "-", "00101",
        "0103",  "199",  "01",  "0",  "",  "0103",
        "199",   "01",   "0"
    );
    for ( $i = 0 ; $i < scalar(@data2) ; ++$i ) {
        $tmp = num_with_leading_zeros( $data1[$i], $data2[$i] );
        if ( $tmp ne $data3[$i] ) {
            $rc       = 0;
            $moduleOK = 0;
            print "num_with_leading_zeros() failed at index $i data1 = ($data1[$i]), data2 = ($data2[$i]), data3 = ($data3[$i]) != ($tmp)\n";
        }
    }
    if ( $moduleOK == 1 ) {
        print "passed num_with_leading_zeros()\n";
    }
    $moduleOK = 1;

    @data1 = (
        "YYYYMMDDhhmmss", "YYYMMDDhhmmss",
        "YYMMDDhhmmss",   "YYYYMMDDhhmmss",
        "YYYMMDDhhmmss",  "YYMMDDhhmmss",
        "YMMDDhhmmss",    "YY-WWW-DD"
    );
    @data2 = (
        "YYYY:MM:DD:hh:mm.ss", "\\DYYYMMDDhhmmss",
        "\\dayYYMMyDDhhmmss",  "YYYYxxzzMMDDhhmmss",
        "YYYMMDDhhmmssxtxtxt", "YYMMDDhh::::mmss",
        "YzzzzzMMDDhhmmss",    "YY-MMM-DD"
    );
    for ( $i = 0 ; $i < scalar(@data2) ; ++$i ) {
        my $now  = time();
        my $tmp1 = time_date_str( $data1[$i], $now );
        if (
            time_date_str_to_int( $data1[$i],
                time_date_str( $data1[$i], $now ) ) != time_date_str_to_int(
                $data2[$i], time_date_str( $data2[$i], $now )
                )
          )
        {
            print "time_date_str() -> time_date_str_int() does not invert for $data1[$i] and $data2[$i] on iteration $i\n";
            $moduleOK = 0;
            $rc       = 0;
        }
    }
    if ( $moduleOK == 1 ) {
        print "passed time_date_str(), invert_time_date_str(), and time_date_str_to_int()\n";
    }
    $moduleOK = 1;

    #
    # and now for some Y2K testing and other stuff. Some errors should be encountered
    #
    my $day2 = time_date_str_to_int( "YYYYMMDDhhmmss", "19991229031227" );
    @data1 = ( 99, 99, 99, 100, 100, 100, 100 );
    @data2 = ( 11, 11, 11, 0,   0,   0,   0 );
    @data3 = ( 29, 30, 31, 1,   2,   3,   4 );
    @data4 = ( "YYYYMMDDhhmmss", "YYYMMDDhhmmss", "YYMMDDhhmmss" );

    foreach my $fmt (@data4) {
        $day1 = $day2;
        for ( $i = 0 ; $i < scalar(@data1) ; ++$i ) {

            my $tmp1 = time_date_str( $fmt, $day1 );

            #print "Just took $day1 ==> $tmp1 with fmt = $fmt\n";
            @tmp1 = invert_time_date_str( $fmt, $tmp1 );
            if ( $tmp1[0] != 27 ) {
                print "seconds wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( $tmp1[1] != 12 ) {
                print "minutes wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( $tmp1[2] != 3 ) {
                print "hours wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( $tmp1[5] != $data1[$i] ) {
                print "year wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( $tmp1[4] != $data2[$i] ) {
                print "month ($tmp1[4]) wrong, expected ($data2[$i]) after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( $tmp1[3] != $data3[$i] ) {
                print "day ($tmp1[3]) wrong, expected ($data3[$i]) after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( time_date_str_to_int( $fmt, time_date_str( $fmt, $day1 ) ) !=
                $day1 )
            {
                print "time_date_str_to_int($fmt, time_date_str($fmt, $day1)) != $day1 \n";
                $moduleOK = 0;
                $rc       = 0;
            }
            $day1 += 60 * 60 * 24;
        }
    }
    if ( $moduleOK == 1 ) {
        print "passed a few Y2K tests\n";
    }
    else {
        print "failed a few Y2K tests\n";
        $moduleOK = 1;
    }

    $day2 = time_date_str_to_int( "YYYYMMDDhhmmss", "20000227031227" );
    @data1 = ( 100, 100, 100, 100, 100, 100, 100 );
    @data2 = ( 01,  01,  01,  02,  02,  02,  02 );
    @data3 = ( 27,  28,  29,  1,   2,   3,   4 );
    @data4 = ( "YYYYMMDDhhmmss", "YYYMMDDhhmmss", "YYMMDDhhmmss" );

    foreach my $fmt (@data4) {
        $day1 = $day2;
        for ( $i = 0 ; $i < scalar(@data1) ; ++$i ) {

            my $tmp1 = time_date_str( $fmt, $day1 );

            #print "Just took $day1 ==> $tmp1 with fmt = $fmt\n";
            @tmp1 = invert_time_date_str( $fmt, $tmp1 );
            if ( $tmp1[0] != 27 ) {
                print "seconds wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( $tmp1[1] != 12 ) {
                print "minutes wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( $tmp1[2] != 3 ) {
                print "hours wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( $tmp1[5] != $data1[$i] ) {
                print "year wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( $tmp1[4] != $data2[$i] ) {
                print "month ($tmp1[4]) wrong, expected ($data2[$i]) after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( $tmp1[3] != $data3[$i] ) {
                print "day ($tmp1[3]) wrong, expected ($data3[$i]) after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $moduleOK = 0;
                $rc       = 0;
            }
            if ( time_date_str_to_int( $fmt, time_date_str( $fmt, $day1 ) ) !=
                $day1 )
            {
                print "time_date_str_to_int($fmt, time_date_str($fmt, $day1)) != $day1 \n";
                $moduleOK = 0;
                $rc       = 0;
            }
            $day1 += 60 * 60 * 24;
        }
    }
    if ( $moduleOK == 1 ) {
        print "passed a few Y2K leap year tests\n";
    }
    else {
        print "failed a few Y2K leap year tests\n";
        $moduleOK = 1;
    }

    $day2 = time_date_str_to_int( "YYYYMMDDhhmmss", "20371229031227" );
    @data1 = ( 137, 137, 137, 138, 138, 138, 138 );
    @data2 = ( 11,  11,  11,  00,  00,  00,  00 );
    @data3 = ( 29,  30,  31,  1,   2,   3,   4 );
    @data4 = ( "YYYYMMDDhhmmss", "YYYMMDDhhmmss", "YYMMDDhhmmss" );
    foreach my $fmt (@data4) {
        $day1 = $day2;
        my $this_ok = 1;
        print "\nReady to convert some times around while incrementing by one day\n";
        for ( $i = 0 ; $i < scalar(@data1) && $this_ok ; ++$i ) {

            my $tmp1 = time_date_str( $fmt, $day1 );
            print "Just took $day1 seconds ==> $tmp1 with fmt = $fmt\n";
            @tmp1 = invert_time_date_str( $fmt, $tmp1 );
            if ( $tmp1[0] != 27 ) {
                print "seconds wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( $tmp1[1] != 12 ) {
                print "minutes wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( $tmp1[2] != 3 ) {
                print "hours wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( $tmp1[5] != $data1[$i] ) {
                print "year wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( $tmp1[4] != $data2[$i] ) {
                print "month ($tmp1[4]) wrong, expected ($data2[$i]) after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( $tmp1[3] != $data3[$i] ) {
                print "day ($tmp1[3]) wrong, expected ($data3[$i]) after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( time_date_str_to_int( $fmt, time_date_str( $fmt, $day1 ) ) !=
                $day1 )
            {
                print "time_date_str_to_int($fmt, time_date_str($fmt, $day1)) != $day1 \n";
                $this_ok = 0;
            }
            $day1 += 60 * 60 * 24;
        }
        if ( $this_ok == 0 ) {
            $moduleOK = 0;
        }
    }
    if ( $moduleOK == 1 ) {
        print "year 2038 tests passed\n";
    }
    else {
        print "failed a few year 2038 tests as expected\n";
        $moduleOK = 1;
    }






    # These tests will fail for a two digit year because a two digit year such as 25 is not considered say 2125.


    my @years;
    $day2 = time_date_str_to_int( "YYYYMMDDhhmmss", "20371229031227" );
    @data1 = ( 137, 140, 157, 174, 191, 208, 225, 278, 331, 356 );
    @data2 = (  11,  11,  11,  11,  11,  11,  11,  10,  10,  10 );
    @data3 = (  29,  28,  24,  20,  16,  12,   8,  25,  13,   6 );
    @years = (   3,  17,  17,  17,  17,  17,  53,  53,  25,  25 );
    @data4 = ( "YYYYMMDDhhmmss", "YYYMMDDhhmmss" );
    foreach my $fmt (@data4) {
        $day1 = $day2;
        my $this_ok = 1;
        print "\nReady to convert some times around while incrementing by one 17 years\n";
        for ( $i = 0 ; $i < scalar(@data1) && $this_ok ; ++$i ) {

            my $tmp1 = time_date_str( $fmt, $day1 );
            print "Just took $day1 seconds ==> $tmp1 with fmt = $fmt ready to add $years[$i] years\n";
            @tmp1 = invert_time_date_str( $fmt, $tmp1 );
            if ( $tmp1[0] != 27 ) {
                print "seconds wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( $tmp1[1] != 12 ) {
                print "minutes ($tmp1[1]) wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( $tmp1[2] != 3 ) {
                print "hours ($tmp1[2]) wrong after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( $tmp1[5] != $data1[$i] ) {
                print "year ($tmp1[5]) wrong , expected ($data1[$i]) after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( $tmp1[4] != $data2[$i] ) {
                print "month ($tmp1[4]) wrong, expected ($data2[$i]) after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( $tmp1[3] != $data3[$i] ) {
                print "day ($tmp1[3]) wrong, expected ($data3[$i]) after invert_time_date_str($fmt, time_date_str($fmt, $day1))\n";
                $this_ok = 0;
            }
            if ( time_date_str_to_int( $fmt, time_date_str( $fmt, $day1 ) ) != $day1 )
            {
                print "time_date_str_to_int($fmt, time_date_str($fmt, $day1)) != $day1 \n";
                $this_ok = 0;
            }
            $day1 += $years[$i] * 60 * 60 * 24 * 365;
        }
        if ( $this_ok == 0 ) {
            $moduleOK = 0;
        }
    }
    if ( $moduleOK == 1 ) {
        print "year 2256 tests passed... Probably not entirely accurate because of future leap second issues.\n";
    }
    else {
        print "failed a few year 2256 tests\n";
        $moduleOK = 1;
    }














    return $rc;
}

my $rc = test_StringUtil();

print "Passed\n" if $rc == 1;
print "Failed\n" if $rc == 0;
