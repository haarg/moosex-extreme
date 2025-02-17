#!/usr/bin/env perl

use lib 'lib';
use Test::Most;

package My::Names {
    use MooseX::Extended types => [qw(compile Num NonEmptyStr Str PositiveInt ArrayRef)];
    use List::Util 'sum';

    param _name => ( isa => NonEmptyStr, init_arg => 'name' );
    param title => ( isa => Str, required => 0, predicate => 1 );
    param extra => ( is  => 'rw', isa => Str, required => 0 );

    field created => ( isa => PositiveInt, default => sub {time} );
    field updated => ( is => 'rw', isa => PositiveInt, writer => 1, default => sub {time} );

    sub name ($self) {
        my $title = $self->title;
        my $name  = $self->_name;
        return $title ? "$title $name" : $name;
    }

    sub add ( $self, $args ) {
        state $check = compile( ArrayRef [ Num, 1 ] );
        ($args) = $check->($args);
        return sum( $args->@* );
    }

    sub warnit ($self) {
        carp("this is a warning");
    }
}

subtest 'miscellaneous features' => sub {
    SKIP: {
        skip "Classes cannot be immutable while running under the debugger", 1 if $^P;
        ok +My::Names->meta->is_immutable,
          'We should be able to define an immutable class';
    }
    is mro::get_mro('My::Names'), 'c3', "Our class's mro should be c3";
};

subtest 'no title' => sub {
    my $person = My::Names->new( name => 'Ovid', );
    is $person->name, 'Ovid', 'name should be correct';
    ok !defined $person->title, '... and no title';
    cmp_ok $person->created, '>', 0, '... and a sane default for created';
    ok !$person->can('sum'), 'subroutines have been removed from the namespace';
    is $person->add( [qw/1 3 5 6/] ), 15, 'Our add() method should work';
    ok !$person->has_title, 'Our predicate shortcut should work';

    ok !defined $person->extra, 'optional params start our as default';
    $person->extra('foo');
    is $person->extra, 'foo', 'We can declare is => "rw" for params';

    my $updated = $person->updated;
    $person->set_updated( $updated + 1 );
    is $person->updated, $updated + 1, 'We should be able to update is => "rw" fields';
};

subtest 'has title' => sub {
    my $person = My::Names->new( name => 'Ovid', );
    my $doctor = My::Names->new( name => 'Smith', title => 'Dr.' );
    is $doctor->name, 'Dr. Smith', 'Titles should show up correctly';
    cmp_ok $doctor->created, '>=', $person->created,
      '... and their created date should be correct';
    ok $doctor->has_title, 'Our predicate shortcut should work';
};

subtest 'exceptions' => sub {
    my $person = My::Names->new( name => 'Ovid', );

    throws_ok { $person->title('Mr.') }
    'Moose::Exception::CannotAssignValueToReadOnlyAccessor',
      'param() is read-only by default';

    throws_ok { $person->created(11111) }
    'Moose::Exception::CannotAssignValueToReadOnlyAccessor',
      'field() is read-only by default';

    throws_ok { $person->add( [] ) }
    'Error::TypeTiny::Assertion',
      'passing an empty array reference should be fatal';

    throws_ok { My::Names->new( name => 'Ovid', created => 1 ) }
    'Moose::Exception',
      'Attributes not defined as `param` are illegal in the constructor';
};

done_testing;
