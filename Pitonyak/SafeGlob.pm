package Pitonyak::SafeGlob;

#************************************************************

=head1 NAME

Pitonyak::SafeGlob - Regular expressions and file specs for finding files and directories.

=head1 SYNOPSIS

File and directory scanning based on regular expressions.

=begin html
<p><code>

use Pitonyak::SafeGlob;                                              <br/>
                                                                     <br/>
my @full_specs = ('c:\*.txt', 'C:\Andy\Dev\Perl\Pitonyak\*.p?');     <br/>
my @file_specs = ('*.pl', '*.pm');                                   <br/>
my @file_regs  = ('.*\.pl$', '.*\.pm$');                             <br/>
my @files;                                                           <br/>
                                                                     <br/>
my $g = new Pitonyak::SafeGlob;                                      <br/>
                                                                     <br/>
$g->case_sensitive(1);                                               <br/>
$g->return_dirs(0);                                                  <br/>
$g->return_files(1);                                                 <br/>
foreach ($g->glob_spec_from_path(@full_specs))                       <br/>
{                                                                    <br/>
  # Full path to file returned.                                      <br/>
  print "spec from path => $_\n";                                    <br/>
}                                                                    <br/>
                                                                     <br/>
foreach ($g->glob_spec('c:\Andy\Dev\Perl\Pitonyak', @file_specs))    <br/>
{                                                                    <br/>
  print "glob_spec => $_\n";                                         <br/>
}                                                                    <br/>
                                                                     <br/>
foreach ($g->glob_regex('c:\Andy\Dev\Perl\Pitonyak', @file_regs))    <br/>
{                                                                    <br/>
  print "glob_regex => $_\n";                                        <br/>
}

</code></p>

=end html


=head1 DESCRIPTION

There was a time when glob() returned an empty list if there were too many files in a directory.
This module avoids this problem.

In the following routines, if the C<$use_case> parameter evaluates to true,
then matching will be done in a case sensitive manner. Matches are not
case sensitive otherwise.

In the following routines, if the C<$include_files> parameter evaluates to true,
then files that match will be returned.

In the following routines, if the C<$include_dirs> parameter evaluates to true,
then directories that match will be returned.

=cut

#************************************************************

use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
$VERSION   = '1.04';
@ISA       = qw(Exporter);
@EXPORT    = qw();
@EXPORT_OK = qw(
  case_sensitive
  copy
  new
  get_class_attribute
  glob_regex
  glob_regex_dirs
  glob_regex_files
  glob_spec
  glob_spec_from_path
  recurse
  return_dirs
  return_files
);

use strict;
use Carp;
use File::Basename;
use File::Spec;
use Pitonyak::DeepCopy qw(deep_copy);

my %initial_attributes = (
  'recurse'        => 0,
  'return_dirs'    => 1,
  'return_files'   => 1,
  'case_sensitive' => 1,
);

#************************************************************

=pod

=head2 new

=over 4

=item new()

Note that this is written in such a manner that it can be inherited.
Also note that it is written such that $obj2 = $obj1->new() is valid!

=back

=cut

#************************************************************

sub new {
  my $self = shift;
  my $objref = bless {}, ref($self) || $self;
  $objref->initialize();
  if ( ref($self) ) {
    $objref->copy($self);
  }
  return $objref;
}

#************************************************************
#**                                                        **
#**  Input : None.                                         **
#**                                                        **
#**  Output: None.                                         **
#**                                                        **
#**  Notes : Not really needed                             **
#**                                                        **
#************************************************************

sub DESTROY {
}

#************************************************************

=pod

=head2 case_sensitive

=over 4

=item case_sensitive([0|1])

Set the attribute if a parameter is present.

Return the state of the parameter.

=back

=cut

#************************************************************

sub case_sensitive {
  return get_class_attribute( @_, 'case_sensitive' );
}

#************************************************************

=pod

=head2 copy

=over 4

=item copy($object)

Make a copy of this object

C<$obj1->copy($obj2)> is the same as C<$obj1 = $obj2>.

=back

=cut

#************************************************************

sub copy {
  foreach my $key ( keys %initial_attributes )
  {
    if ( ref( $_[1]->{$key} ) )
    {
      # If I simply copy it over then we both reference the same thing!
      $_[0]->{$key} = deep_copy( $_[1]->{$key} );
    }
    else
    {
      $_[0]->{$key} = $_[1]->{$key};
    }
  }
}

#************************************************************
#**                                                        **
#**  Input : None.                                         **
#**                                                        **
#**  Output: None.                                         **
#**                                                        **
#**  Notes : Initialize the data structure.                **
#**                                                        **
#************************************************************

sub initialize {
  foreach my $key ( keys %initial_attributes )
  {
    if ( ref( $initial_attributes{$key} ) )
    {
      # If I simply copy it over then we both reference the same thing!
      $_[0]->{$key} = deep_copy( $initial_attributes{$key} );
    }
    else
    {
      $_[0]->{$key} = $initial_attributes{$key};
    }
  }
}

#************************************************************

