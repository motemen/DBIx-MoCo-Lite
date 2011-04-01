use inc::Module::Install;

name 'DBIx-MoCo-Lite';
all_from 'lib/DBIx/MoCo/Lite.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';

auto_set_repository;
auto_include;

WriteAll;
