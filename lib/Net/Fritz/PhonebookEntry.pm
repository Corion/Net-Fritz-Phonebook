package Net::Fritz::PhonebookEntry;
use strict;
use Moo 2;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use Net::Fritz::PhonebookEntry::Number;
use Net::Fritz::PhonebookEntry::Mail;

use vars '$VERSION';
$VERSION = '0.01';

use Data::Dumper;

=head1 NAME

Net::Fritz::PhonebookEntry - a Fritz!Box phone book entry

=head1 ACCESSORS

=head2 C< phonebook >

A weak reference to the phone book containing this entry

=cut

has 'phonebook' => (
    is => 'ro',
    weak_ref => 1,
);

=head2 C< uniqueid >

An opaque value assigned by the Fritz!Box to this entry

=cut

has 'uniqueid' => (
    is => 'rw',
);

=head2 C< category >

The category of this entry

Numeric value, default 0

=cut

has 'category' => (
    is => 'rw',
    default => 0,
);

=head2 C< numbers >

Arrayref of the telephone numbers associated with this entry. The elements
will be L<Net::Fritz::PhonebookEntry::Number>s.

=cut

has 'numbers' => (
    is => 'rw',
    default => sub{ [] },
);

=head2 C< email_addresses >

Arrayref of the email addresses associated with this entry. The elements will be
L<Net::Fritz::PhonebookEntry::Email> objects.

=cut

has 'email_addresses' => (
    is => 'rw',
    default => sub{ [] },
);

=head2 C< name >

The name displayed in the phone book. This will likely be the name of a person.

=cut

has 'name' => (
    is => 'rw',
);

=head2 C< ringtoneidx >

The index of the ringtone to use for this entry?

=cut

has 'ringtoneidx' => (
    is => 'rw',
    #default => '',
);

around BUILDARGS => sub ( $orig, $class, %args ) {
    my %self;
    if( exists $args{ contact }) {
        my $contact = $args{ contact }->[0];
        my $telephony = $contact->{telephony}->[0];
        %self = (
            phonebook => $args{ phonebook },
            name     => $contact->{ person }->[0]->{realName}->[0],
            uniqueid => $contact->{uniqueid}->[0],
            category => $contact->{category}->[0],
            numbers => [map { Net::Fritz::PhonebookEntry::Number->new( %$_ ) }
                           @{ $telephony->{number} }
                       ],
            email_addresses => [map { Net::Fritz::PhonebookEntry::Mail->new( %$_ ) }
                           @{ $telephony->{services} }
                       ],
        );
    } else {
        %self = %args;
    };
    return $class->$orig( %self );
};

=head2 C<< $contact->build_structure >>

  my $struct = $contact->build_structure;
  XMLout( $struct );

Returns the contact as a structured hashref that XML::Simple will serialize to
the appropriate XML to write a contact.

=cut

# This is the reverse of BUILDARGS, basically
sub build_structure( $self ) {
    my %optional_fields;
    if( defined $self->uniqueid ) {
        $optional_fields{ uniqueid } = [$self->uniqueid];
    };

    if( defined $self->ringtoneidx ) {
        $optional_fields{ ringtoneidx } [$self->ringtoneidx] ;
    };
    my $res = {
        person => [{
            realName => [$self->name],
        }],
        telephony => [{
                number => [map { $_->build_structure } @{ $self->numbers }],
                services =>
                    [map { $_->build_structure } @{ $self->email_addresses }],
        }],
        category => [$self->category],
        %optional_fields,
    };
}

=head2 C<< $contact->add_number( $number, $type='home' ) >>

  $contact->add_number('555-12345');
  $contact->add_number('555-12346', 'fax_work');

Adds a number to the entry. No check is made whether that number is already
associated with that phone book entry. You can alternatively pass in a
l<Net::Fritz::PhonebookEntry::Number> object.

=cut

sub add_number($self, $n, $type='home') {
    if( ! ref $n) {
        $n = Net::Fritz::PhonebookEntry::Number->new( content => $n, type => $type );
    };
    push @{$self->numbers}, $n;
};

=head2 C<< $contact->add_email( $mail ) >>

  $contact->add_email('example@example.com');

Adds an email address to the entry. No check is made whether that address is
already associated with that phone book entry. You can alternatively pass in a
l<Net::Fritz::PhonebookEntry::Email> object.

=cut

sub add_email($self, $m) {
    if( ! ref $m) {
        $m = Net::Fritz::PhonebookEntry::Mail->new( email => [{ content => $m }]);
    };
    push @{$self->email_addresses}, $m;
};

=head2 C<< $contact->create() >>

  $contact->create(); # save to Fritz!Box
  $contact->create(phonebook => $other_phonebook);

Creates the contact in the phonebook given at creation or in the call. The
allowed options are

=over 4

=item B<phonebook_id>

The id of the phonebook to use

=item B<phonebook>

The phonebook object to use

=back

If neither the id nor the object are given, the C<phonebook>

=cut

sub create( $self, %options ) {
    if( ! defined $options{ phonebook_id }) {
        $options{ phonebook } ||= $self->phonebook;
        $options{ phonebook_id } = $options{ phonebook }->id;
    };
    $self->service->call('AddPhonebookEntry',
        NewPhonebookID => $options{ phonebook_id },
    )->data
}

sub delete( $self, %options ) {
    $self->service->call('DeletePhonebookEntry',
        NewPhonebookID => $self->phonebook->id,
        NewPhonebookEntryID => $self->id
    )->data
}

sub save( $self ) {
    my $payload = $self->build_structure;
    $self->service->call('AddPhonebookEntry',
        NewPhonebookID => $self->phonebook->id,
        NewPhonebookEntryID => $self->id,
        NewPhonebookEntryData => $payload,
    )->data
}

1;

=head1 REPOSITORY

The public repository of this module is
L<http://github.com/Corion/Net-Fritz-Phonebook>.

=head1 SUPPORT

The public support forum of this module is
L<https://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Net-Fritz-Phonebook>
or via mail to L<net-fritz-phonebook-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2017 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
