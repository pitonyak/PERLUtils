package Pitonyak::CommandLineProcessor;
#************************************************************

=head1 NAME

Pitonyak::CommandLineProcessor - Recognize and parse command line arguments.

=head1 SYNOPSIS

After writing the same code to process arguments over and over again,
I decided to write a processor that could handle most of the tasks for me.

This processor will process the arguments and place them in an array
after matching commands with arguments for me.

The processor also recognizes and parses arguments from text files.

I keep this file here mostly for legacy reasons. If I was feeling industrious, I would replace it with GetOpt.

=head1 DESCRIPTION

More in depth description??

=cut

#************************************************************


require Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = '1.02';
@ISA     = qw(Exporter);
@EXPORT  = qw(
);

@EXPORT_OK = qw(
  case_sensitive
  clear
  clear_arg_config
  clear_arg_values
  die_on_error
  new
  is_argument
  get_argument_name
  get_processed_args
  process_args
  arg_expects_value
  configure
  contains_value
  get_value
  print_usage
);


use strict;
use Carp;
use IO::File;
use Pitonyak::StringUtil qw(left_fmt hash_key_width);
use Pitonyak::ConfigFileParser;

my %initial_attributes = (
  'die_on_error' => 1,
);

my @required_args = (
  'case_sensitive',
  'arg_expects_value',
  'allows_value',               # Not yet handled.
  'force_value_in_same_arg',
  'method_name',
  'description',
  'arg_is_file_name_to_read',
);


#************************************************************

=pod

=head2 die_on_error

=over 4

=item C<< Pitonyak::CommandLineProcessor::die_on_error() >>

Return the state of the initial die_on_error flag.

=item C<< $obj->die_on_error() >>

Return the state of the die_on_error flag.


=item C<< $obj->die_on_error(0|1) >>

Set the state of the die_on_error flag.

=back

=cut

#************************************************************

sub die_on_error
{
  return get_class_attribute( @_, 'die_on_error' );
}

#************************************************************

=pod

=head2 clear

=over 4

=item C<< $obj->clear() >>

Clear the argument configuration and argument values.

=back

=cut

