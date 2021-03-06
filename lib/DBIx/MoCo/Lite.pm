package DBIx::MoCo::Lite;
use strict;
use warnings;
use parent 'Class::Data::Inheritable';
use Carp qw(croak);
use Scalar::Util qw(blessed refaddr);
use List::MoreUtils qw(all);
use Params::Validate qw(validate);
use Class::Load;

our $VERSION = '0.01';

__PACKAGE__->mk_classdata('db');
__PACKAGE__->mk_classdata(list_class => 'DBIx::MoCo::Lite::List');

sub new {
    my $class = shift;
    return bless { @_ }, $class;
}

### CRUD

sub search {
    my $class = shift;
    my %args  = validate(@_, { field => 0, where => 0, order => 0, offset => 0, limit => 0 });

    my ($sql, @binds) = $class->_build_sql(select => $args{field}, $args{where}, $args{order}, $args{limit}, $args{offset});
    $class->db->execute($sql, \my $data, \@binds);

    my @rows = map { $class->new(%$_) } @$data;
    foreach my $row (@rows) {
        $row->__original_set(\@rows);
    }
    return $class->_return_list([ @rows ]);
}

sub find {
    my ($class, %cond) = @_;
    return $class->search(where => \%cond, limit => 1)->[0];
}

sub find_multi {
    my ($class, $key, $values) = @_;

    my %row_by_value = map { ( $_->{$key} => $_ ) } $class->search(
        where => { $key => { -in => [ @$values ] } }
    );
    return $class->_return_list([ map { $row_by_value{$_} } @$values ]);
}

sub create {
    my ($class, %values) = @_;

    my ($sql, @binds) = $class->_build_sql(insert => \%values);
    $class->db->execute($sql, undef, \@binds);

    my $pk = $class->primary_keys;
    if (@$pk == 1 && !defined $values{ $pk->[0] }) {
        $values{ $pk->[0] } = $class->db->last_insert_id;
    }

    return $class->new(%values);
}

sub update {
    my ($self, %values) = @_;
    my $class = ref $self;
    my ($sql, @binds) = $class->_build_sql(update => \%values, $self->_unique_condition);
    $class->db->execute($sql, undef, \@binds);
}

sub delete {
    my $self = shift;
    my $class = ref $self;
    my ($sql, @binds) = $class->_build_sql(delete => $self->_unique_condition);
    $class->db->execute($sql, undef, \@binds);
}

sub _build_sql {
    my ($class, $which, @args) = @_;
    $class = ref $class if ref $class;
    return $class->sql_builder->$which($class->table, @args);
}

sub _list {
    my ($class, $list) = @_;
    Class::Load::load_class($class->list_class);
    return $class->list_class->new($list);
}

sub _return_list {
    my ($class, $list) = @_;
    return wantarray ? @$list : $class->_list($list);
}

sub _unique_condition {
    my $self = shift;
    my $class = ref $self;

    foreach my $ukey ($class->primary_keys, @{ $class->unique_keys }) {
        my @ukeys = ref $ukey eq 'ARRAY' ? @$ukey : ( $ukey );
        if (all { defined $self->{$_} } @ukeys) {
            return +{
                map { ( $_ => $self->{$_} ) } @ukeys
            };
        }
    }

    require Data::Dumper;
    croak 'Could not setup unique condition for row ' . Data::Dumper->new([ { %$self } ], [ $class->table ])->Indent(0)->Dump;
}

### Relation

our $Relations = {};

sub has_a {
    my ($class, $name, $model, $spec) = @_;

    my ($our_key, $their_key) = ref $spec->{key} eq 'HASH' ? %{ $spec->{key} } : ( $spec->{key} ) x 2;

    $Relations->{$class}->{$name} = [ $model, $our_key, $their_key ];

    my $code = sub {
        my $self = shift;

        return $self->__property($name) if $self->__has_property($name);

        if (my $set = $self->__original_set) {
            my $foreign_rows = $model->find_multi($their_key => [ map { $_->{$our_key} } @$set ]);
            foreach (0 .. $#$set) {
                $set->[$_]->__property($name => $foreign_rows->[$_]);
            }
        }

        return $self->__build_property(
            $name => sub {
                return undef unless defined $self->{$our_key};
                return $model->find($their_key => $self->{$our_key});
            }
        );
    };

    no strict 'refs';
    *{"$class\::$name"} = $code;
}

