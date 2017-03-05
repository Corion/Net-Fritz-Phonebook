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
    
my $book = Net::Fritz::Phonebook->new(
    service => $services->data->[0],
    id => 1,
);
#print $book->name, "\n";
        
my $raw_contact = {
        'category' => ['0'],
        'telephony' => [{
            'number' => [
                {
                    'prio'=> '1',
                    'vanity' => '',
                    'type'=> 'home',
                    'quickdial' => '',
                    'content' => '123'
                },
                {
                    'content' => '345',
                    'quickdial' => '',
                    'type'=> 'mobile',
                    'vanity' => '',
                    'prio'=> ''
                },
                {
                    'vanity' => '',
                    'prio'=> '',
                    'type'=> 'work',
                    'content' => '456',
                    'quickdial' => ''
                },
                {
                    'type'=> 'fax_work',
                    'quickdial' => '',
                    'content' => '789',
                    'vanity' => '',
                    'prio'=> ''
                }
                ],
            'services' => [{
                'email' => [{
                    'classifier' => 'private',
                    'content' => 'hans.mueller@example.com'
                }]
            }]
        }],
        'uniqueid' => ['12'],
        'person' => [{
            'realName' => ["Hans M\x{fc}ller"]
        }]
};

my $contact = Net::Fritz::PhonebookEntry->new(
    name => 'Test Tester',
);
$contact->add_number('555-123455');
$contact->add_number('555-123456','fax_work'); # displayed as "fax"
$contact->add_number('555-123457','fax'); # "fax" gets preserved but displayed as "Sonstige"
my $res = $book->add_entry($contact);
die $res->error if $res->error;
