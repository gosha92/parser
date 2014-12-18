use strict;
use warnings;
no warnings 'portable';
use Time::Piece;

# Usage:
my $hex = shift // '';
die "\n    USAGE: attr.pl HEX_OFFSET_TO_FILE_RECORD\n" unless $hex =~ /^(0x)?[0-9a-f]+$/i;

# Читает 512 байтов, начиная со смещения <skip>*512 байтов
# diskread(skip)
sub diskRead($) {
	my $skip = int($_[0]);
	`dd if=\\\\.\\C: skip=${skip} count=1 bs=512 2>nul`;
}

# Упаковывает байты
# parse(data, offset, length, [template])
sub parse {
	my ($data, $offset, $length, $template) = @_;
	unpack $template, substr($data, $offset, $length);
}

# Int -> 0xHex
sub HEXED { '0x' . uc sprintf("%x", shift) };









# Извлекаем файловую запись
my $file_record = diskRead( hex($hex) / 512 );

# Проверяем сигнатуру 'FILE'
my $signature = substr $file_record, 0, 4;
die "\n    Missed 'FILE' signature!\n" unless $signature eq "FILE";

# Вычисляем смещение до атрибутов
my $offset = parse($file_record, 0x14, 2, "v*");
my $file_record_length = parse($file_record, 0x18, 4, "V*");

# Парсим атрибуты
while ($offset < $file_record_length - 8) {
	my $type = parse($file_record, $offset + 0x00, 4, "V*");
	my $length = parse($file_record, $offset + 0x04, 4, "V*");
	my $resident = parse($file_record, $offset + 0x08, 1, "c*");
	my $data_offset = parse($file_record, $offset + 0x14, 2, "v*");
	# Извлекаем данные атрибута
	my $data = '';
	if ($resident) {
		$data = 'unknown';
	} else {
		my $data_length = parse($file_record, $offset + 0x10, 4, "V*");
		$data = substr $file_record, $offset + $data_offset, $data_length;
	}
	# Парсим содержимое стандартных атрибутов
	if ($type eq 0x10) {
		my $ctime = parse($data, 0x00, 8, "I*");
		# $ctime = localtime($ctime)->strftime('%Y.%m.%d %H:%M:%S');
		print "== $ctime ==";
	} elsif ($type eq 0x30) {
		my $name_length = 2 * parse($data, 0x40, 1, "c*");
		$data = substr $data, 0x42, $name_length;
	} elsif ($type eq 0x80) {
	}
	print "[" . HEXED($type) . "]\nresident: $resident\n";
	print "\n--";
	print $data;
	print "--\n\n";
	$offset += $length;
}
