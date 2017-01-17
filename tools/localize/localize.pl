#!/usr/bin/env perl

# Find all C files, extract all configdlg and plugin_action properties/titles
# into localization files

use strict;
use warnings;
use FindBin qw'$Bin';
use lib "$FindBin::Bin/../perl_lib";
use lib "$FindBin::Bin";
use File::Find::Rule;
use Getopt::Long qw(GetOptions);
use HTML::Entities;

my $help;
my $android_xml;
my $c_source;
my $out_fname;

GetOptions (
    "help|?" => \$help,
    "--android-xml" => \$android_xml,
    "--c-source" => \$c_source,
	"--output=s" => \$out_fname
) or die("Error in command line arguments\n");

if ($help) {
    print "Usage: $0 [options]\n";
    print "With no options, $0 will generate strings.pot from deadbeef source code\n\n";
    print "Options:\n";
    print "  --help               Show this text\n";
    print "  --android-xml        Generate android xml strings.xml\n";
    print "  --c-source           Generate strings.c file compatible with xgettext\n";
    exit (0);
}

my $ddb_path = $FindBin::Bin.'/../..';

my @ignore_props = ("box");
my @ignore_paths_android = (
	'plugins/alsa',
	'plugins/artwork-legacy',
	'plugins/cdda',
	'plugins/cocoaui',
	'plugins/converter',
	'plugins/coreaudio',
	'plugins/dca',
	'plugins/dsp_libsrc',
	'plugins/ffmpeg',
	'plugins/gtkui',
	'plugins/hotkeys',
	'plugins/mono2stereo',
	'plugins/notify',
	'plugins/nullout',
	'plugins/oss',
	'plugins/pltbrowser',
	'plugins/psf',
	'plugins/pulse',
	'plugins/rg_scanner',
	'plugins/shellexec',
	'plugins/shellexecui',
	'plugins/shn',
	'plugins/sndio',
	'plugins/soundtouch',
	'plugins/statusnotifier',
	'plugins/supereq',
	'plugins/wildmidi'
);

my @lines;

for my $f (File::Find::Rule->file()->name("*.c")->in($ddb_path)) {
	next if ($android_xml && grep ({$f =~ /\/$_\//} @ignore_paths_android));
    open F, "<$f" or die "Failed to open $f\n";
    my $relf = substr ($f, length($ddb_path)+1);
    while (<F>) {
        # configdialog
        if (/^\s*"property\s+/) {
            my $prop;
            if (/^\s*"property\s+([a-zA-Z0-9_]+)/) {
                $prop = $1;
            }
            elsif (/^(\s*"property\s+\\")/) {
                my $begin = $1;
                my $s = substr ($_, length ($begin));
                if ($s =~ /(.*?)\\"/) {
                    $prop = $1;
                }
            }
            if ($prop && !grep ({$_ eq $prop} @ignore_props)) {
                if (!grep ({$_->{msgid} eq $prop} @lines)) {
                    push @lines, { f=>$relf, line=>$., msgid=>$prop };
                }
            }
        }
        elsif (/^.*DB_plugin_action_t .* {/) {
            # read until we hit title or };
            while (<F>) {
                if (/^(\s*\.title\s*=\s*")/) {
                    my $begin = $1;
                    my $s = substr ($_, length ($begin));
                    if ($s =~ /(.*[^\\])"/) {
                        my $prop = $1;
                        if (!grep ({$_->{msgid} eq $prop} @lines)) {
                            push @lines, { f=>$relf, line=>$., msgid=>$prop };
                        }
                    }
                }
            }
        }
    }
    close F;
}

my @unique_ids;

# the idea of the algorithm is to make it super quick to implement in C,
# with in-place generation support (given the string is ASCII).
sub string_to_id {
	my $s = shift;

	$s =~ s/[^a-zA-Z0-9_]/_/g;
	$s =~ s/^([^a-zA-Z_])/_/;

	my $s_unique = $s;
	my $cnt = 1;
	while (grep ({ $_ eq $s_unique} @unique_ids)) {
		$s_unique = $s.$cnt;
		$cnt++;
	}
	push @unique_ids, $s_unique;
	return $s_unique;
}

sub string_xml_esc {

}

if ($android_xml) {
	my $fname = $out_fname // 'strings.xml';
    open XML, '>:encoding(utf8)', $fname or die "Failed to open $fname\n";
    print XML "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
    print XML "<!-- This file is generated by $0, and contains localizable strings from all plugin configuration dialogs and actions -->\n";
    print XML "<resources>\n";
    for my $l (@lines) {
		my $id = string_to_id ($l->{msgid});
		my $value = encode_entities ($l->{msgid}, '\200-\377');
		$value =~ s/'/\\'/g;
        print XML "    <string name=\"$id\">$value</string>\n";
    }
    print XML "</resources>\n";
    close XML;
}
elsif ($c_source) {
	my $fname = $out_fname // 'strings.c';
    open C, '>:encoding(utf8)', $fname or die "Failed to open $fname\n";
    for my $l (@lines) {
        print C "_(\"$l->{msgid}\");\n";
    }
    close C;
}
else {
	my $fname = $out_fname // 'strings.pot';
    open POT, '>:encoding(utf8)', $fname or die "Failed to open $fname\n";

    print POT "msgid \"\"\nmsgstr \"\"\n\"Content-Type: text/plain; charset=UTF-8\\n\"\n\"Content-Transfer-Encoding: 8bit\\n\"\n";

    for my $l (@lines) {
        print POT "\n#: $l->{f}:$l->{line}\nmsgid \"$l->{msgid}\"\nmsgstr \"\"\n";
    }
    close POT;
}