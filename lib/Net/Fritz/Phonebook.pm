package Net::Fritz::Phonebook;
use strict;
use Moo 2;
use Filter::signatures;
use feature 'signatures';
no warnings 'experimental::signatures';
use Carp qw(croak);

use XML::Simple; # because that's what Net::Fritz uses...
use Net::Fritz::PhonebookEntry;

use vars '$VERSION';
$VERSION = '0.01';

=head1 NAME

Net::Fritz::Phonebook - manage the Fritz!Box phonebook from Perl

=head1 SYNOPSIS

  my $fb = Net::Fritz::Box->new(
      username => $username,
      password => $password,
      upnp_url => $host,
  );
  my $device = $fb->discover;
  if( my $error = $device->error ) {
      die $error
  };
  my $services = $device->find_service_names(qr/X_AVM-DE_OnTel/);
  my $service = $services->data->[0];

  my @phonebooks = Net::Fritz::Phonebook->list($service);

This module uses the API exposed by the Fritz!Box via TR064 to read, create and
update contacts in a phone book. This uses the C<X_AVM-DE_OnTel> service, which
is specific to the AVM Fritz!Box line of products.

=head1 ACCESSORS

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

=head2 C<< id >>

  print $phonebook->id;

The ID of the phone book on the Fritz!Box

=cut

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

=head2 C<< name >>

  print $phonebook->name;

The user visible name of the phone book on the Fritz!Box

=cut

has 'name' => (
    is => 'lazy',
    default => sub($self) {
        $self->metadata->{NewPhonebookName}
    },
);

=head2 C<< url >>

  print $phonebook->url;

The URL of the phone book on the Fritz!Box

This URL is used to access the phone book contents.

=cut

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
        my $r = $res->decoded_content;
        $self->_xs->parse_string( $r );
    },
);

=head2 C<< entries >>

  for my $entry ( @{ $phonebook->entries }) {
      print $entry->name
  };

Arrayref of the entries in this phone book. Each entry is
a L<Net::Fritz::Phonebook::Entry>.

=cut

has 'entries' => (
    is => 'lazy',
    builder => 1,
);

=head1 METHODS

=head2 C<< $phonebook->create >>

  $phonebook->create();

Creates the phone book on the FritzBox. Entries of this phone book are not
saved.

=cut

sub create( $self, %options ) {
    $self->service->call('AddPhonebook')->data
}

=head2 C<< $phonebook->delete >>

  $phonebook->delete();

Deletes the phone book on the FritzBox. All entries of this phone book are also
deleted with the phone book.

=cut

sub delete( $self, %options ) {
    $self->service->call('DeletePhonebook', NewPhonebookID => $self->id )->data
}

sub _build_entries( $self, %options ) {
    my $c = $self->content;
    [map { Net::Fritz::PhonebookEntry->new( phonebook => $self, contact => [$_] ) } @{ $self->content->{phonebook}->[0]->{contact} }];
}

=head2 C<< $phonebook->add_entry >>

  $phonebook->add_entry( $new_contact );

Saves an entry in the phone book on the FritzBox.

=cut

sub add_entry( $self, $entry ) {
    my $s = $entry->build_structure;

    my $xml = XMLout({ contact => [$s]});

    my $res = $self->service->call('SetPhonebookEntry',
        NewPhonebookID => $self->id,
        NewPhonebookEntryID => '', # new entry
        NewPhonebookEntryData => $xml,
    );
};

sub _get_service( $self, %options ) {
    my $service = $options{ service };
    if( ! $service ) {
        my $services = $options{ device }->find_service_names($options{name});
        $service = $services->data->[0];
    };
    $service
}

sub _get_phonebook_service( $self, %options ) {
    $self->_get_service( name => qr/X_AVM-DE_OnTel/, %options )
};

=head2 C<< Net::Fritz::Phonebook->by_name( $device, $name ) >>

  my $device = $fb->discover;
  my $phonebook = Net::Fritz::Phonebook->by_name( device => $device, name => 'Telefonbuch' );

Utility function to find a phonebook by name.

=cut

sub by_name( $class, %options ) {
    my $name = delete $options{ name };
    my @phonebooks = Net::Fritz::Phonebook->list(%options);

    (my $book) = grep { $name eq $_->name }
                   @phonebooks;
    $book
}

=head2 C<< Net::Fritz::Phonebook->list( $service ) >>

  my $device = $fb->discover;
  my $services = $device->find_service_names(qr/X_AVM-DE_OnTel/);
  my @phonebooks = Net::Fritz::Phonebook->list( service => $services->data->[0] );

=cut

sub list( $class, %options ) {
    my $service = $class->_get_phonebook_service( %options );

    my $r = $service->call('GetPhonebookList');
    croak $r->error if $r->error;
    my $d = $r->data;
    return
      map { $class->new( id => $_, service => $service ) }
        split /,/, $service->call('GetPhonebookList')->data->{NewPhonebookList}
}

=head2 C<< Net::Fritz::Phonebook->reload >>

  $phonebook->reload();

Refreshes the content of the phonebook from the Fritz!Box. This is useful if you
have added or removed entries from the phone book and want to fetch the state
on the Fritz!Box again.

=cut

sub reload( $self ) {
    delete $self->{content};
    delete $self->{entries};
};

1;

=head1 SEE ALSO

L<https://avm.de/fileadmin/user_upload/Global/Service/Schnittstellen/X_contactSCPD.pdf>

=cut

=head1 REPOSITORY

The public repository of this module is
L<https://github.com/Corion/Net-Fritz-Phonebook>.

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
