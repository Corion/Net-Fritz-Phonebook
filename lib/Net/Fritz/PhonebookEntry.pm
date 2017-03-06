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
has 'phonebook' => (
    is => 'ro',
    weak_ref => 1,
);

has 'uniqueid' => (
    is => 'rw',
);

has 'category' => (
    is => 'rw',
    default => 0,
);

has 'numbers' => (
    is => 'rw',
    default => sub{ [] },
);

has 'email_addresses' => (
    is => 'rw',
    default => sub{ [] },
);

has 'name' => (
    is => 'rw',
);

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

# This is the reverse of BUILDARGS, basically
sub build_structure( $self ) {
    my @uniqueid;
    if( defined $self->uniqueid ) {
        @uniqueid = (uniqueid => [$self->uniqueid] );
    };

    my @ringtoneidx;
    if( defined $self->ringtoneidx ) {
        @ringtoneidx = (ringtoneidx => [$self->ringtoneidx] );
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
        @ringtoneidx,
        category => [$self->category],
        @uniqueid,
    };
}

sub add_number($self, $n, $type='home') {
    if( ! ref $n) {
        $n = Net::Fritz::PhonebookEntry::Number->new( content => $n, type => $type );
    };
    push @{$self->numbers}, $n;
};

sub add_email($self, $m) {
    if( ! ref $m) {
        $m = Net::Fritz::PhonebookEntry::Mail->new( email => [{ content => $m }]);
    };
    push @{$self->email_addresses}, $m;
};

sub create( $self, %options ) {
    $self->service->call('AddPhonebookEntry',
        NewPhonebookID => $self->phonebook->id,
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
