package Pitonyak::ConfigFileParser;
#************************************************************

=head1 NAME

Pitonyak::ConfigFileParser - Handle a configuration file.

=head1 SYNOPSIS

=begin html

<p><code>
use Pitonyak::ConfigFileParser;                        <br/>
                                                       <br/>
my $cfg = new Pitonyak::ConfigFileParser();            <br/>
$cfg->read_config_file('./modules/sample.cfg');        <br/>
print 'keys = ('.join(', ', $cfg->get_keys()).")\n";   <br/>
</code></p>

=end html

=head1 DESCRIPTION

One might argue that this is nothing more than a light wrapper to read a
configuration file into a hash. The C<< read_config_file method() >>
is pretty smart at processing the file to increase ease of use.

The configuration/properties file contains lines of the form:

C<< <left hand side> = <right hand side> >>

The following parsing rules are used:

=over 4

=item Blank lines are ignored.

=item # is a comment character.

=item Replace ${key} with the key value in the hash.

=item The equal sign separates the keys from the values.

=item leading and trailing space is removed.

=item space around the equal sign is removed.

=item Use a backslash as the escape character.

=back

Use the escape character to insert special characters such as the comment, $,
character, equal sign, leading or trailing space, or an escape character.
Escaping characters with no special meaning, such as an 'a', evaluates to
the character 'a'.

You can prevent substitution of ${key} text by using \${key}.
Substitution is done before escape characters are removed. So,the sequence
${\key} looks to see if there is a key named '\key' for replacement.

Consider the following configuration:

=begin html

<p><code>
file_base = ./files/                      <br/>
partner = john                            <br/>
${partner}.loc = ${file_base}${partner}/  <br/>
</code></p>

=end html

This is equivalent to

=begin html

<p><code>
file_base = ./files/                      <br/>
partner = john                            <br/>
john.loc = ./files/john/                  <br/>
</code></p>

=end html

=head1 Copyright

Copyright 1998-2009 by Andrew Pitonyak

More reworked code from Andrew's library. As with most of my
code libraries, the code is free as free can be.

=cut

#************************************************************

require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = '1.04';
@ISA     = qw(Exporter);
@EXPORT  = qw(
);

@EXPORT_OK = qw(
  clear
  clear_key_value
  config_path
  config_name
  copy
  contains_key
  get_class_attribute
  get_config_full_name
  get_delimited_values
  get_keys
  get_hash_ref
  get_value
  get_value_default
  new
  read_config_file
  set_key_value
);

use Carp;
use IO::File;
use strict;
use Pitonyak::DeepCopy qw(deep_copy);
use Pitonyak::StringUtil qw(trim_space);

my %initial_attributes = (
    'is_ok'         => 1,    # Has an error occured?
    'config_name'   => 'configfile.cfg',
    'config_path'   => './',
);

#************************************************************

=pod

=head2 clear

=over 4

=item C<< $cfg->clear() >>

Clear the entire configuration hash.

=back

=cut

