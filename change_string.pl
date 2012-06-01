#!/usr/local/bin/perl

#************************************************************

=head1 NAME

change_string.pl - Find text in files and change the text to something else.

=head1 DESCRIPTION

If you have some text in a bunch of files, use this to find occurrences of the text and change it to something else.
Sadly, you must change the code to do this. Modify the C<< %initial_change_list >> variable to contain the before and after text.

=head2 Parameters

=over 4

=item  -s        : Turn recursion on so that subdirectories are searched.

=item  file-spec : Enter one or more file specs, complete with path. On Linux, be careful, because the command shell will automatically expand file specs, which is not what you want. 

=back

=head2 Example Usage

C<< perl -s "/home/bob/*.txt" >>


=cut

#************************************************************


use strict;
use Carp;
use File::Basename;

#
# this will map everything in the key list to the value list. The problem
# is that I can not use certain characters in regular expressions so I start
# with a list of bad (or funky) characters, and then I map all of these in
# the keys to be preceded by a backslash.
#

my $verbose_level = 4;
my $do_copy = 1;           # Overwrite the original file?
my $recurse = 0;
my @file_specs = ();


# List of text to change
# Make your changes here
my %initial_change_list = (
        "Andy Pitonyak"     =>  "Andrew Pitonyak",
        'class$('     =>  "silly_class(",
#        "cat "              =>  "Tastey Food ",
    );


