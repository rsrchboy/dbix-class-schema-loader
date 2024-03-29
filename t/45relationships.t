use strict;
use Test::More tests => 12;
use Test::Exception;
use lib qw(t/lib);
use make_dbictest_db;

use DBIx::Class::Schema::Loader;

my $schema_counter = 0;

# test skip_relationships
my $regular = schema_with();
is( ref($regular->source('Bar')->relationship_info('fooref')), 'HASH',
    'regularly-made schema has fooref rel',
  );
my $skip_rel = schema_with( skip_relationships => 1 );
is_deeply( $skip_rel->source('Bar')->relationship_info('fooref'), undef,
    'skip_relationships blocks generation of fooref rel',
  );

# test hashref as rel_name_map
my $hash_relationship = schema_with(
    rel_name_map => {
        fooref => "got_fooref",
        bars   => "ignored",
        Foo    => {
            bars => "got_bars",
            fooref => "ignored",
        },
    }
);
is( ref($hash_relationship->source('Foo')->relationship_info('got_bars')),
    'HASH',
    'single level hash in rel_name_map picked up correctly'
  );
is( ref($hash_relationship->source('Bar')->relationship_info('got_fooref')),
    'HASH',
    'double level hash in rel_name_map picked up correctly'
  );

# test coderef as rel_name_map
my $code_relationship = schema_with(
    rel_name_map => sub {
        my ($args) = @_;

        if ($args->{local_moniker} eq 'Foo') {
            is_deeply(
                $args,
                {
		    name           => 'bars',
		    type           => 'has_many',
                    local_class    =>
                        "DBICTest::Schema::${schema_counter}::Result::Foo",
		    local_moniker  => 'Foo',
		    local_columns  => ['fooid'],
                    remote_class   =>
                        "DBICTest::Schema::${schema_counter}::Result::Bar",
		    remote_moniker => 'Bar',
		    remote_columns => ['fooref'],
		},
		'correct args for Foo passed'
              );
	    return 'bars_caught';
        }
	elsif ($args->{local_moniker} eq 'Bar') {
            is_deeply(
                $args,
                {
		    name           => 'fooref',
		    type           => 'belongs_to',
                    local_class    =>
                        "DBICTest::Schema::${schema_counter}::Result::Bar",
		    local_moniker  => 'Bar',
		    local_columns  => ['fooref'],
                    remote_class   =>
                        "DBICTest::Schema::${schema_counter}::Result::Foo",
		    remote_moniker => 'Foo',
		    remote_columns => ['fooid'],
		},
		'correct args for Foo passed'
              );
	
            return 'fooref_caught';
	}
    }
  );
is( ref($code_relationship->source('Foo')->relationship_info('bars_caught')),
    'HASH',
    'rel_name_map overrode local_info correctly'
  );
is( ref($code_relationship->source('Bar')->relationship_info('fooref_caught')),
    'HASH',
    'rel_name_map overrode remote_info correctly'
  );



# test relationship_attrs
throws_ok {
    schema_with( relationship_attrs => 'laughably invalid!!!' );
} qr/relationship_attrs/, 'throws error for invalid relationship_attrs';


{
    my $nodelete = schema_with( relationship_attrs =>
				{
				 all        => { cascade_delete => 0 },
				 belongs_to => { cascade_delete => 1 },
				},
			      );

    my $bars_info   = $nodelete->source('Foo')->relationship_info('bars');
    #use Data::Dumper;
    #die Dumper([ $nodelete->source('Foo')->relationships() ]);
    my $fooref_info = $nodelete->source('Bar')->relationship_info('fooref');
    is( ref($fooref_info), 'HASH',
	'fooref rel is present',
      );
    is( $bars_info->{attrs}->{cascade_delete}, 0,
	'relationship_attrs settings seem to be getting through to the generated rels',
      );
    is( $fooref_info->{attrs}->{cascade_delete}, 1,
	'belongs_to in relationship_attrs overrides all def',
      );
}

#### generates a new schema with the given opts every time it's called
sub schema_with {
    $schema_counter++;
    DBIx::Class::Schema::Loader::make_schema_at(
            'DBICTest::Schema::'.$schema_counter,
            { naming => 'current', @_ },
            [ $make_dbictest_db::dsn ],
    );
    "DBICTest::Schema::$schema_counter"->clone;
}
