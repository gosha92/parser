package Utils;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(diskRead parse hexdump DUMP);  # symbols to export on request

use strict;
use warnings;
no warnings 'portable';
binmode(STDOUT,':utf8');
use Time::Piece;
use Encode qw(decode);
use Data::Dumper;
use Data::HexDump;
$/ = undef;
use utf8;

use Term::ANSIColor 2.00 qw(:pushpop);

# Читает 512 или length мегабайтов, начиная со смещения offset
# diskread(offset, [length])
sub diskRead {
	my $offset = int($_[0]);
	my $skip = int($offset / (1024*1024));
	my $s = $offset % (1024*1024);
	system "dd if=\\\\.\\C: skip=${skip} count=1 bs=1M 2>nul > dd.bin";
	open my $f, 'dd.bin';
	binmode $f;
	my $b = <$f>;
	close $f;
	my $length = $_[1] // 512;
	return substr $b, $s, $length;
}

# Упаковывает байты
# parse(data, offset, length, [template])
sub parse {
	my ($data, $offset, $length, $template) = (@_, '');
	if ($template eq 'unicode') {
		return decode("UTF-16LE", substr($data, $offset, $length));
	} elsif ($template eq 'flags') {
		my $flags = unpack "V*", substr($data, $offset, $length);
		my @fnames = ('read-only','hidden','system','','','archive',
		'device','normal','temporary','sparse','reparse point',
		'compressed','offline','not indexed','encrypted');
		return join ", ", @fnames[ grep {$flags & (1<<$_)} 0..31 ];
	} elsif ($template eq 'variable') {
		my $bytes = join '', reverse(split(//, substr($data, $offset, $length)));
		$bytes =~ s/^\0+//;
		return hex(unpack "H*", $bytes);
	} elsif ($length == 1) {
		$template = "c*";
	} elsif ($length == 2) {
		$template = "v*";
	} elsif ($length == 4) {
		$template = "V*";
	} elsif ($length == 8) {
		my $time = unpack "Q*", substr($data, $offset, $length);
		$time = int( ($time - 116444736000000000) / 10000000 );
		return localtime($time)->strftime('%d.%m.%Y %H:%M:%S');
	}
	unpack $template, substr($data, $offset, $length);
}

# Int -> 0xHex
sub HEXED { '0x' . uc sprintf("%x", shift) };

sub hexdump {
	my $s = substr HexDump(substr shift, 0, 64), 79;
	$s =~ s/\n+$//;
	$s;
}

my %attr_names = (
	0x10, '$STANDARD_INFORMATION',
	0x20, '$ATTRIBUTE_LIST',
	0x30, '$FILE_NAME',
	0x40, '$VOLUME_VERSION',
	0x40, '$OBJECT_ID',
	0x50, '$SECURITY_DESCRIPTOR',
	0x60, '$VOLUME_NAME',
	0x70, '$VOLUME_INFORMATION',
	0x80, '$DATA',
	0x90, '$INDEX_ROOT',
	0xA0, '$INDEX_ALLOCATION',
	0xB0, '$BITMAP',
	0xC0, '$SYMBOLIC_LINK',
	0xC0, '$REPARSE_POINT',
	0xD0, '$EA_INFORMATION',
	0xE0, '$EA',
	0xF0, '$PROPERTY_SET',
	0x100, '$LOGGED_UTILITY_STREAM'
);

sub DUMP(\@) {
	print "\n\n";
	my @attributes = @{shift;};
	for my $a (@attributes) {
		my $name = $attr_names{$a->{type}} // HEXED($a->{type});
		my $resident = $a->{resident} ? "nonresident" : "resident";
		my $size = $a->{size};
		print "$name \[$resident";
		if ($a->{resident}) {
			print ': ';
			my @dataruns = @{$a->{dataruns}};
			print HEXED(shift @dataruns) . '..' . HEXED(shift @dataruns);
			while(@dataruns) { print ', ' . HEXED(shift @dataruns) . '..' . HEXED(shift @dataruns) };
		}
		print "]";
		if ($a->{resident}) {print " SIZE: ${size} bytes"}
		print "\n" . $a->{data} . "\n\n";
	}
}

1;