my $funky_chars = "\\()\$";
my @funky_chars = split(//, $funky_chars);



#************************************************************
#**                                                        **
#**  Input : Path                                          **
#**                                                        **
#**  Output: None.                                         **
#**                                                        **
#**  Notes : Go through the file and change the text.      **
#**                                                        **
#************************************************************

sub change_text($)
{
   my $in_file = shift;

   # Build a list of change text that does not contain special characters
   #
   my %change_list;
   while (my ($old_text, $new_text) = each %initial_change_list)
   {
       my $original_old_text = $old_text;
       foreach (@funky_chars)
       {
           my $bad_char = "\\$_";
           $old_text =~ s/$bad_char/$bad_char/g;
       }

       if ($verbose_level > 3)
       {
           print "Mapped $original_old_text ==> $old_text\n";
       }

       $change_list{$old_text} = $new_text;
   }
   if ($verbose_level > 2) {
       foreach (keys %change_list) {

           print "map $_ to $change_list{$_}\n";
       }
   }


   my @file_list = glob($_);
   if (not open(INF,"<$in_file"))
   {
       print "Can not open file ($in_file) because: $!\n";
   }
   else
   {
      my $out_file = "$in_file.new";
      if (not open(OUTF,">$out_file"))
      {
          close(INF);
          print "Can not open file ($out_file) because: $!\n";
      }
      else
      {
         print "Opened $in_file and $out_file\n";
         my $changed = 0;
         my $line;
         my $orig_line;
         while ($line = <INF>)
         {
             $orig_line = $line;
             while (my ($old_text, $new_text) = each %change_list)
             {
                 $line =~ s/$old_text/$new_text/g;
             }
             if ($orig_line ne $line)
             {
                 $changed = 1;

                 if ($verbose_level > 1)
                 {
                     print "($in_file) $orig_line ==> $line"
                 }
             }
             print OUTF $line;
         }
         close(INF);
         close(OUTF);
         if ($changed)
         {
             print "$in_file changed\n";
             if ($do_copy)
             {
                 rename $in_file, "$in_file.bak";
                 rename $out_file, $in_file;
             }
         }
         else
         {
             unlink $out_file;
             print "$out_file deleted, no changed made\n"
         }
      }
   }
}

#************************************************************
#**                                                        **
#**  Input : Path                                          **
#**          Include files (0 or 1)                        **
#**          Include dirs  (0 or 1)                        **
#**          List of regular expressions to match          **
#**                                                        **
#**  Output: A list of matching files                      **
#**                                                        **
#**  Notes :                                               **
#**                                                        **
#************************************************************

sub glob_regex {

    my $path      = shift;
    my $use_files = shift;
    my $use_dirs  = shift;
    my @file_list;
    my @ret_list = ();
    if (!opendir(IND, $path))
    {
        carp "Failed to open $path because $!";
    }
    else
    {
        my $regex = scalar(@_) ? join('|', @_) : '';
        @file_list = grep {/$regex/} readdir(IND);
        closedir(IND);

        push(@ret_list, grep($_ ne '.' && $_ ne '..', grep(-d "$path/$_", @file_list))) if $use_dirs;
        push(@ret_list, grep(-e "$path/$_", @file_list)) if $use_files;
    }
    return @ret_list;
}


#************************************************************
#**                                                        **
#**  Input : Path                                          **
#**          Include files (0 or 1)                        **
#**          Include dirs  (0 or 1)                        **
#**          List of file specs                            **
#**                                                        **
#**  Output: A list of matching files                      **
#**                                                        **
#**  Notes : This has not been carefully tested for all    **
#**          cases. Just a few cases                       **
#**                                                        **
#************************************************************

sub glob_spec {

    my $path      = shift;
    my $use_files = shift;
    my $use_dirs  = shift;
    my @reg_list  = @_;
    foreach (@reg_list) {
        s/\./\\./g;
        s/\^/\\^/g;
        s/\$/\\\$/g;
        s/\?/./g;
        s/\*/.*/g;
        $_= "^$_\$";
    }
    return glob_regex($path, $use_files, $use_dirs, @reg_list);
}


sub print_it($)
{
   my $name = shift;
   print "file = $name\n";
}


#************************************************************
#**                                                        **
#**  Input: $subName : A routine to call for each file     **
#**         @_       : a list of file specs                **
#**                                                        **
#**  Output: None                                          **
#**                                                        **
#**  Notes:                                                **
#**                                                        **
#************************************************************

sub call_sub_each_file
{
   my $subName = shift;

   foreach my $spec_with_path (@_)
   {
      my ($file_spec, $path, $suffix) = fileparse($spec_with_path);
      my @fileList = glob_spec($path, 1, 0, $file_spec);
      foreach my $fileName (@fileList)
      {
          my $full_path = "$path$fileName";
          eval "$subName(\$full_path)";
      }
   }
}


#************************************************************
#**                                                        **
#**  Input: $subName  : A routine to call for each file    **
#**         $startDir : Starting directory                 **
#**         $dirSpec  : spec for the directory             **
#**         $fileSpec : file spec to use                   **
#**                                                        **
#**  Output: None                                          **
#**                                                        **
#**  Notes:                                                **
#**                                                        **
#************************************************************

sub call_sub_each_dir_and_file($$$$)
{
   my $subName  = shift;
   my $startDir = shift;
   my $dirSpec  = shift;
   my $fileSpec = shift;

   my @dirList;
   my $aDir;

   call_sub_each_file($subName, "$startDir/$fileSpec");
   my @dir_list = glob_spec($startDir, 0, 1, $dirSpec);
   foreach my $dir_name (@dir_list)
   {
      if ($dir_name ne '.' && $dir_name ne '..')
      {
         call_sub_each_dir_and_file($subName, "$startDir/$dir_name", $dirSpec, $fileSpec);
      }
   }
}


# First, see if should recurse
# and build a list of requested file specs!
foreach (@ARGV)
{
   if (/^-s$/i)
   {
      $recurse = 1;
   }
   else
   {
      push(@file_specs, $_);
   }
}


if (!$recurse)
{
#   call_sub_each_file('print_it', @file_specs);
   call_sub_each_file('change_text', @file_specs);
}
else
{
   foreach my $spec_with_path (@file_specs)
   {
      my ($file_spec, $path, $suffix) = fileparse($spec_with_path);
#      call_sub_each_dir_and_file('print_it', $path, '*', $file_spec);
      call_sub_each_dir_and_file('change_text', $path, '*', $file_spec);
   }
}



