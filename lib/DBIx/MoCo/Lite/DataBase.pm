package DBIx::MoCo::Lite::DataBase;
use strict;
use warnings;
use parent 'Class::Data::Inheritable';
use DBI;
use Carp;

our @CARP_NOT = qw(DBIx::MoCo::Lite);

__PACKAGE__->mk_classdata('dsn');
__PACKAGE__->mk_classdata('username');
__PACKAGE__->mk_classdata('password');

__PACKAGE__->mk_classdata('_dbh');

sub dbh {
    my $class = shift;
    return $class->_dbh if $class->_dbh;

    my $dbh = DBI->connect_cached($class->dsn, $class->username, $class->password);
    return $class->_dbh($dbh);
}

sub execute {
    my $class = shift;
    my ($sql, $data, $binds) = @_;
    my $sth = $class->dbh->prepare($sql) or confess $class->dbh->errstr;
    $sth->execute(@{ $binds || [] }) or confess $sth->errstr;
    if (ref $data) {
        $$data = $sth->fetchall_arrayref({});
    }
}

sub last_insert_id {
    my $class = shift;
    return $class->dbh->{mysql_insertid} || $class->dbh->last_insert_id(undef, undef, undef, undef);
}

1;
