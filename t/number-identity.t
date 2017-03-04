#!perl -w
use strict;
use Test::More tests => 3;
use Net::Fritz::Phonebook;

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

my $contact = Net::Fritz::PhonebookEntry->new(%$raw_contact);
is $contact->id, 12, "We find contact with id 12";
is $contact->name, "Hans M\x{fc}ller", "We find a name";
my $processed = $contact->build_structure;


is_deeply $processed, $raw_contact, "All data survives a serialization round-trip";
