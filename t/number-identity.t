#!perl -w
use strict;
use Test::More tests => 4;
use Data::Dumper;
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
is $contact->uniqueid, 12, "We find contact with id 12";
is $contact->name, "Hans M\x{fc}ller", "We find a name";
my $processed = $contact->build_structure;

is_deeply $processed, $raw_contact, "All data survives a serialization round-trip";

# Now, create an entry from scratch and see whether it still matches:
my $new = Net::Fritz::PhonebookEntry->new(
    category => 0,
);
$new->name("Hans M\x{fc}ller");
$new->uniqueid(12);

my $number = Net::Fritz::PhonebookEntry::Number->new();
$number->content(123);
$number->type('home');
$number->prio('1');
$new->add_number($number);
$new->add_number(345,'mobile');
$new->add_number(456,'work');
$new->add_number(789,'fax_work');
$new->add_email('hans.mueller@example.com');

$processed = $new->build_structure;
is_deeply $processed, $raw_contact, "Fresh creation is identical to canned data"
    or diag Dumper $processed;
