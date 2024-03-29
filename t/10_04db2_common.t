use strict;
use warnings;
use Test::More;
use Test::Exception;
use Try::Tiny;
use File::Path 'rmtree';
use DBIx::Class::Schema::Loader 'make_schema_at';

use lib qw(t/lib);

use dbixcsl_common_tests ();
use dbixcsl_test_dir '$tdir';

use constant EXTRA_DUMP_DIR => "$tdir/db2_extra_dump";

my $dsn      = $ENV{DBICTEST_DB2_DSN} || '';
my $user     = $ENV{DBICTEST_DB2_USER} || '';
my $password = $ENV{DBICTEST_DB2_PASS} || '';

plan skip_all => 'You need to set the DBICTEST_DB2_DSN, _USER, and _PASS environment variables'
    unless ($dsn && $user);

my ($schema, $schemas_created); # for cleanup in END for extra tests

my $srv_ver = do {
    require DBI;
    my $dbh = DBI->connect ($dsn, $user, $password, { RaiseError => 1, PrintError => 0} );
    eval { $dbh->get_info(18) } || 0;
};
my ($maj_srv_ver) = $srv_ver =~ /^(\d+)/;

my $extra_graphics_data_types = {
    graphic            => { data_type => 'graphic', size => 1 },
    'graphic(3)'       => { data_type => 'graphic', size => 3 },
    'vargraphic(3)'    => { data_type => 'vargraphic', size => 3 },
    'long vargraphic'  => { data_type => 'long vargraphic' },
    'dbclob'           => { data_type => 'dbclob' },
};

