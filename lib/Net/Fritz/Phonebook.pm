package Net::Fritz::Phonebook;
use strict;
use Moo 2;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use XML::Simple; # because that's what Net::Fritz uses...

use vars '$VERSION';
$VERSION = '0.01';

use Data::Dumper;

=head1 NAME

Net::Fritz::PhoneBook - update the Fritz!Box phonebook from Perl

=head1 SYNOPSIS

This module uses the API exposed by the Fritz!Box via TR064 to read, create and
update contacts in a phone book. This uses the C<X_AVM-DE_OnTel> service, which
is specific to the AVM Fritz!Box line of products.

=cut

has 'service' => (
    is => 'ro',
);

has '_xs' => (
    is => 'lazy',
    default => sub($self) {
        $self->service->fritz->_xs
    }
);

has 'id' => (
    is => 'ro',
);

has 'metadata' => (
    is => 'lazy',
    default => sub($self) {
        my $res = $self->service->call('GetPhonebook', NewPhonebookID => $self->id )->data;
        $res
    },
);

has 'name' => (
    is => 'lazy',
    default => sub($self) {
        $self->metadata->{NewPhonebookName}
    },
);

has 'url' => (
    is => 'lazy',
    default => sub($self) {
        $self->metadata->{NewPhonebookURL}
    },
);

has 'content' => (
    is => 'lazy',
    default => sub($self) {
        my $res = $self->service->fritz->_ua->get($self->url);
        #warn $res->content;
        $self->_xs->parse_string( $res->content );
    },
);

has 'entries' => (
    is => 'lazy',
    builder => 1,
);

sub create( $self, %options ) {
    $self->service->call('AddPhonebook')->data
}

sub delete( $self, %options ) {
    $self->service->call('DeletePhonebook', NewPhonebookID => $self->id )->data
}

sub _build_entries( $self, %options ) {
    my $c = $self->content;
    [map { Net::Fritz::PhonebookEntry->new( phonebook => $self, contact => [$_] ) } @{ $self->content->{phonebook}->[0]->{contact} }];
}

sub add_entry( $self, $entry ) {
    my $s = $entry->build_structure;

    my $xml = XMLout({ contact => [$s]});

    my $res = $self->service->call('SetPhonebookEntry',
        NewPhonebookID => $self->id,
        NewPhonebookEntryID => '', # new entry
        NewPhonebookEntryData => $xml,
    );
};

package Net::Fritz::PhonebookEntry;
use strict;
use Moo 2;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

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


package Net::Fritz::PhonebookEntry::Number;
use strict;
use Moo 2;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use Data::Dumper;

use vars '$VERSION';
$VERSION = '0.01';

has entry => (
    is => 'ro',
    weak_ref => 1,
);

has 'uniqueid' => (
    is => 'ro',
);

has 'person' => (
    is => 'ro',
);

has 'quickdial' => (
    is => 'ro',
    default => '',
);

has 'vanity' => (
    is => 'ro',
    default => '',
);

has 'prio' => (
    is => 'rw',
    default => '',
);

=head2 C<< type >>

  home
  mobile
  work
  fax_work

All other strings get displayed as "Sonstige" but get preserved.
  
=cut

has 'type' => (
    is => 'rw',
    default => 'home',
);

has 'content' => (
    is => 'rw',
);

sub build_structure( $self ) {
    return {
        type      => $self->type,
        content   => $self->content,
        quickdial => $self->quickdial,
        vanity    => $self->vanity,
        prio      => $self->prio,
    }
}

package Net::Fritz::PhonebookEntry::Mail;
use strict;
use Moo 2;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use Data::Dumper;

use vars '$VERSION';
$VERSION = '0.01';

has entry => (
    is => 'ro',
    weak_ref => 1,
);

has 'classifier' => (
    is => 'rw',
    default => 'private',
);

has 'content' => (
    is => 'rw',
);

around BUILDARGS => sub( $orig, $class, %args ) {
    my %self = (
        exists $args{ email }->[0]->{classifier}
        ? (classifier => $args{ email }->[0]->{classifier}) : (),
        content    => $args{ email }->[0]->{content},
    );
    $class->$orig( %self );
};

sub build_structure( $self ) {
    return {
        email => [{
            classifier => $self->classifier,
            content => $self->content,
        }],
    }
}

1;

=head1 SEE ALSO

L<https://avm.de/fileadmin/user_upload/Global/Service/Schnittstellen/X_contactSCPD.pdf>

=cut
