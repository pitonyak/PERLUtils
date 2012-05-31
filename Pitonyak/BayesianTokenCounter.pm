package Pitonyak::BayesianTokenCounter;

#************************************************************

=head1 NAME

Pitonyak::BayesianTokenCounter - I use this to decide if a piece of email is SPAM.
This counts tokens in "good" files and "bad" files and then does a statistical analysis of
which tokens belong in which group.

=head1 SYNOPSIS

=begin html

<code>
use File::Basename; <BR>
use strict; <BR>
use Pitonyak::SmallLogger; <BR>
use Pitonyak::SafeGlob qw(glob_spec_from_path); <BR>
use Pitonyak::BayesianTokenCounter; <BR>
 <BR>
my $log = new Pitonyak::SmallLogger; <BR>
$log->log_name_date(''); <BR>
$log->screen_output('D', 0); <BR>
$log->screen_output('I', 1); <BR>
$log->file_output('D', 1); <BR>
$log->file_output('T', 1); <BR>
$log->message_loc_format('(sub):(line):'); <BR>
$log->open_append(0); <BR>
$log->log_path('./'); <BR>
 <BR>
my $good_tokens = new Pitonyak::BayesianTokenCounter; <BR>
my $bad_tokens = new Pitonyak::BayesianTokenCounter; <BR>
my $probability_tokens = new Pitonyak::BayesianTokenCounter; <BR>
$good_tokens->set_log($log); <BR>
$bad_tokens->set_log($log); <BR>
$probability_tokens->set_log($log); <BR>
 <BR>
#Read the bad tokens <BR>
$good_tokens->read_from_file('bad_file.dat'); <BR>
 <BR>
#Read the good tokens <BR>
# and then add a few new files with good tokens <BR>
# to it <BR>
$good_tokens->read_from_file('good_file.dat'); <BR>
 <BR>
my $want_files = 1; <BR>
my $want_dirs = 0; <BR>
 <BR>
my $glob = new Pitonyak::SafeGlob(); <BR>
$glob->case_sensitive($files_case_sensitive); <BR>
$glob->recurse(0); <BR>
$glob->return_dirs(0); <BR>
$glob->return_files(1); <BR>
 <BR>
foreach my $file_name ($glob->glob_spec_from_path('~andy/new_good_files/*.MSG')) <BR>
{ <BR>
    $good_tokens->tokenize_file($file_name); <BR>
} <BR>
 <BR>
# Save the new good tokens <BR>
$good_tokens->write_to_file(); <BR>
 <BR>
# Build a probablity file. You probably already <BR>
# built this and simply want to read it in. <BR>
$probability_tokens->build_probabilities($good_tokens, $bad_tokens); <BR>
 <BR>
 <BR>
my $token_list = new Pitonyak::BayesianTokenCounter; <BR>
$token_list->tokenize_file('test_message.MSG'); <BR>
 <BR>
my $prob = $probability_tokens->rate_tokens($token_list); <BR>
 <BR>
$log->warn("The file has probability $prob of beeing SPAM") if ($prob > 0.9); <BR>
$log->info("Finished!"); <BR>
</code>

=end html

=head1 DESCRIPTION

This contains methods to create, read, and write token files.
A token file that contains probabilities can also be created.
After tokenizing a file, it can be compared against the good and bad tokens and a guess made
to see if the file is a good or bad file.

The initial ideas came from
http://www.paulgraham.com/spam.html
And then Gary Arnold did an implementation.
http://www.garyarnold.com/projects.php
Gary's initial code did not meet my needs so I wrote my own.

I placed a limit on the length of a token.
There is a I<max_token_len> and I<min_token_len> attribute that may be set.

This code ignores PGP signatures. I am on several mailing lists with members that have PGP signatures.
These signatures are long and I did not want them in the token lists.
Deep down inside, I think that perhaps if a piece of email contains a PGP signature, then I should
probably just assume that it is NOT SPAM.

Some of my email is pre-filtered by SPAM Assasin which inserts certain headers into my email.
Although SPAM Assasin does a good job, I did not want my token filters to be based on this.
The I<ignore_headers> attribute contains these values.

I list the content types that I know. Some content types I will accept, and others I will simply ignore.
Check out the I<content_types> attribute.

=cut

#************************************************************

require Exporter;
$Pitonyak::BayesianTokenCounter::VERSION = '1.01';

@ISA       = qw(Exporter);
@EXPORT_OK = qw(
  build_probabilities
  case_sensitive
  copy
  new
  fast_mime_decode
  file_name
  get_class_attribute
  ignore_headers
  max_token_len
  min_token_len
  num_files
  num_tokens
  purge_tokens_with_count_less_than
  rate_tokens
  read_from_file
  set_log
  skip_html_comments
  tokenize_file
  tokenize_string
  tokens
  write_to_file
);

