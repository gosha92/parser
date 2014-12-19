use strict;
use warnings;
no warnings 'portable';

use Utils;

# Usage:
my $hex = shift // '';
die "\n    USAGE: attr.pl HEX_OFFSET_TO_FILE_RECORD\n" unless $hex =~ /^(0x)?[0-9a-f]+$/i;

# Извлекаем файловую запись по указанному смещению
my $file_record = diskRead( hex($hex) );

# Проверяем сигнатуру 'FILE'
die "\n    Missed 'FILE' signature!\n" unless substr($file_record, 0, 4) eq "FILE";

# Вычисляем смещение до атрибутов
my $offset = parse($file_record, 0x14, 2);
my $file_record_length = parse($file_record, 0x18, 4);

# Парсим атрибуты
my @attributes = ();
while ($offset < $file_record_length - 8) {
	my $type =        parse($file_record, $offset + 0x00, 4);
	my $length =      parse($file_record, $offset + 0x04, 4);
	my $nonresident = parse($file_record, $offset + 0x08, 1);
	my $name_length = parse($file_record, $offset + 0x09, 1);
	my $data_offset = parse($file_record, $offset + 0x14, 2);
	# Извлекаем данные атрибута
	my $data = '';
	my @dataruns = ();
	if ($nonresident) {
		my $dataruns_offset = $offset + $name_length * 2 + 0x40;
		while (1) {
			my $fragment_info = parse($file_record, $dataruns_offset, 1);
			last unless $fragment_info;
			my $fragment_size_length = $fragment_info & 0x0F;
			my $fragment_addr_length = $fragment_info >> 4;
			my $fragmet_size = parse($file_record, $dataruns_offset + 1, $fragment_size_length, 'variable');
			my $fragmet_addr = parse($file_record, $dataruns_offset + 1 + $fragment_size_length, $fragment_addr_length, 'variable');
			push @dataruns, $fragmet_addr << 12, ($fragmet_addr + $fragmet_size) << 12;
			$data .= diskRead( $fragmet_addr << 12 );
			$dataruns_offset += (1 + $fragment_size_length + $fragment_addr_length);
		}
	} else {
		my $data_length = parse($file_record, $offset + 0x10, 4);
		$data = substr $file_record, $offset + $data_offset, $data_length;
	}
	# Парсим содержимое стандартных атрибутов
	if ($type == 0x10) {
		my $ctime = parse($data, 0x00, 8);
		my $atime = parse($data, 0x08, 8);
		my $mtime = parse($data, 0x10, 8);
		my $rtime = parse($data, 0x18, 8);
		my $flags = parse($data, 0x20, 4, 'flags');
		$data = "ctime: $ctime\natime: $atime\nmtime: $mtime\nrtime: $rtime\nflags: $flags";
	} elsif ($type == 0x30) {
		my $name_length = parse($data, 0x40, 1) * 2;
		$data =           parse($data, 0x42, $name_length, 'unicode');
	} else {
		$data = hexdump($data);
	}
	$offset += $length;
	# Добавляем атрибут
	push @attributes, {
		type => $type,
		resident => $nonresident,
		dataruns => \@dataruns,
		data => $data
	};
}

# Выводим информацию
DUMP(@attributes);