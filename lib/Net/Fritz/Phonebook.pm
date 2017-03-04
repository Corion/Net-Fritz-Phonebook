package Net::Fritz::Phonebook;
use strict;
use Moo;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use Data::Dumper;

=head1 NAME

Net::Fritz::PhoneBook - update the Fritz!Box phonebook from Perl

=head1 SYNOPSIS

This module uses the API exposed by the Fritz!Box via TR064 to read, create and
update contacts in a phone book.

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
        #print Dumper $res;
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
        $self->_xs->parse_string( $res->content );
    },
);

sub create( $self, %options ) {
    $self->service->call('AddPhonebook')->data
}

sub delete( $self, %options ) {
    $self->service->call('DeletePhonebook', NewPhonebookID => $self->id )->data
}

sub entries( $self, %options ) {
    my $c = $self->content;
    #warn Dumper $c;
    map { Net::Fritz::PhonebookEntry->new( phonebook => $self, %$_ ) } @{ $self->content->{phonebook}->[0]->{contact} };
    #$options{ timestamp } ||= '1900-01-01 00:00:01';
    #my $count = $self->service->call('GetNumberOfEntries', timestamp => $options{ timestamp })->data
    #$self->service->call('GetPhonebookEntries', timestamp => $options{ timestamp })->data
}

package Net::Fritz::PhonebookEntry;
use strict;
use Moo;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use Data::Dumper;
#has 'phonebook' => (
#    is => 'ro',
#);

has 'uniqueid' => (
    is => 'ro',
);

has 'person' => (
    is => 'ro',
);

has 'telephony' => (
    is => 'ro',
);

has 'category' => (
    is => 'ro',
);

has 'numbers' => (
    is => 'ro',
    builder => 1,
    lazy => 1,
);

sub name($self) {
    $self->person->[0]->{realName}->[0];
};

sub _build_numbers($self) {
    my $t = $self->telephony;
    [map { Net::Fritz::PhonebookEntry::Number->new( entry => $self, %$_ ) } @{ $t->[0]->{number} }];
};

sub type( $self ) {
    @{ $self->category };
};

package Net::Fritz::PhonebookEntry::Number;
use strict;
use Moo;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';

use Data::Dumper;
#has 'phonebook' => (
#    is => 'ro',
#);

has entry => (
    is => 'ro',
);

has 'uniqueid' => (
    is => 'ro',
);

has 'person' => (
    is => 'ro',
);

=head2 C<< type >>

  home
  mobile
  work
  fax_work

=cut

has 'type' => (
    is => 'ro',
);

has 'content' => (
    is => 'ro',
);

sub number($self) {
    $self->content
};

#sub GetPhonebookList($self) {
#    my ($self) = @_;
#    $self->service->call('GetPhonebookList');
#}

1;

=head1 SEE ALSO

L<https://avm.de/fileadmin/user_upload/Global/Service/Schnittstellen/X_contactSCPD.pdf>

=cut