my $tester = dbixcsl_common_tests->new(
    vendor         => 'DB2',
    auto_inc_pk    => 'INTEGER GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY',
    dsn            => $dsn,
    user           => $user,
    password       => $password,
    null           => '',
    preserve_case_mode_is_exclusive => 1,
    quote_char                      => '"',
    data_types => {
        # http://publib.boulder.ibm.com/infocenter/db2luw/v8/index.jsp?topic=/com.ibm.db2.udb.doc/admin/r0008483.htm
        #
        # Numeric Types
        smallint           => { data_type => 'smallint' },
        integer            => { data_type => 'integer' },
        'int'              => { data_type => 'integer' },
        real               => { data_type => 'real' },
        'double precision' => { data_type => 'double precision' },
        double             => { data_type => 'double precision' },
        float              => { data_type => 'double precision' },
        'float(24)'        => { data_type => 'real' },
        'float(25)'        => { data_type => 'double precision' },
        'float(53)'        => { data_type => 'double precision' },
        numeric            => { data_type => 'numeric' },
        decimal            => { data_type => 'numeric' },
        'numeric(6,3)'     => { data_type => 'numeric', size => [6,3] },
        'decimal(6,3)'     => { data_type => 'numeric', size => [6,3] },

        # Character String Types
        char               => { data_type => 'char', size => 1 },
        'char(3)'          => { data_type => 'char', size => 3 },
        'varchar(3)'       => { data_type => 'varchar', size => 3 },
        'long varchar'     => { data_type => 'long varchar' },
        'clob'             => { data_type => 'clob' },

        # Graphic String Types (double-byte strings)
        ($maj_srv_ver >= 9) ? (%$extra_graphics_data_types) : (),

        # Binary String Types
        'char for bit data'=> { data_type => 'binary', size => 1, original => { data_type => 'char for bit data' } },
        'char(3) for bit data'
                           => { data_type => 'binary', size => 3, original => { data_type => 'char for bit data' } },
        'varchar(3) for bit data'
                           => { data_type => 'varbinary', size => 3, original => { data_type => 'varchar for bit data' } },
        'long varchar for bit data'
                           => { data_type => 'blob', original => { data_type => 'long varchar for bit data' } },
        blob               => { data_type => 'blob' },

        # DateTime Types
        'date'             => { data_type => 'date' },
        'date default current date'
                           => { data_type => 'date', default_value => \'current_timestamp',
                                original => { default_value => \'current date' } },
        'time'             => { data_type => 'time' },
        'time default current time'
                           => { data_type => 'time', default_value => \'current_timestamp',
                                original => { default_value => \'current time' } },
        timestamp          => { data_type => 'timestamp' },
        'timestamp default current timestamp'
                           => { data_type => 'timestamp', default_value => \'current_timestamp',
                                original => { default_value => \'current timestamp' } },

        # DATALINK Type
        # XXX I don't know how to make these
#        datalink           => { data_type => 'datalink' },
    },
    extra => {
        count => 28 * 2,
        run => sub {
            SKIP: {
                $schema = shift;

                my $dbh = $schema->storage->dbh;

                try {
                    $dbh->do('CREATE SCHEMA "dbicsl-test"');
                }
                catch {
                    $schemas_created = 0;
                    skip "no CREATE SCHEMA privileges", 28 * 2;
                };

                $dbh->do(<<"EOF");
                    CREATE TABLE "dbicsl-test".db2_loader_test4 (
                        id INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
                        value VARCHAR(100)
                    )
EOF
                $dbh->do(<<"EOF");
                    CREATE TABLE "dbicsl-test".db2_loader_test5 (
                        id INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
                        value VARCHAR(100),
                        four_id INTEGER NOT NULL UNIQUE,
                        FOREIGN KEY (four_id) REFERENCES "dbicsl-test".db2_loader_test4 (id)
                    )
EOF
                $dbh->do('CREATE SCHEMA "dbicsl.test"');
                $dbh->do(<<"EOF");
                    CREATE TABLE "dbicsl.test".db2_loader_test6 (
                        id INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
                        value VARCHAR(100),
                        db2_loader_test4_id INTEGER,
                        FOREIGN KEY (db2_loader_test4_id) REFERENCES "dbicsl-test".db2_loader_test4 (id)
                    )
EOF
                $dbh->do(<<"EOF");
                    CREATE TABLE "dbicsl.test".db2_loader_test7 (
                        id INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
                        value VARCHAR(100),
                        six_id INTEGER NOT NULL UNIQUE,
                        FOREIGN KEY (six_id) REFERENCES "dbicsl.test".db2_loader_test6 (id)
                    )
EOF
                $dbh->do(<<"EOF");
                    CREATE TABLE "dbicsl-test".db2_loader_test8 (
                        id INT GENERATED BY DEFAULT AS IDENTITY NOT NULL PRIMARY KEY,
                        value VARCHAR(100),
                        db2_loader_test7_id INTEGER,
                        FOREIGN KEY (db2_loader_test7_id) REFERENCES "dbicsl.test".db2_loader_test7 (id)
                    )
EOF

                $schemas_created = 1;

                foreach my $db_schema (['dbicsl-test', 'dbicsl.test'], '%') {
                    lives_and {
                        rmtree EXTRA_DUMP_DIR;

                        my @warns;
                        local $SIG{__WARN__} = sub {
                            push @warns, $_[0] unless $_[0] =~ /\bcollides\b/;
                        };

                        make_schema_at(
                            'DB2MultiSchema',
                            {
                                naming => 'current',
                                db_schema => $db_schema,
                                dump_directory => EXTRA_DUMP_DIR,
                                quiet => 1,
                            },
                            [ $dsn, $user, $password ],
                        );

                        diag join "\n", @warns if @warns;

                        is @warns, 0;
                    } 'dumped schema for "dbicsl-test" and "dbicsl.test" schemas with no warnings';

                    my ($test_schema, $rsrc, $rs, $row, %uniqs, $rel_info);

                    lives_and {
                        ok $test_schema = DB2MultiSchema->connect($dsn, $user, $password);
                    } 'connected test schema';

                    lives_and {
                        ok $rsrc = $test_schema->source('Db2LoaderTest4');
                    } 'got source for table in schema name with dash';

                    is try { $rsrc->column_info('id')->{is_auto_increment} }, 1,
                        'column in schema name with dash';

                    is try { $rsrc->column_info('value')->{data_type} }, 'varchar',
                        'column in schema name with dash';

                    is try { $rsrc->column_info('value')->{size} }, 100,
                        'column in schema name with dash';

                    lives_and {
                        ok $rs = $test_schema->resultset('Db2LoaderTest4');
                    } 'got resultset for table in schema name with dash';

                    lives_and {
                        ok $row = $rs->create({ value => 'foo' });
                    } 'executed SQL on table in schema name with dash';

                    $rel_info = try { $rsrc->relationship_info('db2_loader_test5') };

                    is_deeply $rel_info->{cond}, {
                        'foreign.four_id' => 'self.id'
                    }, 'relationship in schema name with dash';

                    is $rel_info->{attrs}{accessor}, 'single',
                        'relationship in schema name with dash';

                    is $rel_info->{attrs}{join_type}, 'LEFT',
                        'relationship in schema name with dash';

                    lives_and {
                        ok $rsrc = $test_schema->source('Db2LoaderTest5');
                    } 'got source for table in schema name with dash';

                    %uniqs = try { $rsrc->unique_constraints };

                    is keys %uniqs, 2,
                        'got unique and primary constraint in schema name with dash';

                    lives_and {
                        ok $rsrc = $test_schema->source('Db2LoaderTest6');
                    } 'got source for table in schema name with dot';

                    is try { $rsrc->column_info('id')->{is_auto_increment} }, 1,
                        'column in schema name with dot introspected correctly';

                    is try { $rsrc->column_info('value')->{data_type} }, 'varchar',
                        'column in schema name with dot introspected correctly';

                    is try { $rsrc->column_info('value')->{size} }, 100,
                        'column in schema name with dot introspected correctly';

                    lives_and {
                        ok $rs = $test_schema->resultset('Db2LoaderTest6');
                    } 'got resultset for table in schema name with dot';

                    lives_and {
                        ok $row = $rs->create({ value => 'foo' });
                    } 'executed SQL on table in schema name with dot';

                    $rel_info = try { $rsrc->relationship_info('db2_loader_test7') };

                    is_deeply $rel_info->{cond}, {
                        'foreign.six_id' => 'self.id'
                    }, 'relationship in schema name with dot';

                    is $rel_info->{attrs}{accessor}, 'single',
                        'relationship in schema name with dot';

                    is $rel_info->{attrs}{join_type}, 'LEFT',
                        'relationship in schema name with dot';

                    lives_and {
                        ok $rsrc = $test_schema->source('Db2LoaderTest7');
                    } 'got source for table in schema name with dot';

                    %uniqs = try { $rsrc->unique_constraints };

                    is keys %uniqs, 2,
                        'got unique and primary constraint in schema name with dot';

                    lives_and {
                        ok $test_schema->source('Db2LoaderTest6')
                            ->has_relationship('db2_loader_test4');
                    } 'cross-schema relationship in multi-db_schema';

                    lives_and {
                        ok $test_schema->source('Db2LoaderTest4')
                            ->has_relationship('db2_loader_test6s');
                    } 'cross-schema relationship in multi-db_schema';

                    lives_and {
                        ok $test_schema->source('Db2LoaderTest8')
                            ->has_relationship('db2_loader_test7');
                    } 'cross-schema relationship in multi-db_schema';

                    lives_and {
                        ok $test_schema->source('Db2LoaderTest7')
                            ->has_relationship('db2_loader_test8s');
                    } 'cross-schema relationship in multi-db_schema';
                }
            }

        },
    },
);

$tester->run_tests();

END {
    if (not $ENV{SCHEMA_LOADER_TESTS_NOCLEANUP}) {
        if ($schemas_created && (my $dbh = try { $schema->storage->dbh })) {
            foreach my $table ('"dbicsl-test".db2_loader_test8',
                               '"dbicsl.test".db2_loader_test7',
                               '"dbicsl.test".db2_loader_test6',
                               '"dbicsl-test".db2_loader_test5',
                               '"dbicsl-test".db2_loader_test4') {
                try {
                    $dbh->do("DROP TABLE $table");
                }
                catch {
                    diag "Error dropping table: $_";
                };
            }

            foreach my $db_schema (qw/dbicsl-test dbicsl.test/) {
                try {
                    $dbh->do(qq{DROP SCHEMA "$db_schema" RESTRICT});
                }
                catch {
                    diag "Error dropping test schema $db_schema: $_";
                };
            }
        }
        rmtree EXTRA_DUMP_DIR;
    }
}
# vim:et sts=4 sw=4 tw=0:
