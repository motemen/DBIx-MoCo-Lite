use strict;
use Test::More;

unlink './t/t.db';

{
    package t::MoCo::DataBase;
    use parent 'DBIx::MoCo::Lite::DataBase';

    __PACKAGE__->dsn('dbi:SQLite:./t/t.db');
    __PACKAGE__->dbh->do(<<__CREATE_TABLE__);
CREATE TABLE foo (
    id INTEGER PRIMARY KEY,
    value TEXT
);
__CREATE_TABLE__

    __PACKAGE__->dbh->do(<<__CREATE_TABLE__);
CREATE TABLE bar (
    id INTEGER PRIMARY KEY,
    foo_id INT UNSIGNED NOT NULL,
    value TEXT,
    UNIQUE (foo_id)
);
__CREATE_TABLE__

    package t::MoCo;
    use parent 'DBIx::MoCo::Lite';

    __PACKAGE__->db('t::MoCo::DataBase');

    package t::MoCo::Foo;
    use parent -norequire => 't::MoCo';

    __PACKAGE__->has_a(
        bar => 't::MoCo::Bar', {
            key => { 'id' => 'foo_id' }
        }
    );

    package t::MoCo::Bar;
    use parent -norequire => 't::MoCo';

    package t::MoCo::Abc::DefGhi;
    use parent -norequire => 't::MoCo';
}

is +t::MoCo::Foo->table, 'foo', 'MoCo::Foo->table';
is +t::MoCo::Abc::DefGhi->table, 'abc_def_ghi', 'MoCo::Abc::DefGhi->table';

ok my $foo1 = t::MoCo::Foo->create(value => 'abc'), 'create';
ok my $foo2 = t::MoCo::Foo->create(value => 'def'), 'create';
ok my $foo3 = t::MoCo::Foo->create(value => 'ghi'), 'create';
is $foo1->id, 1, '$foo1->id';
is $foo1->value, 'abc', '$foo1->value';

$foo2->update(value => 'xyz');

ok my $bar1 = t::MoCo::Bar->create(foo_id => 1, value => 'blah'), 'create';
ok my $bar2 = t::MoCo::Bar->create(foo_id => 2, value => 'blah blah'), 'create';

is +t::MoCo::Foo->find(id => 2)->value, 'xyz';

my $foos = t::MoCo::Foo->search;
isa_ok $foos, 'DBIx::MoCo::Lite::List';
is     $foos->size, 3;

isa_ok $foos->[0]->bar, 't::MoCo::Bar', '$foos->[0]->bar';
is     $foos->[0]->bar->value, 'blah';

{
    local *DBI::st::execute = sub { die };
    isa_ok $foos->[1]->bar, 't::MoCo::Bar', '$foos->[1]->bar';
    is     $foos->[1]->bar->value, 'blah blah';

    is     $foos->[2]->bar, undef;

    pass 'DBI::st::execute not called';
}

is +t::MoCo::Foo->search(where => [ 'id IN (:id)', id => [ 1, 3 ] ])->size, 2;
is +t::MoCo::Foo->search(where => [ 'id = :id', id => 2 ])->size, 1;

$foos->[1]->delete;

is +t::MoCo::Foo->search->size, 2;

t::MoCo::Foo->create(value => $_) for 1 .. 10;

is +t::MoCo::Foo->search(offset => 3, limit => 5, order => 'id')->size, 5;

unlink './t/t.db';

done_testing;
