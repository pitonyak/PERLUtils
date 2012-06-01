

#************************************************************

=head1 NAME

find_dup_files.pl - Find duplicate files based on size and CRC.

=head1 DESCRIPTION


=begin html
<p><code>
$ perl -w find_dup_files.pl .<br/>
<br/>
CHECKING: ./*<br/>
.............................................<br/>
1 Possible Dup: ./Pitonyak/Test/log_cfg.xml<br/>
.....<br/>
2 Possible Dup: ./Pitonyak/Test/testit.cfg<br/>
................<br/>
3 Possible Dup: ./.git/logs/refs/heads/master<br/>
<br/>
<br/>
***   CRC32    SIZE    Fullpath<br/>
*** 3855569953  1539  ./Pitonyak/log_cfg.xml<br/>
*** 3855569953  1539  ./Pitonyak/Test/log_cfg.xml<br/>
*** 2042401473  2147  ./Pitonyak/testit.cfg<br/>
*** 2042401473  2147  ./Pitonyak/Test/testit.cfg<br/>
*** 1838313830  215  ./.git/logs/HEAD<br/>
*** 1838313830  215  ./.git/logs/refs/heads/master<br/>
<br/>
<br/>
Searched 69 files and found 3 duplicate files<br/>
</code></p>

=end html


=cut

#************************************************************


# Before I ccould use this, I had to install the
# CRC32 code using cpan.

use File::Basename;
use IO::File;
use strict;
use Pitonyak::SafeGlob qw(glob_spec_from_path);
use String::CRC32;
use File::stat;

my $glob    = new Pitonyak::SafeGlob();
my $recurse = 1;

$glob->case_sensitive(0);
$glob->recurse($recurse);
$glob->return_dirs(0);
$glob->return_files(1);

my $handle  = new IO::File;
my $verbose = 0;

my $file_name;
my $crc;

# It is a pretty safe bet that the full name is unique.
# This hash will reference data based on the full name.
# The data will be stored as follows:
# $base_hash{$fullname}->{CRC32, BASENAME, LEN, DIR}
my %base_hash;

# The crc_hash contains an array of full names for each CRC
my %crc_hash;

# These next variables should really be local, but I am too lazy to
# rewrite the code when I know that it works.
my $href;                      #Temp hash reference with CRC info.
my ( $name, $path, $suffix );  #Break out file information.
my @suffixlist;                #Sent to fileparse().
my $sb;                        #File stat information.

my $total_files   = 0; #total files checked.
my $dup_files     = 0; #number of duplicate files.
my $suspect_files = 0; #number of files with duplicate CRC.
my $last_dup      = 0; #file number of last duplicate

sub CheckDups($)
{
  my $file_name = shift;

  print "\nCHECKING: $file_name\n";

  foreach $file_name ( $glob->glob_spec_from_path($file_name) )
  {
    if ( $handle->open("< $file_name") )
    {
      ++$total_files;
      $sb  = stat($file_name);
      $crc = crc32($handle);
      $handle->close();
      ( $name, $path, $suffix ) = fileparse( $file_name, @suffixlist );
      print "$path  $name \n" if $verbose;
      $href                  = {};
      $href->{'BASENAME'}    = $name;
      $href->{'DIR'}         = $path;
      $href->{'CRC'}         = $crc;
      $href->{'SIZE'}        = $sb->size;
      $base_hash{$file_name} = $href;

      if ( !defined( $crc_hash{$crc} ) )
      {
        $crc_hash{$crc} = ();
        print ".";
      }
      else
      {
        print "\n" unless $last_dup + 1 == $total_files;
        $last_dup = $total_files;
        ++$suspect_files;
        print "$suspect_files Possible Dup: $file_name\n";
      }
      push( @{ $crc_hash{$crc} }, $file_name );
    }
    else
    {
      print "Unable to open $file_name\n";
    }
  }
}

sub print_results
{
  if ( $suspect_files > 0 )
  {
    print "\n\n***   CRC32    SIZE    Fullpath\n";
    foreach $crc ( keys(%crc_hash) )
    {

      # Check to see if this CRC has been used more than once.
      if ( scalar( @{ $crc_hash{$crc} } ) > 1 )
      {
        # It has, so check the sizes of each of these files.
        # If the size AND the CRC are the same, then consider them the same.
        # Check this by now creating a hash based on the file size.
        # For each size, store an array of file names.
        my %size_hash;
        my $sz;
        foreach $file_name ( @{ $crc_hash{$crc} } )
        {
          $sz = $base_hash{$file_name}->{'SIZE'};
          $size_hash{$sz} = () unless defined( $size_hash{$sz} );
          push( @{ $size_hash{$sz} }, $file_name );
        }
        foreach $sz ( keys(%size_hash) )
        {
          if ( scalar( @{ $size_hash{$sz} } ) > 1 )
          {
            # Remember, if two files are the same, only one is
            # considered a duplicate.
            $dup_files += scalar( @{ $size_hash{$sz} } ) - 1;
            foreach ( @{ $size_hash{$sz} } )
            {
              print "*** $crc  $sz  $_\n";
            }
          }
        }
      }
    }
  }
  print "\n\nSearched $total_files files and found $dup_files duplicate files\n\n";
}

my $search_path;
foreach (@ARGV)
{
  if (/-v/)
  {
    $verbose = 1 - $verbose;
  }
  elsif (/-s/)
  {
    $recurse = 1 - $recurse;
    $glob->recurse($recurse);
  }
  else
  {
    s/\\ / /;
    if (-d)
    {
      # This is a directory...
      if (/\/$/)
      {
        $search_path = "$_*";
      }
      else
      {
        $search_path = "$_/*";
      }
    }
    else
    {
      $search_path = $_;
    }
    CheckDups($search_path);
  }
}
print_results();



#************************************************************

=pod

=head1 COPYRIGHT

Copyright 2010-2012, Andrew Pitonyak (perlboy@pitonyak.org)

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


=head2 May 31, 2012

Pushed to github.

=cut

#************************************************************