=pod

=head2 get_class_attribute

Remember that the call C<$obj-E<gt>method(@parms)> is the same as
C<method($obj, @parms)>.

=over 4

=item SafeGlob::get_class_attribute($attribute_name)

If there is only one paramter, the first parameter is
assumed to be an attribute name and the default attribute value
is returned.

=item $obj->get_class_attribute($attribute_name)

If there are two parameters, then the first parameter is assumed
to be a C<SafeGlob> object and the second parameter is
assumed to be an attribute name.
The attribute value for the object is returned.

=item $obj->get_class_attribute($attribute_name, $attribute_value)

If three parameters are given, then the first parameter is the object,
the second parameter
is used to set a new value for the attribute,
and the third parameter is the attribute name,
The attribute value is then returned.

=back

=cut

#************************************************************

sub get_class_attribute {
  return $initial_attributes{ $_[0] } if $#_ == 0;
  return $_[0]->{ $_[1] } if $#_ == 1;
  $_[0]->{ $_[2] } = $_[1];
  return $_[1];
}

#************************************************************

=pod

=head2 glob_regex

=over 4

=item glob_regex($path, [@regular_expressions])

=back

All regular expressions are assumed to follow the path.
This returns the files and/or directories that match the regular expression in the given path.
The directory tree is recursed if the recursion flag is set.

=cut

#************************************************************

