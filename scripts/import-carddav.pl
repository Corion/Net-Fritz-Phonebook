#!perl -w
use strict;
use Net::Fritz::Box;
use Net::Fritz::Phonebook;
use Net::CardDAVTalk;
use URI::URL;
use Data::Dumper;
use Encode;

use vars '$VERSION';
$VERSION = '0.01';

=head1 NAME

import-carddav.pl - import a CardDAV phone book

=cut

use Getopt::Long;
GetOptions(
    'h|host:s' => \my $host,
    'u|user:s' => \my $username,
    'p|pass:s' => \my $password,
    'b|phonebook:s' => \my $phonebookname,
);

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

(my $book) = grep { $phonebookname eq $_->name }
               @phonebooks;

if( ! $book) {
    warn "Couldn't find phone book '$phonebookname'\n";
    warn "Known phonebooks on $host are\n";
    warn $_->name . "\n"
        for @phonebooks;
    exit 1;
};

# Cache what we have so we don't overwrite contacts with identical data.
my $entries = $book->entries;

sub entry_exists {
    my( $entry ) = @_;

    #my $uid = $vcard->uid;
    #warn sprintf "[%s] (%s)\n", $uid, $vcard->VFN;

    # check uid
    # grep { $uid eq $_->uniqueid } @$entries;

    my %numbers = map {
        $_->content => 1,
    } @{ $entry->numbers };

    # check name or number
    # This means we cannot rename?!
    grep {
        my $c = $_;
            $c->name eq $entry->name
         or grep { $numbers{ $_->content } } @{ $c->numbers }
    } @$entries;
};

sub entry_is_different {
    my( $entry, $match ) = @_;

    my %numbers = map {
        $_->content => 1,
    } @{ $entry->numbers };

    #my %match_numbers = map {
    #    $_->content => 1,
    #} @{ $match->numbers };

    # check name or number
    # If one of the two is a mismatch, we are different
    #$match->name ne $entry->name
    #    or grep { $numbers{ $_->content } } @{ $c->numbers }
    #} @$entries;
};

sub add_contact {
    my( $vcard ) = @_;
    my $name = encode('Latin-1', $vcard->VFN);

    $name =~ s!\x{fffd}!!g;
    #$Data::Dumper::Useqq = 1;
    #warn Dumper \$name;
    my $contact = Net::Fritz::PhonebookEntry->new(
        name => $name,
        # I need a better unifier - the uniqueid gets assigned by the fb
        #uniqueid => $vcard->uid,
    );

    for my $number ($vcard->VPhones) {
        $contact->add_number($number->{value}, $number->{type});
    };

    if( 0+@{ $contact->numbers } and ! entry_exists( $contact )) {
        my $res = $book->add_entry($contact);
        die $res->error if $res->error;
    };
}

for my $url (@ARGV) {
    $url = URI::URL->new( $url );

    my @userinfo = split /:/, $url->userinfo, 2;
    my $CardDAV = Net::CardDAVTalk->new(
        user => $userinfo[0],
        password => $userinfo[1],
        host => $url->host(),
        port => $url->port(),
        scheme => $url->scheme,
        url => $url->path,
        expandurl => 1,
        logger => sub { warn "DAV: @_" },
    );

    for my $cal (@{ $CardDAV->GetAddressBooks() }) {
        print sprintf "%s (%s)\n", $cal->{name}, $cal->{path};
        #print Dumper $cal;

        if( $cal->{path} eq 'addresses' ) {
            #$Data::Dumper::Useqq = 1;
            my( $cards ) = $CardDAV->GetContacts( $cal->{path} );
            for my $addr (@$cards) {
                add_contact( $addr );
            };
        };
    };
};
