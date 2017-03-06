#!perl -w
use strict;
use Net::Fritz::Box;
use Net::Fritz::Phonebook;
use Net::CardDAVTalk;
use URI::URL;
use Data::Dumper;
use Encode;

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
    
my $book = Net::Fritz::Phonebook->new(
    service => $services->data->[0],
    id => 1,
);

# Cache what we have so we don't overwrite contacts with identical data.
my $entries = $book->entries;
print $_->uniqueid,"\n" for @$entries;

sub entry_exists {
    my( $entry ) = @_;
    
    #my $uid = $vcard->uid;
    #warn sprintf "[%s] (%s)\n", $uid, $vcard->VFN;

    # check uid
    # grep { $uid eq $_->uniqueid } @$entries;
    
    # check name
    grep {
            $_->name eq $entry->name
    } @$entries;
    
    # check number
    
    #0
};

sub add_contact {
    my( $vcard ) = @_;
    #print join " - ", $addr->VFN, (map {ref $_ ? $_->{value}: ()} $addr->VNickname), (map { $_->{value}} $addr->VEmails);
    #my $name = decode( 'Latin-1', $vcard->VFN );
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