#************************************************************
sub clear()
{
  if ($#_ == 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ))
  {
    # fastest way to clear a hash is to assign it to an empty list.
    # ${$_[0]->{'config_hash'}} = ();
    $_[0]->{'config_hash'}->{'arg_config'} = {};
    $_[0]->{'config_hash'}->{'arg_values'} = [];
  }
}

#************************************************************

=pod

=head2 clear_arg_config

=over 4

=item C<< $obj->clear_arg_config() >>

Clear the argument configuration.

=back

=cut

#************************************************************
sub clear_arg_config()
{
  if ($#_ == 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ))
  {
    # Fastest way to clear a hash is to assign it to an empty list.
    $_[0]->{'config_hash'}->{'arg_config'} = {};
  }
}

#************************************************************

=pod

=head2 clear_arg_values

=over 4

=item C<< $obj->clear_arg_values() >>

Clear the argument values.

=back

=cut

#************************************************************
sub clear_arg_values()
{
  if ($#_ == 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ))
  {
    # fastest way to clear a hash is to assign it to an empty list.
    $_[0]->{'config_hash'}->{'arg_values'} = [];
  }
}

#************************************************************

=pod

=head2 get_processed_args

=over 4

=item C<< $obj->get_processed_args() >>

Get a reference to all of the accumulated arguments.

=back

=cut

#************************************************************

sub get_processed_args
{
  if ($#_ == 0 && UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ))
  {
    return @{$_[0]->{'config_hash'}->{'arg_values'}};
  }
}

#************************************************************

=pod

=head2 push_processed_arg

=over 4

=item C<< $obj->push_processed_arg($arg_name, $arg_value, $method_name) >>

Push a processed argument set onto the stack.

=begin html

<table BORDER='1' CELLPADDING="5">
<TR><TH>Argument</TH>                <TH>Description</TH></TR>
<TR><TD><CODE>arg_name</CODE></TD>   <TD>Argument name without the leading minus.</TD></TR>
<TR><TD><CODE>arg_value</CODE></TD>  <TD>Value</TD></TR>
<TR><TD><CODE>method_name</CODE></TD><TD>Name of the method to use to parse the argument/value.</TD></TR>
</table>

=end html

=back

=cut

#************************************************************

sub push_processed_arg
{
  if ($#_ < 3 || !UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ))
  {
    die('Usage: $obj->push_processed_arg($arg_name, $arg_value, $method_name)');
  }
  my $obj = shift;
  my $arg = [];
  push(@{$arg}, @_);
  push(@{$obj->{'config_hash'}->{'arg_values'}}, $arg);
  print "pushing arg 0: $arg->[0]  \n";
  print "     pushing arg 1: $arg->[1]  \n";
  print "     pushing arg 2: $arg->[2]  \n";
}

sub print_usage
{
  if ($#_ < 0 || !UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ))
  {
    my $err_msg = 'print_usage must be called with a CommandLineProcessor';
    die ($err_msg);
  }
  my $arg_cfg = $_[0]->{'config_hash'}->{'arg_config'};
  my $key_width = hash_key_width(%{$arg_cfg}) + 1;
  my $arg_ref;
  print "Print Usage:\n";
  foreach my $key (keys %{$arg_cfg})
  {
    $arg_ref = $arg_cfg->{$key};
    if ($arg_ref->{'arg_expects_value'})
    {
      if ($arg_ref->{'force_value_in_same_arg'} || $arg_ref->{'allows_value'})
      {
        print ' -'.left_fmt($key_width, $arg_ref->{'name'}).'=<value> '.$arg_ref->{'description'}."\n";
      }
      if (!$arg_ref->{'force_value_in_same_arg'})
      {
        print ' -'.left_fmt($key_width, $arg_ref->{'name'}).' <value> '.$arg_ref->{'description'}."\n";
      }
    }
    else
    {
      print ' -'.left_fmt($key_width, $arg_ref->{'name'}).'         '.$arg_ref->{'description'}."\n";
    }
  }
}

#************************************************************

=pod

=head2 process_args

=over 4

=item C<< $obj->process_args(@arg_list) >>

Process each argument based on the current configuration.
An argument list is built by calling C<< get_processed_args() >>.

=back

=cut

#************************************************************

sub process_args
{
  if ($#_ < 0 || !UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ))
  {
    my $err_msg = 'process_args must be called with a CommandLineProcessor';
    die ($err_msg);
  }
  my $cmd = shift;

  if ($#_ < 0 || !UNIVERSAL::isa( $_[0], 'Pitonyak::ADPLogger' ))
  {
    my $err_msg = 'process_args must be called with an ADPLogger';
    die ($err_msg) if $cmd->die_on_error();
    carp ($err_msg);
    return undef;
  }
  my $log = shift;

  my $last_arg;
  my $current_arg;
  my $current_value;
  my $arg_hash;
  foreach $current_arg (@_)
  {
    print "current = $current_arg last = $last_arg\n";
    if ($cmd->is_argument($current_arg))
    {
      # If $last_arg is still set, then we are expecting to process a value.
      # We found an argument rather than a value, so this is an error.
      if (defined($last_arg))
      {
        my $err_msg = "Processing argument $current_arg while $last_arg has not finished";
        $log->error($err_msg);
        $cmd->print_usage();
        die ($err_msg) if $cmd->die_on_error();
        return undef;
      }

      # Extract the argument name from the entered argument.
      $last_arg = $cmd->get_argument_name($current_arg);
      
      # If the argument does not exist, then it is not configured to
      # be supported.
      if (!defined($last_arg))
      {
        my $err_msg = "Unknown argument $current_arg";
        $log->error($err_msg);
        $cmd->print_usage();
        die ($err_msg) if $cmd->die_on_error();
        return undef;
      }

      $arg_hash = defined($cmd->{'config_hash'}->{'arg_config'}->{$last_arg}) ? $cmd->{'config_hash'}->{'arg_config'}->{$last_arg} : $cmd->{'config_hash'}->{'arg_config'}->{lc $last_arg};

      if ($arg_hash->{'expects_value'} || ($arg_hash->{'allows_value'} && $cmd->contains_value($current_arg)))
      {
        if ($cmd->contains_value($current_arg))
        {
          if ($arg_hash->{'arg_is_file_name_to_read'})
          {
            $cmd->process_args_from_file($cmd->get_value($current_arg));
          }
          else
          {
            $cmd->push_processed_arg($last_arg, $cmd->get_value($current_arg), $arg_hash->{'method_name'});
          }
          undef $last_arg;
        }
        elsif ($arg_hash->{'force_value_in_same_arg'})
        {
          my $err_msg = "$current_arg must contain an argument, but it does not";
          $log->error($err_msg);
          $cmd->print_usage();
          die ($err_msg) if $cmd->die_on_error();
          return undef;
        }
      }
      else
      {
        # No value is expected.
        $cmd->push_processed_arg($last_arg, undef, $arg_hash->{'method_name'});
        undef $last_arg;
      }
    }
    elsif (defined($last_arg))
    {
      #
      # It is not possible to get here, because last_arg is always cleared.
      # The intent was to not clear last_arg is an argument is possible or required.
      # I have no current need, so I will not fix this bug.
      #
      # This is a value and we are watching for a value!
      if ($arg_hash->{'arg_is_file_name_to_read'})
      {
        $cmd->process_args_from_file($current_arg);
      }
      else
      {
        $cmd->push_processed_arg($last_arg, $current_arg, $arg_hash->{'method_name'});
      }
      undef $last_arg;
    }
    else
    {
      # Value without any specific argument.
      $cmd->push_processed_arg(undef, $current_arg, undef);
    }
  }
}

#************************************************************

=pod

=head2 process_args_from_file

=over 4

=item C<< $obj->process_args_from_file($file_name, ...) >>

Process arguments from each file. Empty lines are ignored.
The general process is to open and read values from every file
and then process the lines.

=back

=cut

#************************************************************

sub process_args_from_file
{
  if ($#_ < 1 || !UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ))
  {
    die('Usage: $obj->process_args_from_file($file_name)');
  }
  my $obj = shift;
  my $handle = new IO::File;
  my @args;
  foreach my $file_name (@_)
  {
    if (!-f $file_name)
    {
      my $err_msg = "Filename $file_name does not exist while processing arguments";
      die($err_msg) if $obj->die_on_error();
      warn($err_msg);
      return undef;
    }
    if (!$handle->open('<'.$file_name))
    {
      my $err_msg = "Unable to open $file_name because $!";
      die($err_msg) if $obj->die_on_error();
      warn($err_msg);
      return undef;
    }
    while(<$handle>)
    {
      chomp;
      push(@args, $_) if $_ ne '';
    }
    $handle->close();
  }
  process_args(@args);
}

#************************************************************

=pod

=head2 configure

=over 4

=item C<< $obj->configure($cfg) >>

Configure this object using a configuration file. Typical values are as follows:

=begin html

<table BORDER='1' CELLPADDING="5">
<TR><TH>Key</TH>              <TH>Description</TH></TR>
<TR><TD><CODE>die_on_error</CODE></TD>    <TD>If 1, an error causes program termination.</TD></TR>
<TR><TD><CODE>arg_names</CODE></TD>       <TD>Comma separated list of expected argument names.</TD></TR>
<TR><TD><CODE></CODE></TD>    <TD></TD></TR>
</table>

=end html

Each supported argument is assumed to its own entry. A typical examle might be:

=begin html

<table BORDER='1' CELLPADDING="10"><TR><TD><code>
arg_names = s, ReadFile                                <br/>
arg = s                                                <br/>
arg.${arg}.case_sensitive           = 0                <br/>
arg.${arg}.expects_value            = 0                <br/>
arg.${arg}.allows_value             = 1                <br/>
arg.${arg}.force_value_in_same_arg  = 1                <br/>
arg.${arg}.method_name              =                  <br/>
arg.${arg}.description              = Recursively traverse directories.<br/>
arg.${arg}.arg_is_file_name_to_read = 0                <br/>
                                                       <br/>
arg = ReadFile                                         <br/>
arg.${arg}.case_sensitive           = 0                <br/>
arg.${arg}.expects_value            = 1                <br/>
arg.${arg}.allows_value             = 1                <br/>
arg.${arg}.force_value_in_same_arg  = 0                <br/>
arg.${arg}.method_name              =                  <br/>
arg.${arg}.description              = Read arguments from the specified text file.<br/>
arg.${arg}.arg_is_file_name_to_read = 1                <br/>
</code>
</TD></TR></table>

=end html

The supported argument configuration items are as follows:

=begin html

<table BORDER='1' CELLPADDING="5">
<TR><TH>Key                                    </TH> <TH>Description</TH></TR>
<TR><TD><CODE>case_sensitive           </CODE> </TD> <TD>Is this argument case sensitive?</TD></TR>
<TR><TD><CODE>expects_value            </CODE> </TD> <TD>Argument uses a corresponding value.</TD></TR>
<TR><TD><CODE>allows_value             </CODE> </TD> <TD>Will use a value in the same argument if present.</TD></TR>
<TR><TD><CODE>force_value_in_same_arg  </CODE> </TD> <TD>Will only accept a value if embedded in the argument using an equal sign.</TD></TR>
<TR><TD><CODE>method_name              </CODE> </TD> <TD>Method to call to process this argument.</TD></TR>
<TR><TD><CODE>description              </CODE> </TD> <TD>Text description to print with help.</TD></TR>
<TR><TD><CODE>arg_is_file_name_to_read </CODE> </TD> <TD>This argument causes arguments to be read from the specified file.</TD></TR>
</table>

=end html

=back

=cut

#************************************************************

sub configure
{
  if ($#_ < 1 || !UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ) || !UNIVERSAL::isa( $_[1], 'Pitonyak::ConfigFileParser' ))
  {
    carp('Usage: $obj->configure($cfg) with a ConfigFileParser');
    return undef;
  }
  if (!$_[1]->contains_key('arg_names'))
  {
    carp('Usage: $obj->configure() expected the ConfigFileParser to have a key named arg_names.');
    return undef;
  }

  if ($_[1]->contains_key('die_on_error'))
  {
    $_[0]->die_on_error($_[1]->contains_key('die_on_error'));
  }

  foreach my $arg_name ($_[1]->get_delimited_values('arg_names'))
  {
    my $arg_hash = {};
    $arg_hash->{'name'} = $arg_name;
    foreach my $req_name (@required_args)
    {
      if (!$_[1]->contains_key("arg.$arg_name.$req_name"))
      {
        die("Config file missing key for arg.$arg_name.$req_name");
      }
      $arg_hash->{$req_name} = $_[1]->get_value("arg.$arg_name.$req_name")
    }
    if ($arg_hash->{'case_sensitive'})
    {
      $_[0]->{'config_hash'}->{'arg_config'}->{$arg_name} = $arg_hash;
    }
    else
    {
      $_[0]->{'config_hash'}->{'arg_config'}->{lc $arg_name} = $arg_hash;
    }
  }
}

#************************************************************

=pod

=head2 copy

=over 4

=item copy($obj)

Make a copy of one object into another

C<$obj1->copy($obj2)> is the same as C<$obj1 = $obj2>.

=back

=cut

#************************************************************

sub copy
{
  foreach my $key ( keys %initial_attributes )
  {
    # If there are any attributes that should not be copied
    # check for them here to prevent copying.
    # For example, a file handle...
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

=head2 get_class_attribute

The get_class_attribute method utilizes the fact that
C<< $obj->method(@parms) >> is the same as
C<< method($obj, @parms) >>. This method does not perform type checking
to verify that this is true.

The C<get_class_attribute> method is rarely called directly.

=over 4

=item C<< Pitonyak::ADPLogger::get_class_attribute($attribute_name) >>

With only one paramter, the first parameter is
assumed to be an attribute name and the default attribute value
is returned.

=item C<< $obj->get_class_attribute($attribute_name) >>

With two arguments, the first is assumed
to be a C<ADPLogger> object and the second is
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

=head2 new

=over 4

=item C<< $obj = new Pitonyak::CommandLineProcessor; >>

Generate a new object.

=item C<< $obj = $obj->new() >>

Generate a new copy of an object.

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

=head2 is_argument

=over 4

=item C<< $obj->is_argument($arg) >>

Return 1 if C<< $arg >> starts with a minus sign.

=back

=cut

#************************************************************

sub is_argument
{
  if (($#_ < 1) || !UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ))
  {
    carp('Usage: $obj->is_argument($arg_name) with num: '.$#_);
    return 0;
  }
  return ($_[1] =~ /^-/);
}

#************************************************************

=pod

=head2 get_argument_name

=over 4

=item C<< $obj->get_argument_name($arg) >>

Obtain the argument name if C<< $arg >> is preceded by a minus sign.
Execpted use is something like:

C<< $arg_name = $obj->get_argument_name($arg) if $obj->is_argument($arg); >>

If $arg is not an argument, then undef is returned.

The returned name is take from the argument hash, and is not the precise
value of the argument. So, if "filename" is not case sensitive, then
FileName, and filename will both return filename.

=back

=cut

#************************************************************

sub get_argument_name
{
  if ($#_ < 1 || !UNIVERSAL::isa( $_[0], 'Pitonyak::CommandLineProcessor' ))
  {
    carp('Usage: $obj->get_argument_name($arg_name');
    return undef;
  }
  if ($_[1] =~ /^-(.*)$/)
  {
    my $arg = $1;
    if ($arg =~ /^(.*?)=/)
    {
      $arg = $1;
    }
    return $_[0]->{'config_hash'}->{'arg_config'}->{$arg}->{'name'} if defined($_[0]->{'config_hash'}->{'arg_config'}->{$arg});
    return $_[0]->{'config_hash'}->{'arg_config'}->{lc $arg}->{'name'} if defined($_[0]->{'config_hash'}->{'arg_config'}->{lc $arg}) && !$_[0]->{'config_hash'}->{'arg_config'}->{lc $arg}->{'case_sensitive'};
  }
  return undef;
}

#************************************************************

=pod

=head2 arg_expects_value

=over 4

=item C<< $obj->arg_expects_value($arg) >>

Return 1 if C<< $arg >> expects an argument, 0, otherwise.

=back

=cut

#************************************************************

sub arg_expects_value
{
  my $arg = get_argument_name(@_);
  return defined($arg) ? $_[0]->{'config_hash'}->{'arg_config'}->{$arg}->{'expect_args'} : 0;
}

#************************************************************

=pod

=head2 contains_value

=over 4

=item C<< $obj->contains_value($arg) >>

Return 1 if C<< $arg >> is of the form '-argument=value', otherwise,
return 0.

=back

=cut

#************************************************************

sub contains_value
{
  return ($_[1] =~ /^-.*?=/)
}

#************************************************************

=pod

=head2 get_value

=over 4

=item C<< $obj->get_value($arg) >>

If C<< $arg >> is of the form '-argument=value', then return value.
If it is not, then return undef.

=back

=cut

#************************************************************

sub get_value
{
  if ($_[1] =~ /^-.*?=/)
  {
    return ($_[1] =~ /^-.*?=(.*)$/) ? $1 : '';
  }
  return undef;
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
  $_[0]->{'config_hash'}->{'arg_config'} = {};
  $_[0]->{'config_hash'}->{'arg_values'} = [];
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

=head1 Modification History

=head2 March 13, 1998

Version 1.00 First release

=head2 September 10, 2002

Version 1.01 Changed internal documentation to POD documentation.

=head2 May 29, 2012

Version 1.02
Fixed a bug so that optional parameters are read. Will still not read a parameter of the form "-s 2", but it will handle "-s=2".

=cut

#************************************************************

1;
