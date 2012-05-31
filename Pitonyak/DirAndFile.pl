package Pitonyak::DirAndFile;

#************************************************************

=head1 NAME

Pitonyak::DirAndFile - General Directory utilities.

=head1 SYNOPSIS

Given two files or directories, set the attributes on the second argument to match those on the first.
In other words, given the arguments file1.txt and file2.txt, the attributes on file2.txt are set to match
those on file1.txt.

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

=head1 DESCRIPTION

=cut

#************************************************************

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = '1.00';
@ISA    = qw(Exporter);
@EXPORT = qw(
);

@EXPORT_OK = qw(
);

use Carp;
use strict;
use File::stat;
use Fcntl ':mode';

sub set_stat
{
  if ($#_ < 1)
  {
    die("Expect <dest> <stat_object>");
  }
  my $dst_name = shift;

  if ((! -f $dst_name) && (! -d $dst_name))
  {
    carp ("Source file $dst_name does not exist");
    return undef;
  }

  my $src_stat = shift;

  my $dst_stat = stat($dst_name);
  if ( !defined($dst_stat) )
  {
    carp ("Failed to stat destination file $dst_stat because $!");
    return undef;
  }

  if (($src_stat->uid != $dst_stat->uid) || ($src_stat->gid != $dst_stat->gid))
  {
    if (force_file_writable($dst_stat->mode, $dst_name))
    {
      $dst_stat = stat($dst_name);
    }
    print "UID or GUID differ ".$src_stat->uid.' <=> '.$dst_stat->uid." and ".$src_stat->gid.' <=> '.$dst_stat->gid."\n";
    chown($src_stat->uid, $src_stat->gid, $dst_name);
  }

  if (($src_stat->atime != $dst_stat->atime) || ($src_stat->mtime != $dst_stat->mtime))
  {
    if (force_file_writable($dst_stat->mode, $dst_name))
    {
      $dst_stat = stat($dst_name);
    }
    print " differ atime ".$src_stat->atime.' <=> '.$dst_stat->atime." or mtime ".$src_stat->mtime.' <=> '.$dst_stat->mtime." \n";
    utime($src_stat->atime, $src_stat->mtime, $dst_name);
  }

  if ($src_stat->mode != $dst_stat->mode)
  {
    print "modes differ ".$src_stat->mode."  ".$dst_stat->mode." \n";
    chmod($src_stat->mode, $dst_name);
  }

  #if ($src_stat->ctime != $dst_stat->ctime)
  #{
  #  print " differ ctime ".$src_stat->ctime."  ".$dst_stat->ctime." \n";
  #  #chmod($src_stat->mode, $dst_name);
  #}
}

#************************************************************

=pod

=head2 match_file_or_dir_attributes

=over 4

=item C<< match_file_or_dir_attributes($src, $dst) >>

The source and destination contain the full path to the source and
destination file or directory. On exit, the attributes on the source will
be the same as on the destination.

=begin html

<table BORDER='1' CELLPADDING="10">
<TR><TH>Attribute</TH><TH>Checked</TH><TH>Description</TH></TR>
<TR><TD>dev      </TD>No <TD></TD><TD>device number of filesystem                    </TD></TR>
<TR><TD>ino      </TD>No <TD></TD><TD>inode number                                   </TD></TR>
<TR><TD>mode     </TD>No <TD></TD><TD>file mode  (type and permissions)              </TD></TR>
<TR><TD>nlink    </TD>No <TD></TD><TD>number of (hard) links to the file             </TD></TR>
<TR><TD>uid      </TD>Yes<TD></TD><TD>numeric user ID of file's owner                </TD></TR>
<TR><TD>gid      </TD>Yes<TD></TD><TD>numeric group ID of file's owner               </TD></TR>
<TR><TD>rdev     </TD>No <TD></TD><TD>the device identifier (special files only)     </TD></TR>
<TR><TD>size     </TD>No <TD></TD><TD>total size of file, in bytes                   </TD></TR>
<TR><TD>atime    </TD>Yes<TD></TD><TD>last access time in seconds since the epoch    </TD></TR>
<TR><TD>mtime    </TD>Yes<TD></TD><TD>last modify time in seconds since the epoch    </TD></TR>
<TR><TD>ctime    </TD>No <TD></TD><TD>inode change time in seconds since the epoch   </TD></TR>
<TR><TD>blksize  </TD>No <TD></TD><TD>preferred block size for file system I/O       </TD></TR>
<TR><TD>blocks   </TD>No <TD></TD><TD>actual number of blocks allocated              </TD></TR>

=end html

No attempt is made to change access on the containing directory so that
the attributes of the differening files can be changed.

=back

=cut

#************************************************************

sub match_file_or_dir_attributes
{
  if ($#_ < 1)
  {
    die("Expect <source> <dest>");
  }
  my $src_name = shift;
  my $dst_name = shift;
  if ((! -f $src_name) && (! -d $src_name))
  {
    carp ("Source file $src_name does not exist");
    return undef;
  }
  if ((! -f $dst_name) && (! -d $dst_name))
  {
    carp ("Source file $dst_name does not exist");
    return undef;
  }

  my $src_stat = stat($src_name); # or carp ("failed to stat $src_name because $!");
  if ( !defined($src_stat) )
  {
    carp ("Failed to stat source file $src_name because $!");
    return undef;
  }

  my $dst_stat = stat($dst_name);
  if ( !defined($dst_stat) )
  {
    carp ("Failed to stat destination file $dst_stat because $!");
    return undef;
  }

  if (($src_stat->uid != $dst_stat->uid) || ($src_stat->gid != $dst_stat->gid))
  {
    if (force_file_writable($dst_stat->mode, $dst_name))
    {
      $dst_stat = stat($dst_name);
    }
    print "UID or GUID differ ".$src_stat->uid.' <=> '.$dst_stat->uid." and ".$src_stat->gid.' <=> '.$dst_stat->gid."\n";
    chown($src_stat->uid, $src_stat->gid, $dst_name);
  }

  if (($src_stat->atime != $dst_stat->atime) || ($src_stat->mtime != $dst_stat->mtime))
  {
    if (force_file_writable($dst_stat->mode, $dst_name))
    {
      $dst_stat = stat($dst_name);
    }
    print " differ atime ".$src_stat->atime.' <=> '.$dst_stat->atime." or mtime ".$src_stat->mtime.' <=> '.$dst_stat->mtime." \n";
    utime($src_stat->atime, $src_stat->mtime, $dst_name);
  }

  if ($src_stat->mode != $dst_stat->mode)
  {
    print "modes differ ".$src_stat->mode."  ".$dst_stat->mode." \n";
    chmod($src_stat->mode, $dst_name);
  }

  #if ($src_stat->ctime != $dst_stat->ctime)
  #{
  #  print " differ ctime ".$src_stat->ctime."  ".$dst_stat->ctime." \n";
  #  #chmod($src_stat->mode, $dst_name);
  #}
}

#************************************************************

=pod

=head2 force_file_writable

=over 4

=item C<< force_file_writable($current_mode, $path) >>

The first argument, C<< $current_mode >>, is the current mode of the file.

The second argument, C<< $parth >>, is the full path to the file.

On exit, the file or directory will be readable and writable.

=back

=cut

#************************************************************

sub force_file_writable
{
  if (($_[0] & (S_IRUSR | S_IWUSR)) ne (S_IRUSR | S_IWUSR))
  {
    chmod ((S_IRUSR | S_IWUSR | $_[0]), $_[1]);
    return 1;
  }
  return 0;
}

match_file_or_dir_attributes(@ARGV);
