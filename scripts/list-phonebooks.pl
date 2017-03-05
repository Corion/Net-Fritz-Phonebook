#!perl -w
use strict;
use Net::Fritz::Box;
use Net::Fritz::Phonebook;
use Data::Dumper;

use Getopt::Long;
GetOptions(
    'h|host:s' => \my $host,
    'u|user:s' => \my $username,
    'p|pass:s' => \my $password,
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
for my $service (@{ $services->data }) {
    #print $service->dump;
    my $phonebooks = $service->call('GetPhonebookList');
    if( my $error = $phonebooks->error ) {
        die "Phonebook: $error";
    };

    my @items = split /,/, $phonebooks->data->{NewPhonebookList};
    
    for my $bookid (@items) {
        my $book = Net::Fritz::Phonebook->new(
            service => $service,
            id => $bookid,
        );
        #print Dumper $book->content;
        print $book->name, "\n";
        for my $e (@{ $book->entries }) {
            delete $e->{phonebook};
            print join "\t", $e->name, $e->category, (map { $_->type, $_->content } @{ $e->numbers }), "\n";
        };
        
        if( 'Testtelefonbuch' eq $book->name ) {
            my $e = Net::Fritz::PhonebookEntry->new(
                name => 'Test Tester',
            );
            $e->add_number('555-123456');
            my $res = $book->add_entry($e);
            die $res->error if $res->error;
        };
    };
    
};

#my $service  = $fb->get_service('DeviceInfo:1');
#$service->call();