sub _get_relation_info {
    my ($class, $name) = @_;
    $class = ref $class if ref $class;
    my $info = $Relations->{$class}->{$name} or return;
    return @$info;
}

### Columns

sub AUTOLOAD {
    my $self = shift;
    my ($method) = our $AUTOLOAD =~ /([^:]+)$/ or croak;
    unless (ref $self) {
        croak qq(Trying to call non-class method '$method');
    }
    if (@_) {
        die 'TODO';
    } else {
        return $self->{$method};
    }
}

### Inside out property

our $InsideOut = {};

sub __property {
    my $self = shift;

    my $id = refaddr $self;
    if (@_ == 0) {
        return $InsideOut->{$id};
    } elsif (@_ == 1) {
        return $InsideOut->{$id}->{$_[0]};
    } elsif (@_ == 2) {
        return $InsideOut->{$id}->{$_[0]} = $_[1];
    } else {
        croak;
    }
}

sub __has_property {
    my $self = shift;

    my $id = refaddr $self;
    return exists $InsideOut->{$id}->{$_[0]};
}

sub __build_property {
    my ($self, $name, $builder) = @_;
    return $self->__property($name) if $self->__has_property($name);
    return $self->__property($name => $self->$builder);
}

sub DESTROY {
    my $self = shift;
    my $id = refaddr $self;
    delete $InsideOut->{$id};
}

## Predefined property

sub __changed_cols {
    my $self = shift;
    return $self->__property(__changed_cols => @_);
}

sub __original_set {
    my $self = shift;
    return $self->__property(__original_set => @_);
}

### Class properties

__PACKAGE__->mk_classdata("_$_") for qw(sql_builder table primary_keys unique_keys columns);

sub sql_builder {
    my $class = shift;

    return $class->_sql_builder($_[0]) if @_;
    return $class->_sql_builder if $class->_sql_builder;

    require DBIx::MoCo::Lite::SQLBuilder;
    return $class->_sql_builder(DBIx::MoCo::Lite::SQLBuilder->new(limit_dialect => $class->db->dbh));
}

sub table {
    my $class = shift;

    return $class->_table($_[0]) if @_;
    return $class->_table if $class->_table;

    # guess
    my $base = do { no strict 'refs'; ${"$class\::ISA"}[0] };
    my $table = $class;
    $table =~ s/^$base\:://;
    $table = lc join '_', grep { defined $_ && length $_ } split /::|([A-Z]+[a-z]*)/, $table;
    return $class->_table($table);
}

sub primary_keys {
    my $class = shift;

    return $class->_primary_keys if $class->_primary_keys;
    return $class->_primary_keys([ $class->db->dbh->primary_key(undef, undef, $class->table) ]);
}

sub unique_keys {
    []; # TODO
}

sub columns {
    my $class = shift;
    
    return $class->_columns if $class->_columns;

    if (my $sth = $class->db->dbh->column_info(undef, undef, $class->table, undef)) {
        confess $class->db->dbh->errstr if $class->db->dbh->err;
        my $cols = $sth->fetchall_arrayref({}) or confess $sth->errstr;
        return $class->_columns([ map { $_->{COLUMN_NAME} } @$cols ]);
    } else {
        die 'TODO';
    }
}

1;

__END__

=head1 NAME

DBIx::MoCo::Lite -

=head1 SYNOPSIS

  use DBIx::MoCo::Lite;

=head1 DESCRIPTION

DBIx::MoCo::Lite is

=head1 AUTHOR

motemen E<lt>motemen@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
