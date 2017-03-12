#!perl -w
use strict;
use Test::More tests => 5;
use Net::Fritz::Box;
use Net::Fritz::Phonebook;

# Round trip test to see whether we can create, find and delete an entry
# with umlauts in its name

if( -f 'fritzbox.credentials' ) {
    do 'fritzbox.credentials';
};

if(! $ENV{FRITZ_HOST}) {
    SKIP: {
        skip "Live tests not run", 1;
        exit
    };
};

my $name = "Hans M\N{LATIN SMALL LETTER U WITH DIAERESIS}ller";
#my $name = "Hans Mahler";
my $phonebookname = 'Testtelefonbuch';

binmode STDOUT, ':encoding(UTF-8)';
`chcp 65001 2>&1`;

my $fb = Net::Fritz::Box->new(
    username => $ENV{FRITZ_USER},
    password => $ENV{FRITZ_PASS},
    upnp_url => $ENV{FRITZ_HOST},
);

my $device = $fb->discover;
if( my $error = $device->error ) {
    die $error
};

my $phonebook = Net::Fritz::Phonebook->by_name(
    device => $device,
    name => $phonebookname
);

if(! $phonebook) {
    SKIP: {
        skip "Phonebook '$phonebookname' not found", 1;
        exit
    };
};

my $number = '555-666-6666-qwe';
my $contact = Net::Fritz::PhonebookEntry->new(
    name => $name,
);
is $contact->name, $name, "We store and retrieve the name immediately";
$contact->add_number($number);

(my $existing) = grep { my $c = $_;
                        grep { $_->{content} eq $number } @{$c->numbers}
                      } @{ $phonebook->entries };
if( ! is $existing, undef, "Our contract does not yet exist" ) {
    diag $existing->uniqueid;
    use Data::Dumper;
    diag Dumper( $existing->name );
    diag Dumper $existing->numbers;
};

my $error;
my $res;
if( ! eval {
    $res = $phonebook->add_entry( $contact );
    1;
}) {
    $error = $@;
};
$error ||= $res->error;
is $error, '', "We can add an entry with an umlaut";

# These two tests don't pass currently. It seems that entires added via TR-064
# get double-encoded on the Fritz!Box :-/

$phonebook->reload;
($existing) = grep { my $c = $_;
                        grep { $_->{content} eq $number } @{$c->numbers}
                      } @{ $phonebook->entries };
isn't $existing, undef, "Our contract exists now";
if(! is $existing->{name}, $name, "We retrieve the same name we wrote") {
    diag 'Got:      ' . Dumper $existing->{name};
    diag 'Expected: ' . Dumper $name;
    print '# ' . $existing->{name}, "\n";
    print '# ' . $name, "\n";
};

my $existing2 = $phonebook->get_entry_by_index( $existing->uniqueid );
isn't $existing2, undef, "Our contract exists now";
if(! is $existing2->{name}, $name, "We retrieve the same name we wrote") {
    diag 'Got:      ' . Dumper $existing2->{name};
    diag 'Expected: ' . Dumper $name;
    print '# ' . $existing2->{name}, "\n";
    print '# ' . $name, "\n";
};