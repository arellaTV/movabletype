#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";    # t/lib
use Test::More;
use MT::Test::Env;
our $test_env;

BEGIN {
    $test_env = MT::Test::Env->new;
    $ENV{MT_CONFIG} = $test_env->config_file;
}

use utf8;

use MT::Test::Tag;

# plan tests => 2 * blocks;
plan tests => 1 * blocks;

use MT;
use MT::Test;
use MT::Test::Permission;
my $app = MT->instance;

my $blog_id = 1;

filters {
    template => [qw( chomp )],
    expected => [qw( chomp )],
    error    => [qw( chomp )],
};

$test_env->prepare_fixture(
    sub {
        MT::Test->init_db;

        my $ct = MT::Test::Permission->make_content_type(
            name    => 'test content data',
            blog_id => $blog_id,
        );
        my $cd = MT::Test::Permission->make_content_data(
            blog_id         => $blog_id,
            content_type_id => $ct->id,
            created_on      => '20170530183000',
        );
    }
);

MT::Test::Tag->run_perl_tests($blog_id);

# MT::Test::Tag->run_php_tests($blog_id);

__END__

=== MT::ContentCreatedDate
--- template
<mt:Contents content_type="test content data"><mt:ContentCreatedDate></mt:Contents>
--- expected
May 30, 2017  6:30 PM

=== MT::ContentCreatedDate with language="ja"
--- template
<mt:Contents content_type="test content data"><mt:ContentCreatedDate language="ja"></mt:Contents>
--- expected
2017年5月30日 18:30

