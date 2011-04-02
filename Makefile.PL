use inc::Module::Install;

name 'DBIx-MoCo-Lite';
all_from 'lib/DBIx/MoCo/Lite.pm';

requires 'parent';
requires 'Carp';
requires 'Scalar::Util';
requires 'List::MoreUtils';
requires 'Class::Load';
requires 'DBI';
requires 'SQL::Abstract';
requires 'Class::Data::Inheritable';
requires 'List::Rubyish';

tests 't/*.t';
recursive_author_tests 'xt';

test_requires 'Test::More';
test_requires 'Test::mysqld' if $Module::Install::AUTHOR;

auto_set_repository;
auto_include;

WriteAll;
