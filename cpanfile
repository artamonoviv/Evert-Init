requires 'perl', '5.008001';
requires 'Evert::E', '0.002';
requires 'JSON::MaybeXS', '1.003008';
requires 'Carp', '1.40';
requires 'Data::Dumper', '2.161';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Capture::Tiny', '0.44';
};