sub glob_regex {
  if ( $#_ < 1 )
  {
    carp('glob_regex_dirs expected at least two parameters, a path and regular expression');
  }

  my $obj;
  if ( UNIVERSAL::isa( $_[0], 'Pitonyak::SafeGlob' ) )
  {
    $obj = shift;
    if ( $#_ < 1 )
    {
      carp('glob_regex_dirs expected at least two parameters, a path and regular expression');
    }
  }
  else
  {
    $obj = new Pitonyak::SafeGlob();
  }
  my @return_values = ();

  push ( @return_values, $obj->glob_regex_files(@_) ) if $obj->return_files();
  push ( @return_values, $obj->glob_regex_dirs(@_) )  if $obj->return_dirs();
  return @return_values;
}

#************************************************************

=pod

=head2 glob_regex_dirs

=over 4

=item glob_regex_dirs($path, [@dir_regular_expressions])

=back

All regular expressions are assumed to follow the path.
This returns the directories that match the regular expression in the given path.
Recursion is done if the recurse parameter is set.

=cut

#************************************************************

sub glob_regex_dirs
{
  if ( $#_ < 1 )
  {
    carp('glob_regex_dirs expected at least two parameters, a path and regular expression');
  }

  my $obj;
  if ( UNIVERSAL::isa( $_[0], 'Pitonyak::SafeGlob' ) )
  {
    $obj = shift;
    if ( $#_ < 1 )
    {
      carp('glob_regex_dirs expected at least two parameters, a path and regular expression');
    }
  }
  else
  {
    $obj = new Pitonyak::SafeGlob();
  }

  my @dir_list;
  my $path = shift;
  if ( !opendir( IND, $path ) ) {
    carp "Failed to open $path because $!";
  }
  else
  {
    my @orig_dir_list = grep( -d File::Spec->catfile($path, $_), readdir(IND) );
    closedir(IND);

    # Remove the directories '.' and '..'
    @orig_dir_list = grep( $_ ne '.' && $_ ne '..', @orig_dir_list );

    # Now match the regular expression
    my $regex = scalar(@_) ? join ( '|', @_ ) : '';
    @dir_list = grep { /$regex/i } @orig_dir_list if not $obj->case_sensitive();
    @dir_list = grep { /$regex/ } @orig_dir_list  if $obj->case_sensitive();

    # Should we recurse the directory tree?
    if ( $obj->recurse() )
    {
      foreach my $a_dir (@orig_dir_list)
      {
        push ( @dir_list, map { File::Spec->catfile($a_dir, $_) } $obj->glob_regex_dirs( File::Spec->catfile($path, $a_dir), $regex ) );
      }
    }
  }

  return @dir_list;
}

#************************************************************

=pod

=head2 glob_regex_files

=over 4

=item glob_regex_files($path, [@file_regular_expressions])

=back

All regular expressions are assumed to follow the path.
This returns the files that match the regular expression in the given path.
Recursion is done if the recurse parameter is set.

=cut

#************************************************************

sub glob_regex_files
{
  if ( $#_ < 1 )
  {
    carp('glob_regex_files expected at least two parameters, a path and regular expression');
  }

  my $obj;
  if ( UNIVERSAL::isa( $_[0], 'Pitonyak::SafeGlob' ) )
  {
    $obj = shift;
    if ( $#_ < 1 )
    {
      carp('glob_regex_files expected at least two parameters, a path and regular expression');
    }
  }
  else
  {
    $obj = new Pitonyak::SafeGlob();
  }

  my @file_list;
  my $path = shift;

  if ( !opendir( IND, $path ) )
  {
    carp "Failed to open $path because $!";
  }
  else
  {
    # match the regular expression
    my $regex = scalar(@_) ? join ( '|', @_ ) : '';

    @file_list = grep { /$regex/i && -f File::Spec->catfile($path, $_) } readdir(IND) if not $obj->case_sensitive();
    @file_list = grep { /$regex/  && -f File::Spec->catfile($path, $_) } readdir(IND) if $obj->case_sensitive();
    closedir(IND);

    # Should we recurse the directory tree?
    if ( $obj->recurse() )
    {
      foreach my $a_dir ( $obj->glob_regex_dirs( $path, '.*' ) )
      {
        my $path_dir = File::Spec->catfile($path, $a_dir);
        if ( !opendir( IND, $path_dir ) )
        {
          carp "Failed to open $path_dir because $!";
        }
        else
        {
          # match the regular expression
          push ( @file_list, map { File::Spec->catfile($a_dir, $_) } grep { /$regex/i && -f File::Spec->catfile($path_dir, $_) } readdir(IND) ) if not $obj->case_sensitive();
          push ( @file_list, map { File::Spec->catfile($a_dir, $_) } grep { /$regex/ &&  -f File::Spec->catfile($path_dir, $_) } readdir(IND) ) if $obj->case_sensitive();
          closedir(IND);
        }
      }
    }
  }
  return @file_list;
}

#************************************************************

=pod

=head2 glob_spec

=over 4

=item glob_spec($path, [@file_specs])

=back

All file specs are assumed to follow the path.
The file specs are turned into regular expressions and then glob_regex is called.
This returns the files that match the file specification in the given path.

=cut

#************************************************************

sub glob_spec
{
  if ( $#_ < 1 )
  {
    carp('glob_spec expected at least two parameters, a path and file spec');
  }

  my $obj;
  if ( UNIVERSAL::isa( $_[0], 'Pitonyak::SafeGlob' ) )
  {
      $obj = shift;
      if ( $#_ < 1 )
      {
        carp('glob_spec expected at least two parameters, a path and file spec');
      }
  }
  else
  {
    $obj = new Pitonyak::SafeGlob();
  }

  my $path     = shift;
  my @reg_list = @_;
  foreach (@reg_list)
  {
    s/\./\\./go;     # Convert '.' to '\.'
    s/\^/\\^/go;     # Convert '^' to '\^'
    s/\$/\\\$/go;    # Convert '$' to '\$'
    s/\?/./go;       # Convert '?' to '.'
    s/\*/.*/go;      # Convert '*' to '.*'
    $_ = "^$_\$";    # Place a '^' in front and '$' at the end.
  }
  return $obj->glob_regex( $path, @reg_list );
}

#************************************************************

=pod

=head2 glob_spec_from_path

=over 4

=item glob_spec_from_path([@file_specs_with_dirs])

=back

This assumes that it is given a list of file specs where the file specs
contain leading directory entries.
The file spec and path are separated using File::Basename::fileparse()
and then glob_spec is called.

=cut

#************************************************************

sub glob_spec_from_path
{
  if ( $#_ < 0 )
  {
    carp('glob_spec_from_path, expected at least one parameter');
  }

  my $obj;
  if ( UNIVERSAL::isa( $_[0], 'Pitonyak::SafeGlob' ) )
  {
    $obj = shift;
  }
  else
  {
    $obj = new Pitonyak::SafeGlob();
  }

  my @list;
  my @suffixlist = ();
  foreach my $fullname (@_)
  {
    my ( $name, $path, $suffix ) = fileparse( $fullname, @suffixlist );
    push ( @list, map { "$path$_" } $obj->glob_spec( $path, $name ) );
  }
  return @list;
}

#************************************************************

=pod

=head2 recurse

=over 4

=item recurse([0|1])

Set the attribute if a parameter is present.

Return the state of the parameter.

=back

=cut

#************************************************************

sub recurse
{
  return get_class_attribute( @_, 'recurse' );
}

#************************************************************

=pod

=head2 return_dirs

=over 4

=item return_dirs([0|1])

Set the attribute if a parameter is present.

Return the state of the parameter.

=back

=cut

#************************************************************

sub return_dirs
{
  return get_class_attribute( @_, 'return_dirs' );
}

#************************************************************

=pod

=head2 return_files

=over 4

=item return_files([0|1])

Set the attribute if a parameter is present.

Return the state of the parameter.

=back

=cut

#************************************************************

sub return_files
{
  return get_class_attribute( @_, 'return_files' );
}

#************************************************************

=pod

=head1 COPYRIGHT

Copyright 1998-2012, Andrew Pitonyak (perlboy@pitonyak.org)

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

=head2 July 17, 2009

Change some wording, and a few minor fixes such sa removing references to
a logger.

=head2 April 4, 2007

Use File::Spec to concatinate a directory path to a file name.
This is a safer than the previous assumptions.
Corrected POD documentation.

=head2 September 10, 2002

Version 1.01 Changed internal documentation to POD documentation and
support subdirectories

=head2 March 13, 1998

Version 1.00 First release

=cut

#************************************************************

1;