#************************************************************
sub clear()
{
  if ($#_ == 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::ConfigFileParser' ))
  {
    # fastest way to clear a hash is to assign it to an empty list.
    ${$_[0]->{'config_hash'}} = ();
  }
}

#************************************************************

=pod

=head2 clear_key_value

=over 4

=item C<< $cfg->clear_key_value('key_text') >>

Clear the specified key so that it is no longer in the configuration hash.

=back

=cut

#************************************************************

sub clear_key_value()
{
  if ($#_ > 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::ConfigFileParser' ))
  {
    undef( $_[0]->{'config_hash'}->{$_[1]});
  }
}

#************************************************************

=pod

=head2 config_name

The config_name is the name of the configuration file with the file extension.
The full file name is built by concatenating C<< config_path() >> and C<< config_name() >>.
The extension is not assumed because it might be '.cfg' or '.properties'.

=over 4

=item C<< config_name() >>

Return the default file name with file extension.

=item C<< $cfg->config_name() >>

Return the base configuration file name.

=item C<< $cfg->config_name(file_name) >>

Set the file name with extension, used for the next read.

=back

=cut

#************************************************************

sub config_name
{
  return get_class_attribute( @_, 'config_name' );
}

#************************************************************

=pod

=head2 config_path

The config_path identifies the directory containing the file.
The full file name is built by concatinating C<< config_path() >> and C<< config_name() >>.

=over 4

=item C<< config_path() >>

Return the default path during initialization, which is './'.

=item C<< $cfg->config_path() >>

Return the the path to the next configuration file to read.
Reading a configuration file with a fully specified file name
does not cause the path or the file name to be set.

=item C<< $cfg->config_path(path) >>

Set the path for the configuration file, which will be used for the next read
operation if the file name is not specified.
If the provided path does not contain '/' or '\', then '/' is appended to
to the path. The path itself is not checked for validity.

If the provided path is an empty string, then the path is set to the
default value.

=back

=cut

#************************************************************

sub config_path
{
  # If zero arguments, return the initial value.
  return $initial_attributes{ 'config_path' } if $#_ < 0;

  # If one argument, assume the object is correct and return
  # the current path.
  return $_[0]->{ 'config_path' } if $#_ == 0;

  my $obj = shift;
  my $value = shift;

  if ($value =~ /[\/\\]$/)
  {
    $obj->{ 'config_path' } = $value;
  }
  elsif ($value eq '')
  {
    $obj->{ 'config_path' } = $initial_attributes{ 'config_path' };
  }
  else
  {
    $obj->{ 'config_path' } = $value.'/';
  }

  return $obj->{ 'config_path' };
}

#************************************************************

=pod

=head2 copy

=over 4

=item copy($config_object)

Make a copy of one ConfigFileParser into another

C<$obj1->copy($obj2)> is the same as C<$obj1 = $obj2>.
The receiving ConfigFileParser is closed first.

=back

=cut

#************************************************************

sub copy
{
  foreach my $key ( keys %initial_attributes )
  {
    if ( UNIVERSAL::isa( $_[1]->{$key}, 'HASH' ) )
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

=pod

=head2 contains_key

=over 4

=item C<< $cfg->contains_key(key_name) >>

Return 1 if the hash contains the key name and 0 otherwise.

=back

=cut

#************************************************************

sub contains_key()
{
  if (($#_ > 0) && UNIVERSAL::isa( $_[0], 'Pitonyak::ConfigFileParser' ))
  {
    return defined($_[0]->{'config_hash'}->{$_[1]}) ? 1 : 0;
  }
  carp('You must include a key name, such as $obj->contains_key("joe")');
  return 0;
}

#************************************************************

=pod

=head2 get_class_attribute

The get_class_attribute method utilizes the fact that
C<< $obj->method(@parms) >> is the same as
C<< method($obj, @parms) >>. This method does not perform type checking
to verify that this is true.

The C<get_class_attribute> method is rarely called directly.

=over 4

=item C<< Pitonyak::ConfigFileParser::get_class_attribute($attribute_name) >>

With only one paramter, the first parameter is
assumed to be an attribute name and the default attribute value
is returned.

=item C<< $obj->get_class_attribute($attribute_name) >>

With two arguments, the first is assumed
to be a C<ConfigFileParser> object and the second is
assumed to be an attribute name.
The attribute value for the object is returned.


=item C<< $obj->get_class_attribute($attribute_value, $attribute_name) >>

With three arguments, the first is assumed to be the object,
the second is a new attribute value, and the third is the attribute
name to set. Although the order seems odd, this is intentional.

Consider the method C<< is_ok >> defined as C<< return get_class_attribute( @_, 'is_ok' ); >>

Remember that C<@_> refers to the argument list passed to the method. In all cases, the last argument
passed to C<get_class_attribute> is the attribute name. If the method is called directly,
this is the only argument.

=back

=cut

#************************************************************

sub get_class_attribute
{
  return $initial_attributes{ $_[0] } if $#_ == 0;
  return $_[0]->{ $_[1] } if $#_ == 1;
  $_[0]->{ $_[2] } = $_[1];
  return $_[1];
}

#************************************************************

=pod

=head2 get_config_full_name

=over 4

=item C<< $cfg->get_config_full_name() >>

Build and return the full path to the configuration file.
Remember that C<< $cfg->config_path() >>
returns a string with a trailing '/', so the value returned is equivalent to:

C<< $cfg->config_path().$cfg->config_name() >>

=back

=cut

#************************************************************

sub get_config_full_name()
{
  $_[0]->{'config_path'}.$_[0]->{'config_name'};
}

#************************************************************

=pod

=head2 get_hash_ref

=over 4

=item C<<  $cfg->get_hash_ref() >>

Return a reference to the hash containing the properties.
For example, to obtain the value for the key 'peter', you
can use C<<  $cfg->get_hash_ref()->{'peter'} >> or
C<<  $cfg->get_value('peter') >>.

=back

=cut

#************************************************************
sub get_hash_ref()
{
  return $_[0]->{'config_hash'} if $#_ >= 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::ConfigFileParser' );
}

#************************************************************

=pod

=head2 get_keys

=over 4

=item C<< $cfg->get_keys() >>

Return the keys in the hash as an array.
This is equivalent to
C<<  keys(%{$cfg->get_hash_ref()}) >>.

=back

=cut

#************************************************************

sub get_keys()
{
  return keys %{$_[0]->{'config_hash'}} if $#_ >= 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::ConfigFileParser' );
}

#************************************************************

=pod

=head2 get_value

=over 4

=item C<< $cfg->get_value('key') >>

Return the property value for the specified key.
To obtain the value for the key 'peter', you
can use C<<  $cfg->get_hash_ref()->{'peter'} >> or
C<<  $cfg->get_value('peter') >>.

=back

=cut

#************************************************************

sub get_value
{
  return $_[0]->{'config_hash'}->{$_[1]} if $#_ > 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::ConfigFileParser' );
}

#************************************************************

=pod

=head2 get_value_default

=over 4

=item C<< $cfg->get_value_default('key') >>

This version is identical to C<< $cfg->get_value_default('key') >>,
except that it returns an empty string if the key does not exist.

=item C<< $cfg->get_value_default('key', 'default') >>

If the property exists, return the value. If the property
does not exist, return the specified default value.

=back

=cut

#************************************************************

sub get_value_default
{
    if ( $#_ > 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::ConfigFileParser' ))
    {
        return $_[0]->{'config_hash'}->{$_[1]} if defined($_[0]->{'config_hash'}->{$_[1]});
    }
    return ($#_ > 1) ? $_[2] : '';
}


#************************************************************

=pod

=head2 get_delimited_values

=over 4

=item C<< $cfg->get_delimited_values('key') >>

Omitting the delimiter is the same as calling
C<<  $cfg->get_delimited_values('key', ',') >>.

=item C<< $cfg->get_delimited_values('key', 'delimiter') >>

Extract the specified key from the configuration item.
Assume that the key contains a list of items delimited with the
specified delimiter.
Leading and trailing spaces are removed.
All of the values are returned as an array.

=back

=cut

#************************************************************

sub get_delimited_values
{
    my @array;
    if ($#_ > 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::ConfigFileParser' ))
    {
        my $obj = shift;
        my $name = shift;
        my $delim = ',';
        $delim = shift if $#_ >= 0;
        return @array if not defined($obj->{'config_hash'}->{$name});
        return map {trim_space($_)} split($delim, $obj->{'config_hash'}->{$name});
    }
    return @array;
}

#************************************************************

=pod

=head2 new

=over 4

=item C<< $cfg_copy = $cfg->new() >>

Generate a new copy of a configuration object.

=back

=cut

#************************************************************

sub new
{
  my $self = shift;
  my $objref = bless {}, ref($self) || $self;
  $objref->initialize();
  if ( ref($self) )
  {
    $objref->copy($self);
  }
  return $objref;
}

#************************************************************

=pod

=head2 read_config_file

Read a config/properties file from disk and populate this object.
The current object is cleared reading the file.
Any current values are over-written.

=over 4

=item C<< $cfg->read_config_file() >>

The directory
and name must be set using C<config_path()> and C<config_name()>.
C<get_config_full_name()> is used to build the full path.

=item C<< $cfg->read_config_file('full_path_to_file') >>

Neither C<config_path()> nor C<config_name()> are updated.

=back

=cut

#************************************************************

sub read_config_file()
{
  if ( $#_ < 0 || !UNIVERSAL::isa( $_[0], 'Pitonyak::ConfigFileParser' ))
  {
    carp('Usage: obj->read_config_file() or obj->read_config_file(<config_file_name>)');
    return undef;
  }

  # Either build the full name, or take it from the argument.
  my $file_name = ($#_ > 0) ? $_[1] : $_[0]->get_config_full_name();

  # First, read the entire file into an array.
  # Remove comments, blank lines, as well as leading and trailing white space.
  my $rc = 0;
  my $line = 0;
  my $handle = new IO::File;
  my ($key, $value);
  if ( not $handle->open( '<' . $file_name ) )
  {
    carp("Unable to open configuration file $file_name because $!");
    return undef;
  }
  else
  {
    while (<$handle>)
    {
      $key = '';
      $value = '';
      ++$line;
      chomp;
      s/^\s*//;           # leading spaces
      #
      # This one is more difficult....
      # s/(.*?(?<!\\)(?:(\\\\)*))#.*/$1/
      #
      # .*?           include all preceding text minimally
      # (?<!\\)       Do not allow a preceding backslash
      # (?:(\\\\)*))  Match any groups of two backslashes
      # #.*           Match a # followed by anything
      #
      # This effectively considers the first # not preceded by
      # an odd number of \ to be a comment.
      #
      if ($] >= 5.005)
      {
        s/(.*?(?<!\\)(?:(\\\\)*))#.*/$1/;
        s/^(.*?(?<!\\)(?:(\\\\)*))\s*$/$1/;         # Trailing spaces not preceded by a \

        # Look for substition values of the form ${key_name}.
        # Replace these values with entries that have already been read.
        while (/(?<!\\)(?:(\\\\)*)\${(.*?)}/)
        {
          my $parens = defined($1) ? $1 : '';
          my $subst_name = $2;
          my $subst_value = defined($subst_name) && defined($_[0]->{'config_hash'}->{$subst_name}) ? $_[0]->{'config_hash'}->{$subst_name} : '';
          s/(?<!\\)(?:(\\\\)*)(\${.*?})/$parens$subst_value/;
        }

        if ($_ ne '')              # Ignore empty lines
        {
          # Ignore lines that do not contain '='
          if (/(.*?(?<!\\)(?:(\\\\)*))=(.*)$/)
          {
            $key = $1;
            $value = $3;
            $key =~ s/^(.*?(?<!\\)(?:(\\\\)*))\s*$/$1/; # Trailing spaces not preceded by a \
            $value =~ s/^\s*//;      # Leading spaces on the value.
            $key   =~ s/\\(.)/$1/g;  # Now remove \ chars
            $value =~ s/\\(.)/$1/g;  # Now remove \ chars

            # Although it might be argued that this is not the best time for this,
            # property substitution is done now.

            $_[0]->{'config_hash'}->{$key} = $value;
            #$log->trace("Config line $line: ($key)=($value)") if defined ($log);
          }
          else
          {
            my $error_msg = "Line $line does not contain the '=' character";
            carp($error_msg);
            #$log->trace($error_msg) if defined ($log);
          }
        }
      }
      else
      {
        my $error_msg = 'Please use a version of perl newer than 5.004';
        carp($error_msg);
        #$log->trace($error_msg) if defined ($log);
        return undef;
        s/(.*?)#.*/$1/;     # ?? This is WRONG but supported by perl 5.004
        s/\s*$//;           # ?? This is WRONG but supported by perl 5.004
      }
      #s/\\(.)/$1/g;              # Now remove \ chars
    }
    $handle->close();
  }
  return $rc;
}

#************************************************************

=pod

=head2 set_key_value

=over 4

=item C<< $cfg->set_key_value(key, value) >>

Set the specified key to the specified value.

=back

=cut

#************************************************************
sub set_key_value()
{
  return $_[0]->{'config_hash'}->{$_[1]} = $_[2] if $#_ > 1 && UNIVERSAL::isa( $_[0], 'Pitonyak::ConfigFileParser' );
}

#************************************************************

=pod

=head1 Private Methods

=head2 initialize

=over 4

=item C<< initialize() >>

The C<< initialize() >> method is called automatically when an object is created.
The new method also calls C<< initialize() >> directly

Initialize the data structure by copying values from the initial attributes hash
into the newly created object. Finally, set the read properties hash to
an empty reference.

=back

=cut

#************************************************************

sub initialize
{
  foreach my $key ( keys %initial_attributes )
  {
    if ( UNIVERSAL::isa( $initial_attributes{$key}, 'HASH' ) )
    {
      # If I simply copy it over then we both reference the same thing!
      $_[0]->{$key} = deep_copy( $initial_attributes{$key} );
    }
    else
    {
      $_[0]->{$key} = $initial_attributes{$key};
    }
  }

  # Set the initial reference to the configuration hash (will hold file values).
  $_[0]->{'config_hash'} = {};
}

#************************************************************
#**                                                        **
#**  Input : None.                                         **
#**                                                        **
#**  Output: None.                                         **
#**                                                        **
#**  Notes : Nothing to destroy or close, but just in case.**
#**                                                        **
#************************************************************

sub DESTROY
{
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

=head2 March 1998

Version 1.00 First release

=head2 September 10, 2002

Version 1.01 Changed internal documentation to POD documentation. Added parameter checking.

=head2 January 2012

Version 1.04 Fixed an issue with a regular expression that prevented proper parsing of substitution variables.

=cut

#************************************************************

1;
