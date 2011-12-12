#!/usr/bin/perl -w

#       getmensamenu.pl
#
#       Copyright 2011 Philipp Böhm <philipp-boehm@live.de>
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.
#
use strict;
use Getopt::Long;
use File::Copy;
use WWW::Mechanize;
use Data::Dumper;
use HTML::TreeBuilder;
use Email::Send;
use Encode;
use MIME::Lite;
use POSIX qw/strftime/;

my $VERSION = "0.0.1";

################################################################################
############### Parameter erfassen #############################################
################################################################################
my %PARAMS = ();
my @EMAIL_ADDRESSES;

GetOptions(
    \%PARAMS,
    "help" => \&help,
    "verbose",
    "version" => sub { print $VERSION, "\n"; exit; },
    "to=s" => \@EMAIL_ADDRESSES,
) or die "Fehler bei der Parameterübergabe";

################################################################################
############## Mensaseite parsen ###############################################
################################################################################
my $BROWSER = WWW::Mechanize->new(
    stack_depth => -1,
    timeout     => 180,
    autocheck   => 1,
    agent       => "automensa/libwww-perl",
    cookie_jar  => {},
);
$BROWSER->quiet(1);

$BROWSER->get(
'http://www.studentenwerk-rostock.de/index.php?lang=de&mainmenue=4&submenue=47'
);

$BROWSER->follow_link( text_regex => qr/Speiseplan.*KW/, n => 1 );

my $root = HTML::TreeBuilder->new_from_content( $BROWSER->content() );

# passende Layoit-Tabelle "Speiseplan für ..."
my $MenuTable = $root->look_down(
    "_tag",        "table", "width",       "100%",
    "border",      "0",     "cellpadding", "2",
    "cellspacing", "1",     "bgcolor",     "#FFFFFF"
);

my @MENU;
for my $tr ( $MenuTable->look_down( "_tag", "tr", "bgcolor", "#EFEFEF" ) ) {
    my $text = encode_utf8( $tr->as_text() );

    if ( defined $tr->look_down( "_tag", "img" ) ) {
        $text = "VITALTHEKE";
    }

    if ( $text =~ /\w+/ ) {
        if ( ( $tr->attr('class') =~ /fett$/ && $text =~ /THEKE/i )
            || $text =~ /VITALTHEKE/ )
        {
            push( @MENU, sprintf( "==== %s", $text ) );
        }
        elsif ( $tr->attr('class') =~ /fett$/ ) {
            push( @MENU, sprintf( "%s:", $text ) );
        }
        else {
            push( @MENU, sprintf( " - %s", $text ) );
        }
    }
}

die "Keine passenden Daten gefunden" unless ( scalar grep( /THEKE/i, @MENU ) );

################################################################################
############## Nachricht zusammenbauen #########################################
################################################################################
my $date = strftime "%d.%m.%Y", localtime;

my $MESSAGE =
"Hallo Hungrige,\n\nhier der heutige Mensaplan ($date) für die Mensa Süd.\n\n";
foreach my $line (@MENU) {
    $MESSAGE .= ( $line . "\n" );
}
$MESSAGE .= "\n\nGuten Appetit\n\n";

my $MAIL = MIME::Lite->new(
    From    => 'mensanews@i77i.de',
    To      => pop @EMAIL_ADDRESSES,
    Cc      => join( ", ", @EMAIL_ADDRESSES ),
    Subject => "MensaNews für $date",
    Data    => $MESSAGE,
);

print $MAIL->as_string;

################################################################################
############## Funktionsdefinitionen ###########################################
################################################################################

sub help {
    print << "EOF";

Copyright 2011 Philipp Böhm

Script, welches den aktuellen Speiseplan der Mensa Süd per Email verschickt
    
Usage: $0 [Optionen]

   --help                 : Diesen Hilfetext ausgeben
   --verbose              : erweiterte Ausgaben
   --version              : Versionshinweis
   --to=EMAIL (multiple)  : Gibt die Email-Adressen an, an die die Email 
                            versendet wird

EOF
    exit();
}
