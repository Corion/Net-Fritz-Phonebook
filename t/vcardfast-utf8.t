#!perl -w
use strict;
use Net::CardDAVTalk::VCard;
use Text::VCardFast;
use Data::Dumper;
use Test::More tests => 2;

my $vcard = join "",
"BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Hans M\N{LATIN SMALL LETTER U WITH DIAERESIS}ller",
"\r\nTEL;TYPE=CELL;TYPE=VOICE:555-1267-789\r\nN:M\N{LATIN SMALL LETTER U WITH DIAERESIS}ller;Hans;;;\r\n",
"PRODID:-//dmfs.org//mimedir.vcard//EN\r\nREV:20170101T000001Z\r\n",
"\r\nEND:VCARD\r\n",
;

my $contact_hash = vcard2hash($vcard);
is $contact_hash->{objects}->[0]->{properties}->{fn}->[0]->{value}, "Hans M\N{LATIN SMALL LETTER U WITH DIAERESIS}ller",
    "Values don't get mojibaked by Text::VCardFast";

#$Data::Dumper::Useqq = 1;
#diag Dumper $contact_hash;
    
my $contact = Net::CardDAVTalk::VCard->new_fromstring($vcard);

is $contact->VFN, "Hans M\N{LATIN SMALL LETTER U WITH DIAERESIS}ller",
    "Values don't get mojibaked by Net::CardDAVTalk";