@EXPORT_OK = qw(
  copy
  new
);

use Carp;
use IO::File;
use File::Basename;
use strict;
use MIME::Base64 ();
use MIME::Parser;
use Pitonyak::DeepCopy qw(deep_copy);
use Pitonyak::SmallLogger;
use Pitonyak::XMLUtil qw(object_to_xml xml_to_object);
use Pitonyak::StringUtil qw( array_width center_fmt compact_space
  hash_key_width hash_val_width left_fmt
  num_int_digits num_with_leading_zeros
  trans_blank trim_fmt trim_space right_fmt);

my %initial_attributes = (
    'fast_mime_decode' => 1,  # Do you trust Andrew Pitonyak to do it correctly?
    'case_sensitive'   => 0,  # Are the tokens case sensitive?
    'skip_html_comments' => 1,   # Remove HTML (and XML) comments?
    'file_name'          => '',  # Name of the token file
    'max_token_len'      => 55,  # Ignore tokens longer than this
    'min_token_len'      => 3,   # Ignore tokens shorter than this
    'num_files'          => 0.0, # Number of files used to accumulate token list
    'tokens'             => {},  # Empty Hash with the tokens
    'ignore_headers'     => {
        'spam'         => 1,     # Lines that start with these will be ingored
        'x-spam-score' => 1,     # These are assumed to be post-fixed with a ':'
        'x-scanned-by' => 1,
        'x-andy-spam'  => 1,
    },
    'content_types' => {
        'text'             => 1,    # A good content type
        'message'          => 1,    # A good content type
        'multipart'        => 1,    # A good content type
        'x-sun-attachment' => 1,    # ?? This one concerns me!
        'application'      => 0,    # An ignored content type
        'image'            => 0,    # An ignored content type
        'audio'            => 0,    # An ignored content type
        'video'            => 0,    # An ignored content type
    },
);

#************************************************************

=pod

=head2 new

=over 4

=item new()

Note that this is written in such a manner
that it can be inherited. Also note that it
is written such that $obj2 = $obj1->new()
is valid!

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
#**  Notes : Not really needed since there is nothing to   **
#**          cleanup such as open files                    **
#**                                                        **
#************************************************************

sub DESTROY {
}

#************************************************************

=pod

=head2 copy

=over 4

=item copy($object)

Make a copy of this object

C<$obj1-E<gt>copy($obj2)> is the same as C<$obj1 = $obj2>.

=back

=cut

#************************************************************

sub copy {
    foreach my $key ( keys %initial_attributes ) {
        if ( UNIVERSAL::isa( $_[1]->{$key}, 'HASH' ) ) {

            # If I simply copy it over then we both reference the same thing!
            $_[0]->{$key} = deep_copy( $_[1]->{$key} );
        }
        else {
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
    foreach my $key ( keys %initial_attributes ) {
        if ( UNIVERSAL::isa( $initial_attributes{$key}, 'HASH' ) ) {

            # If I simply copy it over then we both reference the same thing!
            $_[0]->{$key} = deep_copy( $initial_attributes{$key} );
        }
        else {
            $_[0]->{$key} = $initial_attributes{$key};
        }
    }
}

#************************************************************

=pod

=head2 build_probabilities

=over 4

=item build_probabilities($good_token_list, $bad_token_list)

returns the Baysian probability tokens for the input tokens.

The initial ideas came from
http://www.paulgraham.com/spam.html
And then Gary Arnold did an implementation.
http://www.garyarnold.com/projects.php
Unfortunately for me, Gary Arnold did not produce
code that met my needs and I also wanted to be able
to avoid certain attachements so I had to write my
own code!

=back

=cut

#************************************************************

sub build_probabilities {
    if (   $#_ < 1
        || !UNIVERSAL::isa( $_[0], 'Pitonyak::BayesianTokenCounter' )
        || !UNIVERSAL::isa( $_[1], 'Pitonyak::BayesianTokenCounter' ) )
    {
        carp("Usage: build_probabilities(<good_tokens> <bad_tokens>)");
        return;
    }
    if ( $#_ == 1 ) {
        my $token_list = new Pitonyak::BayesianTokenCounter;
        return $token_list->build_probabilities(@_);
    }
    my $obj = shift;
    my $log = $obj->{'log'} if exists( $obj->{'log'} );

    my $num_good_files = $_[0]->num_files();
    my $num_bad_files  = $_[1]->num_files();
    my $good_tokens    = $_[0]->{'tokens'};
    my $bad_tokens     = $_[1]->{'tokens'};
    my $my_tokens      = {};

    # handle the good tokens
    foreach ( keys %$good_tokens ) {

        # Good tokens are double
        # bad tokens are not!
        my $bad_value = 0.0;
        $bad_value = 1.0 * $bad_tokens->{$_} if exists( $bad_tokens->{$_} );

        # Only consider tokens that occur often enough
        if ( ( 2.0 * $good_tokens->{$_} + $bad_value ) >= 5.0 ) {

            # Calculate the "spamminess" of this token
            my $good_value = 2.0 * $good_tokens->{$_} / $num_good_files;
            $good_value = 1.0 if $good_value > 1.0;

            $bad_value /= $num_bad_files;
            $bad_value = 1.0 if $bad_value > 1.0;

            my $final_value = $bad_value / ( $good_value + $bad_value );
            $final_value = 0.99 if $final_value > 0.99;
            $final_value = 0.01 if $final_value < 0.01;
            $my_tokens->{$_} = $final_value;
        }
    }

    # handle the bad tokens
    foreach ( keys %$bad_tokens ) {

        # We only care about the ones that were not also in
        # the good token list
        $my_tokens->{$_} = '0.99'
          if !exists( $good_tokens->{$_} ) && $bad_tokens->{$_} >= 5.0;
    }
    $obj->{'tokens'} = $my_tokens;
    return $obj;
}

#************************************************************

=pod

=head2 case_sensitive

=over 4

=item case_sensitive([0|1])

Returns, and optionally sets, the boolean for turning on considering tokens case sensitive.

=back

=cut

#************************************************************

sub case_sensitive {
    return get_class_attribute( @_, 'case_sensitive' );
}

#************************************************************

=pod

=head2 fast_mime_decode

=over 4

=item fast_mime_decode([0|1])

Returns, and optionally sets, the boolean for using a fast mime decode algorithm.

If this evaluates to true then my own
processing is used to find and decode mime
attachements. This is much faster but does
not use the standard methods that were
written by someone who probably has a better
understanding of how this works.

=back

=cut

#************************************************************

sub fast_mime_decode {
    return get_class_attribute( @_, 'fast_mime_decode' );
}

#************************************************************

=pod

=head2 file_name

=over 4

=item file_name([$new_file_name])

Returns, and optionally sets, the current file_name. This is the name of the file that
will be read or written.

=back

=cut

#************************************************************

sub file_name {
    return get_class_attribute( @_, 'file_name' );
}

#************************************************************

=pod

=head2 get_class_attribute

Remember that the call C<$obj-E<gt>method(@parms)> is the same as
C<method($obj, @parms)>.

=over 4

=item SmallLogger::get_class_attribute($attribute_name)

If there is only one paramter, the first parameter is
assumed to be an attribute name and the default attribute value
is returned.

=item $obj->get_class_attribute($attribute_name)

If there are two parameters, then the first parameter is assumed
to be a C<SmallLogger> object and the second parameter is
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
#**                                                        **
#**  Modify the lines that should be ignored while parsing.**
#**                                                        **
#************************************************************

#************************************************************

=pod

=head2 ignore_headers

=over 4

=item Pitonyak::BayesianTokenCounter::ignore_headers

Returns the default ignore_headers hash reference

=item $obj->ignore_headers($hash_ref)

Sets the current ignore_headers hash to the parameter.

=item $obj->ignore_headers($key, [0|1])

Return the state of the current header and optionally set it

=back

=cut

#************************************************************

sub ignore_headers {
    return $initial_attributes{'ignore_headers'} if $#_ < 0;
    return $_[0]->{'ignore_headers'} if $#_ == 0;
    if ( UNIVERSAL::isa( $_[1], 'HASH' ) ) {
        $_[0]->{'ignore_headers'} = deep_copy( $_[1] );
        return $_[1];
    }
    else {
        if ( $#_ > 1 ) {
            $_[0]->{'ignore_headers'}->{ $_[1] } = $_[2];
        }
        return $_[0]->{'ignore_headers'}->{ $_[1] };
    }
}

#************************************************************

=pod

=head2 max_token_len

=over 4

=item max_token_len([$max_token_len])

Returns, and optionally sets, the the max token length accepted.

=back

=cut

#************************************************************

sub max_token_len {
    return get_class_attribute( @_, 'max_token_len' );
}

#************************************************************

=pod

=head2 min_token_len

=over 4

=item min_token_len([$max_token_len])

Returns, and optionally sets, the the min token length accepted.

=back

=cut

#************************************************************

sub min_token_len {
    return get_class_attribute( @_, 'min_token_len' );
}

#************************************************************

=pod

=head2 num_files

=over 4

=item num_files([$num_files])

Returns, and optionally sets, the numbers of files processed.

=back

=cut

#************************************************************

sub num_files {
    return get_class_attribute( @_, 'num_files' );
}

#************************************************************

=pod

=head2 num_tokens

=over 4

=item num_tokens()

Get the current number of tokens in this object.

=back

=cut

#************************************************************

sub num_tokens {
    my $hash_ref = $_[0]->{'tokens'};
    return scalar keys %$hash_ref;
}

#************************************************************

=pod

=head2 ProcessMimeMessage

=over 4

=item ProcessMimeMessage($text)

This assumes that the text string is a single email message.
The text and html portions are processed out and returned.

=back

=cut

#************************************************************

sub ProcessMimeMessage {
    my ($entity) = @_;
    my $msg = '';

    $entity->make_singlepart;

    my @keep = grep { $_->mime_type =~ /^text\/(plain|html)$/i } $entity->parts;
    $entity->parts( \@keep );

    $msg .= $entity->head->as_string;
    if ( !defined $entity->bodyhandle ) {
        foreach ( $entity->parts ) {
            $msg .= ProcessMimeMessage($_);
        }
    }
    else {
        $msg .= " " . $entity->bodyhandle->as_string;
    }
    return $msg;
}

#************************************************************

=pod

=head2 purge_tokens_with_count_less_than

=over 4

=item purge_tokens_with_count_less_than($lower_limit)

Delete tokens that occure fewer than the specified number of times

=back

=cut

#************************************************************

sub purge_tokens_with_count_less_than {
    if ( $#_ < 0 || !UNIVERSAL::isa( $_[0], 'Pitonyak::BayesianTokenCounter' ) )
    {
        carp(
"Usage: bayesian_token_counter_object->purge_tokens_with_count_less_than(<number>)"
        );
        return;
    }
    my $obj       = shift;
    my $min_count = shift;
    my $tokens    = $obj->{'tokens'};

    foreach my $key ( keys %$tokens ) {
        if ( $tokens->{$key} < $min_count ) {
            delete $tokens->{$key};
        }
    }
}

#************************************************************

=pod

=head2 rate_tokens

=over 4

=item rate_tokens($tokens_to_rate)

Returns the probability that the given tokens are bad tokens.

It is assumed that this token object is a probability token object

The calling code will look something like this:

=begin html

<code>
my $log = new Pitonyak::SmallLogger; <BR>
my $token_list = new Pitonyak::BayesianTokenCounter; <BR>
$log->log_path($program_path); <BR>
$token_list->set_log($log); <BR>
$token_list->read_from_file($config_file); <BR>
my $file_tokens = new Pitonyak::BayesianTokenCounter; <BR>
$file_tokens->tokenize_file($file_name); <BR>
my $prob = $token_list->rate_tokens($file_tokens); <BR>
</code>

=end html

=back

=cut

#************************************************************

sub rate_tokens {
    if (   $#_ < 1
        || !UNIVERSAL::isa( $_[0], 'Pitonyak::BayesianTokenCounter' )
        || !UNIVERSAL::isa( $_[1], 'Pitonyak::BayesianTokenCounter' ) )
    {
        carp("Usage: rate_tokens(<file_token_list>)");
        return undef;
    }

    my $obj = shift;
    my $log = $obj->{'log'} if exists( $obj->{'log'} );

    my $file_tokens = $_[0]->{'tokens'};    # tokens to rate
    my $my_tokens   = $obj->{'tokens'};     # probability tokens
    my %interesting_tokens;                 # Interesting tokens
                                            #
        # Temporary hash built to avoid modifying the original
        # hash but allows for previously unseen tokens to be added
        # with no ill affects to the current object
    my %token_rating;

    # Rate each email token according to how far from 0.5 it is.
    foreach ( keys %$file_tokens ) {
        $token_rating{$_} = 0.2;
        $token_rating{$_} = $my_tokens->{$_} if exists( $my_tokens->{$_} );
        $interesting_tokens{$_} = abs( 0.5 - $token_rating{$_} );
    }

    # Get the indices of the 15 most interesting tokens
    my @most_interesting =
      sort { $interesting_tokens{$b} <=> $interesting_tokens{$a} }
      keys %interesting_tokens;
    @most_interesting = @most_interesting[ 0 .. 14 ];

    # Calculate Bayesian probability of the tokens
    my $prod           = 1;
    my $one_minus_prod = 1;
    foreach my $a_token (@most_interesting) {
        $prod           *= $token_rating{$a_token};
        $one_minus_prod *= ( 1.0 - $token_rating{$a_token} );
        $log->write_log_type( 'P',
            "$_[1] interesting $token_rating{$a_token} $a_token" )
          if defined($log);
    }

    # Probably bad if $probability_of_spam > 0.9
    my $probability_of_spam = 1.0;
    my $denominator         = $prod + $one_minus_prod;
    $probability_of_spam = $prod / $denominator if $denominator > 0.0000001;

    $log->write_log_type( 'T',
        "$_[1] is bad with probability of $probability_of_spam" )
      if defined($log);

    # Is it spam?
    return $probability_of_spam;
}

#************************************************************

=pod

=head2 read_from_file

=over 4

=item Pitonyak::BayesianTokenCounter::read_from_file($file_name)

This will create an appropriate object and then read the file.

=item $obj->read_from_file($file_name)

Read the current file and then return the object used to read it.

=back

=cut

#************************************************************

sub read_from_file {
    if ( $#_ < 0 ) {
        carp("Usage: read_from_file(<file_name>)");
        return;
    }
    if ( !UNIVERSAL::isa( $_[0], 'Pitonyak::BayesianTokenCounter' ) ) {
        my $token_list = new Pitonyak::BayesianTokenCounter;
        return $token_list->read_from_file(@_);
    }

    my $obj = shift;
    my $log;
    $log = $obj->{'log'} if exists( $obj->{'log'} );

    my $file_name = $obj->{'file_name'};
    $file_name = shift if $#_ >= 0;
    if ( !defined($file_name) || length($file_name) == 0 ) {
        my $message = "Can not read a file unless the file name is given";
        carp($message);
        $log->error($message) if defined($log);
        return;
    }
    $obj->{'file_name'} = $file_name;
    $log->debug("Opening file <$file_name") if defined($log);
    my $handle = new IO::File;
    if ( $handle->open( '<' . $file_name ) ) {
        my $reading_tokens = 0;
        my $xml_string     = '';
        my %token_hash;
        while (<$handle>) {
            chomp;
            if ($reading_tokens) {
                if (/^\s*(\d*\.?\d*)\s+(.+)$/) {
                    $token_hash{$2} = $1;
                }
            }
            elsif (/^\*+\s*tokens\s*\*+$/) {
                $reading_tokens = 1;
            }
            else {
                $xml_string .= $_;
            }
        }
        $handle->close();
        my $temp_hash = xml_to_object($xml_string);
        foreach my $key ( keys %initial_attributes ) {
            $obj->{$key} = $temp_hash->{$key} unless $key eq 'tokens';
        }
        $obj->{'file_name'} = $file_name;
        $obj->{'tokens'}    = \%token_hash;
    }
    else {
        my $message = "Failed to open ($file_name) because $!";
        carp($message);
        $log->error($message) if defined($log);
    }
    return $obj;
}

#************************************************************

=pod

=head2 set_log

=over 4

=item set_log([$logger_instance])

If the logger instance is not present, then any existing logger will be deleted
from the object.

If the object is present, then it must be an instance of Pitonyak::SmallLogger
and it is set as the object to use.

=back

=cut

#************************************************************

sub set_log {
    my $obj = shift;
    if ( $#_ < 0 ) {

        # No parameter, so delete the log entry
        delete $obj->{'log'};
    }
    else {
        my $new_log = shift;
        if ( UNIVERSAL::isa( $new_log, 'Pitonyak::SmallLogger' ) ) {
            $obj->{'log'} = $new_log;
        }
        else {
            carp("I expected to be called with a Pitonyak::SmallLogger!");
        }
    }
}

#************************************************************

=pod

=head2 skip_html_comments

=over 4

=item skip_html_comments([0|1])

Returns, and optionally sets, the true/false value for skipping HTML coments.

=back

=cut

#************************************************************

sub skip_html_comments {
    return get_class_attribute( @_, 'skip_html_comments' );
}

#************************************************************

=pod

=head2 tokenize_file

=over 4

=item Pitonyak::BayesianTokenCounter::tokenize_file($file_name)

An object is created and then the file is tokenized into the object

=item $obj->tokenize_file($file_name)

If the $file_name is '-', then STDIN is read. If not, then the file is opened from disk and read.
The file is then tokenized.

=back

=cut

#************************************************************

sub tokenize_file {
    if ( $#_ < 0 ) {
        carp("Usage: tokenize_file(<file_name>)");
        return;
    }
    if ( !UNIVERSAL::isa( $_[0], 'Pitonyak::BayesianTokenCounter' ) ) {
        my $token_list = new Pitonyak::BayesianTokenCounter;
        return $token_list->tokenize_file(@_);
    }

    my $obj       = shift;
    my $log       = $obj->{'log'} if exists( $obj->{'log'} );
    my $file_name = shift if $#_ >= 0;
    if ( !defined($file_name) || length($file_name) == 0 ) {
        carp("Can not write to a file unless the file name is given");
        return;
    }
    if ( $obj->fast_mime_decode() ) {

        # Enable slurp mode!
        local $/;
        undef $/;
        if ( $file_name eq "-" ) {
            $obj->tokenize_string(<STDIN>);
        }
        else {
            my $handle = new IO::File;
            if ( !$handle->open( $file_name, 'r' ) ) {
                $log->error("Failed to open file $file_name because $!")
                  if defined($log);
                return;
            }
            $obj->tokenize_string(<$handle>);
            $handle->close();
        }
    }
    else {
        my $mime_entity;
        my $parser = new MIME::Parser;
        $parser->output_to_core(1);
        $parser->extract_uuencode(1);
        if ( $file_name eq "-" ) {
            $mime_entity = $parser->parse( \*STDIN );
        }
        else {
            my $handle = new IO::File;
            if ( !$handle->open( $file_name, 'r' ) ) {
                $log->error("Failed to open file $file_name because $!")
                  if defined($log);
                return;
            }
            $mime_entity = $parser->parse($handle);
            $handle->close();
        }
        if ( !defined($mime_entity) ) {
            $log->error("Failed to open file $file_name because $!")
              if defined($log);
            return;
        }
        else {
            $obj->tokenize_string( ProcessMimeMessage($mime_entity) );
        }
    }

    $obj->{'num_files'}++;
    $log->debug("$obj->{num_files} tokenized $file_name") if defined($log);

    return $obj;
}

#************************************************************

=pod

=head2 tokenize_string

=over 4

=item tokenize_string(@strings_to_tokenize)

This assumes that the list of strings is a mail message to be tokenized.
In the program, the entire file is read into a single variable and then
this is called.

=back

=cut

#************************************************************

sub tokenize_string {
    if ( $#_ < 0 ) {
        carp("Usage: tokenize_string(<text>)");
        return;
    }
    if ( !UNIVERSAL::isa( $_[0], 'Pitonyak::BayesianTokenCounter' ) ) {
        my $token_list = new Pitonyak::BayesianTokenCounter;
        return $token_list->tokenize_string(@_);
    }
    if ( $#_ < 1 ) {
        carp("Usage: tokenize_string(<text>)");
        return;
    }

    my $obj            = shift;
    my $log            = $obj->{'log'} if exists( $obj->{'log'} );
    my $parse_64       = $obj->fast_mime_decode();
    my $case_sensitive = $obj->case_sensitive();

    my $content_type_hash_ref = $obj->{'content_types'};
    my $max_token_length      = $obj->{'max_token_len'};
    my $min_token_length      = $obj->{'min_token_len'};
    my $last_header_field     = "";
    my $this_header_field     = "";
    my $boundary_line;
    my $boundary_test;

    my $skip_to_next_boundary = 0;
    my $skip_644              = 0;
    my $skip_pgp_block        = 0;
    my $skip_base64           = 0;
    my $skip                  = 0;
    my $base64_text;

    my $found_boundary_find_type = 0;
    my $token_hash               = $obj->{'tokens'};
    my $line_number              = 0;
  ONE_STRING: foreach my $one_string (@_) {

        # Rip out HTML and XML comments
        $one_string =~ s/\<\!\-.*?\-\>//gso if $obj->skip_html_comments();

      ONE_LINE: foreach ( split ( /\n/, $one_string ) ) {
            ++$line_number;
            chomp;
            $this_header_field = "";
            if (/(^.*?):/o) {
                $this_header_field = lc $1;
                $last_header_field = $this_header_field;
            }
            if ( $last_header_field eq 'content-type' && /boundary=(\S+)/io ) {

                #
                # Some boundary lines are enclosed in quotes, some are not
                #
                $boundary_line = $1;
                $boundary_line = $1 if $boundary_line =~ /^"(.*)"$/o;
                $boundary_line = $1 if $boundary_line =~ /^'(.*)'$/o;

                #
                # If the boundary_line contains special characters, then this
                # will cause a problem in the comparisons so the $boundary_test
                # variable will precede the special characters with a backslash.
                # this fix thanks to Paul Hodges paul@qbss.com
                ( $boundary_test = $boundary_line ) =~
                  s/([*$()\[\]{}|\\\^+?.])/\\$1/g;

                $log->write_log_type( 'T',
                    "Found the boundary ($boundary_line)" )
                  if defined($log);
                next ONE_LINE;
            }

            #
            # Usually NOT skipping so this allows one check rather than
            # multiple checks for every line!
            #
            if ($skip) {
                if ($skip_base64) {

                    # remember that I chomped off the new line
                    $base64_text .= "$_\n"
                      if length($_) > 40
                      && index( $_, ' ' ) < $[
                      && ( !defined($boundary_line) || !/$boundary_test/ );
                }
                if ($skip_to_next_boundary) {
                    next ONE_LINE if !/$boundary_test/;
                    $log->write_log_type( 'T',
                        "Found the next boundary at line $line_number" )
                      if defined($log);
                    $found_boundary_find_type = 1;
                    $skip_to_next_boundary    = 0;
                    $skip                     = 0;
                    if ( $skip_base64 && length($base64_text) > 0 ) {
                        $log->write_log_type( 'T',
"Decoded and tokenizing valid base64 content at line $line_number"
                          )
                          if defined($log);
                        my $decoded = MIME::Base64::decode($base64_text);
                        undef $base64_text;
                        $obj->tokenize_string($decoded);
                    }
                    $skip_base64 = 0;
                    undef $base64_text;
                }
                elsif ($skip_pgp_block) {
                    if (/^-*END\s+PGP\s+PUBLIC\s+KEY\s+BLOCK-*$/io) {
                        $skip_pgp_block = 0;
                        $skip           = 0;
                    }
                    next ONE_LINE;
                }
                elsif ($skip_644) {
                    next ONE_LINE if /^end$/o;
                    $skip_644 = 0;
                    $skip     = 0;
                }
            }
            elsif (/^-*BEGIN\s+PGP\s+PUBLIC\s+KEY\s+BLOCK-*$/io) {
                $log->write_log_type( 'D', "Skipping PGP public key" )
                  if defined($log);
                $skip_pgp_block = 1;
                $skip           = 1;
                next ONE_LINE;
            }
            elsif ($found_boundary_find_type) {
                if (/^content-type:\s+(([^\/=]+).*)$/io) {
                    my $content_type = lc $2;
                    if ( !exists( $content_type_hash_ref->{$content_type} ) ) {
                        $log->error(
"Ignoring unknown content type ($1) did not find type ($2)"
                          )
                          if defined($log);
                        $skip_to_next_boundary = 1;
                    }
                    elsif ( $content_type_hash_ref->{$content_type} ) {
                        $log->debug("Processing content type ($1)")
                          if defined($log);
                        $skip_to_next_boundary = 0;
                    }
                    else {
                        $log->debug("Ignoring content type ($1)")
                          if defined($log);
                        $skip_to_next_boundary = 1;
                    }
                    $skip                     = $skip_to_next_boundary;
                    $found_boundary_find_type = 0;
                }
                next ONE_LINE;
            }
            elsif ( defined($boundary_line) && /$boundary_test/ ) {
                $log->write_log_type( 'T',
                    "found a boundary, must determine type" )
                  if defined($log);
                $found_boundary_find_type = 1;
            }

            # If this is an entire message with a content type that I do not support
            elsif (
                /^content-type:\s+(([^\/=]+).*)$/io
                && (   !exists( $content_type_hash_ref->{ lc $2 } )
                    || !$content_type_hash_ref->{ lc $2 } )
              )
            {
                if ( !exists( $content_type_hash_ref->{ lc $2 } ) ) {
                    $log->error(
"Ignoring entire message with unknown content type ($1) did not find type ($2)"
                      )
                      if defined($log);
                }
                else {
                    $log->debug("Ignoring entire message content type ($1)")
                      if defined($log);
                }
                last ONE_STRING;
            }

            # Check for a uuencoded attachement
            # and then simply ignore it!
            elsif (/^begin\s+644\s+/o) {
                $log->debug("Skipping UUENCODE block") if defined($log);
                $skip_644 = 1;
                $skip     = 1;
            }

            # If this next conditional is true then there is a supported
            # type that has been encoded as base64 which we can not directly
            # tokenize. I hate it when that happens!
            elsif ( $parse_64 && /^(content-transfer-encoding:\s*base64)/io ) {
                $skip_base64 = 1;
                $skip        = 1;
                $base64_text = '';
                if ( defined($boundary_line) ) {
                    $log->debug(
"Found $1 in a supported type, collecting encoded text to next boundary"
                      )
                      if defined($log);
                    $skip_to_next_boundary = 1;
                    next ONE_LINE;
                }
                else {
                    $log->debug(
"Found $1 and no boundaries were defined, collecting encoded text to the end of the text"
                      )
                      if defined($log);
                    next ONE_LINE;
                }
            }
            elsif ( exists( $obj->{'ignore_headers'}->{$this_header_field} ) ) {
                $log->write_log_type( 'T', "Ignoring $_" ) if defined($log);
            }
            else {

                # This means split on anything that is NOT a word character
                # but also do not split on $, ', or -
                # foreach ( split (/[^\w'$-]/o) ) {
                # This addition prevents words with the high bit set
                # from causing a split.
                foreach ( split (/[^\w\200-\377'\$\.\-]/o) ) {

                    # Strip starting and ending "'" and "-" characters, and a few codes
                    # (like "20" or "3D") on the front of words, left over from
                    # unhandled "%20" and "=3D" constructs.
                    $_ = $1 if /^(?:20|2e|2E|2f|2F|3d|3D)(.*?)$/;
                    s/^[_'\.\-]*(.*?)[_'\.\-]*$/$1/;

                    if (   $min_token_length < length($_)
                        && length($_) < $max_token_length
                        && not /^\d*$/ )
                    {

                        # See if the line is just a bunch of repeated characters, if so, ignore them
                        # If we have a special character then there is a problem with the regular expression
                        my $first_char = substr( $_, 0, 1 );
                        $first_char = '\\' . $first_char
                          if ( $first_char eq '.'
                            || $first_char eq '$'
                            || $first_char eq '/'
                            || $first_char eq '\\' );
                        if (/^$first_char+$/) {
                        }
                        elsif ($case_sensitive) {
                            $token_hash->{$_} += 1.0;
                        }
                        else {
                            $token_hash->{ lc $_ } += 1.0;
                        }
                    }
                }
            }
        }
    }
    if ( $skip_base64 && length($base64_text) > 0 ) {
        $log->write_log_type( 'T',
"Decoded and tokenizing valid base64 content at end of text (line $line_number)"
          )
          if defined($log);
        my $decoded = MIME::Base64::decode($base64_text);
        undef $base64_text;
        $obj->tokenize_string($decoded);
    }
    $skip_base64 = 0;
    undef $base64_text;

    return $obj;
}

#************************************************************

=pod

=head2 tokens

=over 4

=item tokens([$token_hash_ref])

Returns, and optionally sets, the internal token hash.

=back

=cut

#************************************************************

sub tokens {
    return $initial_attributes{'tokens'} if $#_ < 0;
    if ( $#_ > 0 ) {
        my $ref_type = ref( $_[1] );
        if ( $ref_type eq 'HASH' ) {
            $_[0]->{'tokens'} = deep_copy( $_[1] );
        }
        else {
            confess("Parameter to tokens must be a HASH, not a $ref_type");
        }
    }
    return $_[0]->{'tokens'};
}

#************************************************************

=pod

=head2 write_to_file

=over 4

=item write_to_file([$file_name])

Write the tokens to either the current file name, or to the new
file name as specified by the parameter.

This can be slow because the tokens are sorted by frequencey and name.

=back

=cut

#************************************************************

sub write_to_file {
    if ( $#_ < 0 || !UNIVERSAL::isa( $_[0], 'Pitonyak::BayesianTokenCounter' ) )
    {
        carp(
            "Usage: bayesian_token_counter_object->write_to_file([<file_name>])"
        );
        return;
    }

    my $obj       = shift;
    my $log       = $obj->{'log'} if exists( $obj->{'log'} );
    my $file_name = $obj->{'file_name'};
    $file_name = shift if $#_ >= 0;
    if ( !defined($file_name) || length($file_name) == 0 ) {
        carp("Can not write to a file unless the file name is given");
        return;
    }
    $obj->{'file_name'} = $file_name;

    #
    # Although I could simply slam out the hash, I choose not to
    # because the token list is large and XML has a lot of overhead.
    # It is better, from a space and time perspective, to write
    # the tokens in a different format!
    # Turn this object into a simple hash but do NOT copy the
    # tokens.
    #
    my %temp_hash;
    foreach my $key ( keys %initial_attributes ) {
        $temp_hash{$key} = $obj->{$key} unless $key eq 'tokens';
    }

    #
    # Convert the hash to an XML string suitable for
    # writing to a file!
    #
    my $xml_string = object_to_xml( \%temp_hash );
    my $tokens     = $obj->{'tokens'};
    my $handle     = new IO::File;
    $log->debug("Ready to open file for writing <$file_name") if defined($log);
    if ( $handle->open( '>' . $file_name ) ) {
        $handle->print($xml_string);
        $handle->print("\n*******tokens******\n");
        my $num_tokens = 0;
        foreach (
            sort { $tokens->{$b} <=> $tokens->{$a} || $a cmp $b }
            keys %$tokens
          )
        {
            $handle->print( right_fmt( 8, $tokens->{$_} ) . " $_\n" );
            ++$num_tokens;
        }
        $handle->print("*******$num_tokens tokens******\n");
        $handle->close();
    }
    else {
        my $message = "Failed to open file $file_name because $!";
        carp($message);
        $log->error($message) if defined($log);
    }
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

=head2 March 13, 1998

Version 1.00 First release

=head2 September 10, 2002

Version 1.01 Changed internal documentation to POD documentation. Added parameter checking.

=cut

#************************************************************

1;
